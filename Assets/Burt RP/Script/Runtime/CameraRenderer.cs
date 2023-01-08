using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public partial class CameraRenderer
{
    ScriptableRenderContext context;

    Camera camera;

    const string bufferName = "Render Camera";

    CommandBuffer buffer = new CommandBuffer { name = bufferName };

    CullingResults cullingResults;

    static ShaderTagId forwardShaderTagId = new ShaderTagId("BRPForward");

    Lighting lighting = new Lighting();

    public void Render(ScriptableRenderContext context, Camera camera,ShadowSetting shadowSetting)
    {
        this.context = context;
        this.camera = camera;

        // 区分多摄像机
        PrepareBuffer();
        // 使UI在Scene可视（貌似没用？）
        PrepareForSceneWindow();

        // 视锥体剔除
        if (!Cull(shadowSetting.maxDistance))
            return;

        buffer.BeginSample(SampleName);
        ExecuteBuffer();
        lighting.Setup(context, cullingResults, shadowSetting);
        buffer.EndSample(SampleName);
        Setup();
        DrawUnsupportedShaders();
        DrawVisibleGeometry();
        DrawGizmos();
        lighting.Cleanup();
        Submit();
    }

    void DrawVisibleGeometry()
    {
        // 绘制不透明
        // 用于确定是否应用正交或基于距离的排序
        var sortingSettings = new SortingSettings(camera) { criteria = SortingCriteria.CommonOpaque };
        var drawingSettings = new DrawingSettings(forwardShaderTagId, sortingSettings);
        drawingSettings.perObjectData =
                PerObjectData.ReflectionProbes |
                PerObjectData.Lightmaps | PerObjectData.ShadowMask |
                PerObjectData.LightProbe | PerObjectData.OcclusionProbe |
                PerObjectData.LightProbeProxyVolume |
                PerObjectData.OcclusionProbeProxyVolume;


        // 指出允许哪些渲染队列
        var filteringSettings = new FilteringSettings(RenderQueueRange.opaque);

        context.DrawRenderers(cullingResults, ref drawingSettings, ref filteringSettings);

        // 绘制天空盒
        context.DrawSkybox(camera);

        // 绘制透明
        sortingSettings.criteria = SortingCriteria.CommonTransparent;
        drawingSettings.sortingSettings = sortingSettings;
        filteringSettings.renderQueueRange = RenderQueueRange.transparent;
        context.DrawRenderers(cullingResults, ref drawingSettings, ref filteringSettings);
    }

    void Setup()
    {
        // 清除渲染目标
        context.SetupCameraProperties(camera);
        CameraClearFlags flags = camera.clearFlags;
        buffer.ClearRenderTarget(flags <= CameraClearFlags.Depth,
                                 flags == CameraClearFlags.Color,
                                 flags == CameraClearFlags.Color ? camera.backgroundColor.linear
                                                                 : Color.clear);

        // 使用命令缓冲区注入给Profiler注入样本，这些样本将同时显示在Profiler和帧调试器中
        buffer.BeginSample(SampleName);
        ExecuteBuffer();
    }

    void Submit()
    {
        buffer.EndSample(SampleName);
        ExecuteBuffer();

        // 我们向上下文发出的命令都是缓冲的。必须通过在上下文上调用Submit来提交排队的工作才会执行
        context.Submit();
    }

    void ExecuteBuffer()
    {
        context.ExecuteCommandBuffer(buffer);
        buffer.Clear();
    }

    bool Cull(float maxDistance)
    {
        if (camera.TryGetCullingParameters(out ScriptableCullingParameters p))
        {
            p.shadowDistance = Mathf.Min(maxDistance,camera.farClipPlane);
            cullingResults = context.Cull(ref p);
            return true;
        }

        return false;
    }


}
