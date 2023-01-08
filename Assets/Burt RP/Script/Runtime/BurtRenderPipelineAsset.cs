using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[CreateAssetMenu(menuName ="Rendering/Burt Render Pipeline")]
public class BurtRenderPipelineAsset : RenderPipelineAsset
{
    [SerializeField]
    ShadowSetting shadowSetting = default;
    protected override RenderPipeline CreatePipeline()
    {
        return new BurtRenderPipeline(shadowSetting);
    }
    
}
