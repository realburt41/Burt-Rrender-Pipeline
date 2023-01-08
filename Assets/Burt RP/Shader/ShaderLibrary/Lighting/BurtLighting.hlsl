#ifndef BURT_LIGHTING_INCLUDED
#define BURT_LIGHTING_INCLUDED

struct Light {
    float3 color;
    float3 direction;
};

#define MAX_DIRECTIONAL_LIGHT_COUNT 4

CBUFFER_START(_BurtLight)
//float3 _DirectionalLightColor;
//float3 _DirectionalLightDirection;
int _DirectionalLightCount;
float4 _DirectionalLightColors[MAX_DIRECTIONAL_LIGHT_COUNT];
float4 _DirectionalLightDirections[MAX_DIRECTIONAL_LIGHT_COUNT];
float4 _DirectionalLightShadowData[MAX_DIRECTIONAL_LIGHT_COUNT];
CBUFFER_END

int GetDirectionLightCount() {
    return _DirectionalLightCount;
}

Light GetDirectionalLight(int index) {
    Light light;
    light.color = _DirectionalLightColors[index];
    light.direction = _DirectionalLightDirections[index];
    return light;
}

float3 GetRadiance(float3 N, Light light) {
    return saturate(dot(N, light.direction)) * light.color;
}

float3 GetLighting(float3 N) {
    float3 color = 0.0;
    for (int i = 0; i < GetDirectionLightCount(); i++) {
        color += GetRadiance(N,GetDirectionalLight(i));
    }
    return color;
}

#endif  // BURT_LIGHTING_INCLUDED