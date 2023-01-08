#ifndef COMMON_INPUT_INCLUDE
    #define COMMON_INPUT_INCLUDE

    // Unity Include
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    //#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"

    // BRP Include
    #include "Assets/Burt RP/Shader/ShaderLibrary/Lighting/BurtLighting.hlsl"
    #include "Assets/Burt RP/Shader/ShaderLibrary/Math/Math.hlsl"
    #include "Color.hlsl"

    SamplerState sampler_LinearClamp;
    SamplerState sampler_LinearRepeat;


#endif // COMMON_INPUT_INCLUDE