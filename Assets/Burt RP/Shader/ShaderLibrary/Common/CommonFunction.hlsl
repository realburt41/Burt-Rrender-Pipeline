#ifndef COMMON_FUNCTION_INCLUDE
#define COMMON_FUNCTION_INCLUDE

#include "CommonInput.hlsl"

inline half3 UnPackViewDir(half4 T, half4 B, half4 N)
{
    return half3(T.w, B.w, N.w);
}

////////////// Normal Function ////////////////////
inline half3 NormalBlend(half3 n1, half3 n2)
{
    return normalize(half3(n1.xy + n2.xy, n1.z));
}

inline half3 NormalBlendReoriented(half3 A, half3 B)
{
    half3 t = A.xyz + half3(0.0, 0.0, 1.0);
    half3 u = B.xyz * half3(-1.0, -1.0, 1.0);
    return (t / t.z) * dot(t, u) - u;
}

inline half3 NormalStrength(half3 In, half Strength)
{
    return half3(In.rg * Strength, lerp(1, In.b, saturate(Strength)));
}

float NormalFiltering(float roughness, const float3 worldNormal)
{
    // Kaplanyan 2016, "Stable specular highlights"
    // Tokuyoshi 2017, "Error Reduction and Simplification for Shading Anti-Aliasing"
    // Tokuyoshi and Kaplanyan 2019, "Improved Geometric Specular Antialiasing"

    // This implementation is meant for deferred rendering in the original paper but
    // we use it in forward rendering as well (as discussed in Tokuyoshi and Kaplanyan
    // 2019). The main reason is that the forward version requires an expensive transform
    // of the half vector by the tangent frame for every light. This is therefore an
    // approximation but it works well enough for our needs and provides an improvement
    // over our original implementation based on Vlachos 2015, "Advanced VR Rendering".

    float3 du = ddx(worldNormal);
    float3 dv = ddy(worldNormal);

    float variance = 0.5 * (dot(du, du) + dot(dv, dv));

    float kernelRoughness = min(2.0 * variance, 1);
    float squareRoughness = saturate(roughness * roughness + kernelRoughness);

    return sqrt(squareRoughness);
}

////////////// UV ////////////////////////
float2 RotateUV(float2 uv, half radius)
{
    float s, c;
    sincos(0.0174 * radius, s, c);

    // Calculate rotation at (0, 0) image local space.
    uv -= float2(0.5, 0.5);
    uv = float2(uv.x * c + uv.y * s, uv.y * c - uv.x * s);
    uv += float2(0.5, 0.5);

    return uv;
}

////////////// Fog ////////////////////
float3 MixFogColorPBR(half3 fragColor, half3 fogColor, half fogFactor)
{
    #if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
        half fogIntensity = ComputeFogIntensity(fogFactor);
        fragColor = lerp(fogColor, fragColor, fogIntensity);
    #endif
    return fragColor;
}


half LerpWhiteTo(half b, half t)
{
    half oneMinusT = 1.0 - t;
    return oneMinusT + b * t;
}




#endif // COMMON_FUNCTION_INCLUDE