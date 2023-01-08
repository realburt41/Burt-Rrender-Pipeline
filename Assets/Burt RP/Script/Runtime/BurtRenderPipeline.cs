using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public class BurtRenderPipeline : RenderPipeline
{
    CameraRenderer renderer = new CameraRenderer();

    ShadowSetting shadowSetting;
    protected override void Render(ScriptableRenderContext context, Camera[] cameras)
    {
        foreach (Camera camera in cameras)
        {
            renderer.Render(context, camera, shadowSetting);
        }
    }

    public BurtRenderPipeline(ShadowSetting shadowSetting)
    {
        GraphicsSettings.useScriptableRenderPipelineBatching = true;
        GraphicsSettings.lightsUseLinearIntensity = true;

        this.shadowSetting = shadowSetting;
    }

}
