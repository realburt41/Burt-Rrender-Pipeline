Shader "Burt RP/Unlit" {

    Properties {
        _MainTex ("Texture", 2D) = "white" { }
        _Color ("Color", Color) = (1, 1, 1, 1)

        [Enum(UnityEngine.Rendering.CompareFunction)]_ZTest ("深度测试", Float) = 4
        [Enum(Off, 0, On, 1)]_ZWrite ("深度写入", Float) = 0

        [Enum(UnityEngine.Rendering.BlendMode)]_BlendSrc ("Blend Src", Float) = 5
        [Enum(UnityEngine.Rendering.BlendMode)]_BlendDes ("Blend Des", Float) = 10
    }

    SubShader {
        Tags { "LightMode" = "BRPForward" }

        Pass {
            Blend [_BlendSrc] [_BlendDes]
            
            ZWrite [_ZWrite]
            ZTest [_ZTest]

            HLSLPROGRAM

            #pragma target 3.5

            #pragma vertex vert
            #pragma fragment frag

            #include "Assets/Burt RP/Shader/ShaderLibrary/Common/CommonInput.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_ST;
            float4 _Color;
            CBUFFER_END

            struct appdata {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                half3 normal : NORMAL;
            };

            struct v2f {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                half3 normal : TEXCOORD1;
            };

            sampler2D _MainTex;

            v2f vert(appdata v) {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normal = TransformObjectToWorldNormal(v.normal);
                return o;
            }

            float4 frag(v2f i) : SV_Target {
                half3 normal = normalize(i.normal);
                float4 col = tex2D(_MainTex, i.uv) * _Color;
                return col;

                //Light light = GetDirectionalLight(0);
                //return GetRadiance(normal,light).xyzz;
                return GetLighting(normal).xyzz;
            }
            ENDHLSL
        }
    }
}