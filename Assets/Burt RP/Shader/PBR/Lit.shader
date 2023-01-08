Shader "Burt RP/Lit"
{

    Properties
    {
        _BaseMap ("颜色贴图", 2D) = "white" { }
        _BaseColor ("RGB:颜色 A:透明度", Color) = (1, 1, 1, 1)
        [NoScaleOffset][Normal]_NormalMap ("法线贴图", 2D) = "bump" { }
        [NoScaleOffset]_MetallicGlossMap ("RGB: 金属度 AO 光滑度", 2D) = "white" { }

        _Metallic ("金属度", Range(0.0, 1.0)) = 0.0
        _Smoothness ("光滑度", Range(0.0, 1.0)) = 0.5
        _OcclusionStrength ("AO强度", Range(0.0, 1.0)) = 1.0

        _Reflectance ("反射率", Range(0.0, 1.0)) = 0.5

        [Enum(UnityEngine.Rendering.CompareFunction)]_ZTest ("深度测试", Float) = 4
        [Enum(Off, 0, On, 1)]_ZWrite ("深度写入", Float) = 0

        [Enum(UnityEngine.Rendering.BlendMode)]_BlendSrc ("Blend Src", Float) = 5
        [Enum(UnityEngine.Rendering.BlendMode)]_BlendDes ("Blend Des", Float) = 10
    }

    HLSLINCLUDE

    #include "Assets/Burt RP/Shader/ShaderLibrary/Common/CommonFunction.hlsl"
    

    CBUFFER_START(UnityPerMaterial)
        half4 _BaseColor;

        half _Smoothness;
        half _Metallic;
        half _OcclusionStrength;

        half _Reflectance;

        float4 _BaseMap_ST;
        float _Cutoff;
    CBUFFER_END
    
    TEXTURE2D(_BaseMap);
    SAMPLER(sampler_BaseMap);

    TEXTURE2D(_NormalMap);
    TEXTURE2D(_MetallicGlossMap);

    struct Attributes
    {
        float4 positionOS : POSITION;
        float3 normalOS : NORMAL;

        float4 tangentOS : TANGENT;

        float2 uv : TEXCOORD0;
    };
    
    struct Varyings
    {
        float4 positionCS : SV_POSITION;

        float2 uv : TEXCOORD0;

        half4 normalWS : TEXCOORD1;
        half4 tangentWS : TEXCOORD2;
        half4 bitangentWS : TEXCOORD3;
        float3 positionWS : TEXCOORD4;
    };

    #include "PBRFunction.hlsl"

    void PrepareData(Varyings input, out InputData_RP inputData, out SurfaceData_RP surfaceData, out BRDFData_RP brdfData, half vface)
    {
        InitSurfaceData(input.uv, surfaceData);
        InitInputData(input, vface, surfaceData, inputData);
        InitBRDFData(inputData, surfaceData, brdfData);
    }

    void DirectLighting(SurfaceData_RP surfaceData, BRDFData_RP brdfData, Light mainLight, InputData_RP inputData, out half3 DirectDiffuse, out half3 DirectSpecular)
    {
        // Radiance
        half3 MainRadiance = GetLighting(inputData.normalWS);

        // Energy Compensation
        half multiscatterDFGX = brdfData.envBRDF.x + brdfData.envBRDF.y;
        half3 EnergyCompensation = 1.0 + brdfData.specular * (rcp(multiscatterDFGX) - 1.0);

        half NoV = saturate(dot(inputData.normalWS, inputData.viewDirWS));

        half3 SpecularTerm = UnitySpecular(inputData.normalWS, mainLight.direction, inputData.viewDirWS, brdfData.roughness2MinusOne, brdfData.roughness2, brdfData.normalizationTerm)
        * EnergyCompensation;

        DirectSpecular = brdfData.specular * SpecularTerm * MainRadiance;

        DirectDiffuse = brdfData.diffuse * MainRadiance;
    }

    void IndirectLighting(BRDFData_RP brdfData, InputData_RP inputData, SurfaceData_RP surfaceData, Light mainLight, half3 sh, out half3 indirectDiffuse, out half3 IndirectSpecular)
    {
        indirectDiffuse = sh * brdfData.diffuse;

        half3 reflectVector = reflect(-inputData.viewDirWS, inputData.normalWS);
        half NoV = saturate(dot(inputData.normalWS, inputData.viewDirWS));
        IndirectSpecular = UEIBL(reflectVector, inputData.positionWS, brdfData.perceptualRoughness, brdfData.specular, NoV, surfaceData.occlusion, brdfData.envBRDF);

        indirectDiffuse *= surfaceData.occlusion;
        IndirectSpecular *= surfaceData.occlusion;
    }

    ENDHLSL

    SubShader
    {

        Tags { "LightMode" = "BRPForward" }

        Pass
        {
            Blend [_BlendSrc] [_BlendDes]
            
            ZWrite [_ZWrite]
            ZTest [_ZTest]

            HLSLPROGRAM

            #pragma target 3.5

            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _REFLECTANCE

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;

                // Vertex
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionWS = vertexInput.positionWS;
                output.positionCS = vertexInput.positionCS;

                // UV
                output.uv = input.uv;

                // View
                half3 viewDirWS = (GetCameraPositionWS() - vertexInput.positionWS);

                // Normal
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                half sign = input.tangentOS.w * GetOddNegativeScale();
                output.tangentWS = half4(normalInput.tangentWS.xyz, viewDirWS.x);
                output.bitangentWS = half4(sign * cross(normalInput.normalWS.xyz, normalInput.tangentWS.xyz), viewDirWS.y);
                output.normalWS = half4(normalInput.normalWS.xyz, viewDirWS.z);
                
                return output;
            }

            half4 frag(Varyings input, half vface : VFACE) : SV_Target
            {
                SurfaceData_RP surfaceData;
                InputData_RP inputData;
                BRDFData_RP brdfData;
                
                Light light = GetDirectionalLight(0);

                PrepareData(input, inputData, surfaceData, brdfData, vface);

                // Direct Color
                half3 DirectDiffuse, DirectSpecular;
                DirectLighting(surfaceData, brdfData, light, inputData, DirectDiffuse, DirectSpecular);

                // Indirect Color
                half3 IndirectDiffuse, IndirectSpecular;
                IndirectLighting(brdfData, inputData, surfaceData, light, SGameSH9(inputData.normalWS.xyz), IndirectDiffuse, IndirectSpecular);
                
                // Combine
                half3 color = DirectDiffuse + DirectSpecular + IndirectDiffuse + IndirectSpecular;
                return half4(color, surfaceData.alpha);
            }
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"

            Tags { "LightMode" = "ShadowCaster" }

            ColorMask 0

            HLSLPROGRAM
            #pragma target 3.5
            #pragma shader_feature _CLIPPING
            #pragma vertex ShadowCasterPassVertex
            #pragma fragment ShadowCasterPassFragment
            #include "Assets/Burt RP/Shader/ShaderLibrary/Shadow/ShadowCasterPass.hlsl"

            ENDHLSL
        }
    }
}