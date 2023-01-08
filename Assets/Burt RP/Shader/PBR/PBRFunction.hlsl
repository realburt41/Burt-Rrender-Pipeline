#ifndef PBR_FUNCTION_INCLUDE
#define PBR_FUNCTION_INCLUDE

#include "Assets/Burt RP/Shader/ShaderLibrary/Common/CommonFunction.hlsl"
#include "Assets/Burt RP/Shader/ShaderLibrary/Surface/ShadingModel.hlsl"
#include "Assets/Burt RP/Shader/ShaderLibrary/Common/GlobalIllumination.hlsl"

///////// Roughness ////////////////////
void UnityRoughness(half smoothness, inout half perceptualRoughness, inout half roughness, inout half roughness2)
{
    perceptualRoughness = 1 - smoothness;
    roughness = max(perceptualRoughness * perceptualRoughness, M_HALF_MIN_SQRT);
    roughness2 = max(roughness * roughness, M_HALF_MIN);
}

void FilamentRoughness(half smoothness, inout half perceptualRoughness, inout half roughness, inout half roughness2)
{
    perceptualRoughness = clamp(1 - smoothness, MIN_PERCEPTUAL_ROUGHNESS, 1.0);
    roughness = perceptualRoughness * perceptualRoughness;
    roughness2 = roughness * roughness;
}

//////////// Specular Occlusion ////////////////
void SpecularOcclusionData(half3 R, half3 BN, half perceptualRoughness, half occlusion, half specularOcclusionStrength, inout half3 albedo, inout half metallic)
{
    // Base signal depends on occlusion and dot product between reflection and bent normal vector
    half occlusionAmount = max(0, dot(R, BN));
    half reflOcclusion = occlusion - (1 - occlusionAmount);
    // Scale with roughness. This is what "sharpens" glossy reflections
    reflOcclusion = saturate(reflOcclusion / perceptualRoughness);
    // Fade between roughness-modulated occlusion and "regular" occlusion based on surface roughness
    // This is done because the roughness-modulated signal doesn't represent rough surfaces very well
    reflOcclusion = lerp(reflOcclusion, lerp(occlusionAmount, 1, occlusion), perceptualRoughness);
    // Scale by color and return
    half so_factor = max(lerp(1, reflOcclusion, specularOcclusionStrength), 0);

    albedo = lerp(1, pow(so_factor, (1 - perceptualRoughness) * 2), metallic * metallic) * albedo;
    metallic = pow(so_factor, 0.5) * metallic;
}

/////////// F0 ///////////////////
float ComputeDielectricF0(float reflectance)
{
    return 0.16 * reflectance * reflectance;
}

float3 ComputeF0(float3 baseColor, float metallic, float reflectance)
{
    return baseColor.rgb * metallic + (reflectance * (1.0 - metallic));
}

////////////// Init Start ////////////////////////
void InitSurfaceData(float2 uv, out SurfaceData_RP outSurfaceData)
{
    outSurfaceData = (SurfaceData_RP)0;

    // base map
    half4 albedoAlpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_LinearRepeat, uv);

    //alpha
    outSurfaceData.alpha = albedoAlpha.a * _BaseColor.a;

    #if defined(_ALPHATEST_ON)
        clip(outSurfaceData.alpha - _Cutoff);
    #endif

    outSurfaceData.albedo = albedoAlpha.rgb * _BaseColor.rgb;
    outSurfaceData.specular = half3(0.0h, 0.0h, 0.0h);

    //specGloss
    half4 specGloss = SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_LinearRepeat, uv);
    outSurfaceData.metallic = specGloss.r * _Metallic;
    outSurfaceData.smoothness = specGloss.b * _Smoothness * 0.95;

    outSurfaceData.reflectance = _Reflectance;

    //ao
    outSurfaceData.occlusion = LerpWhiteTo(specGloss.g, _OcclusionStrength);
}

void InitInputData(Varyings input, half vface, inout SurfaceData_RP surfaceData, out InputData_RP inputData)
{
    inputData = (InputData_RP)0;
    inputData.positionWS = input.positionWS;
    inputData.positionCS = input.positionCS;

    // Normal, View
    input.normalWS = input.normalWS * vface;
    inputData.viewDirWS = normalize(UnPackViewDir(input.tangentWS, input.bitangentWS, input.normalWS));
    
    inputData.TBN = half3x3(input.tangentWS.xyz, input.bitangentWS.xyz, input.normalWS.xyz);

    half3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_LinearRepeat, input.uv));
    inputData.normalWS = normalize(mul(normalTS, inputData.TBN));
}

void InitBRDFData(InputData_RP inputData, inout SurfaceData_RP surfaceData, out BRDFData_RP brdfData)
{

    brdfData = (BRDFData_RP)0;

    // Unity Handle
    // UnityRoughness(surfaceData.smoothness,brdfData.perceptualRoughness,brdfData.roughness,brdfData.roughness2);

    // Filament Handle
    FilamentRoughness(surfaceData.smoothness, brdfData.perceptualRoughness, brdfData.roughness, brdfData.roughness2);

    brdfData.normalizationTerm = brdfData.roughness * 4.0h + 2.0h;
    brdfData.roughness2MinusOne = brdfData.roughness2 - 1.0h;

    // Specular Occlusion
    #if defined(_SPECULAROCCLUSION_ON)
        half3 reflectVector = reflect(-inputData.viewDirWS, inputData.normalWS);
        SpecularOcclusionData(reflectVector, inputData.bentNormalWS, brdfData.perceptualRoughness, surfaceData.occlusion, _SpecularOcclusionStrength, surfaceData.albedo, surfaceData.metallic);
    #endif

    half oneMinusDielectricSpec = 1 - 0.04;
    half oneMinusReflectivity = oneMinusDielectricSpec - surfaceData.metallic * oneMinusDielectricSpec;

    brdfData.diffuse = surfaceData.albedo * oneMinusReflectivity;

    #if defined(_REFLECTANCE)
        float reflectance = ComputeDielectricF0(surfaceData.reflectance);
        brdfData.specular = ComputeF0(surfaceData.albedo, surfaceData.metallic, reflectance);
    #else
        brdfData.specular = lerp(0.04, max(0, surfaceData.albedo), surfaceData.metallic);
    #endif

    brdfData.grazingTerm = saturate(surfaceData.smoothness + 1 - oneMinusReflectivity);

    brdfData.envBRDF = EnvBRDFApproxLazarov(brdfData.perceptualRoughness, saturate(dot(inputData.normalWS, inputData.viewDirWS)));
}
/////////////// Init End ////////////////////////////

#endif //PBR_FUNCTION_INCLUDE