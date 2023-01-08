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

        // ���ֶ������
        PrepareBuffer();
        // ʹUI��Scene���ӣ�ò��û�ã���
        PrepareForSceneWindow();

        // ��׶���޳�
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
        // ���Ʋ�͸��
        // ����ȷ���Ƿ�Ӧ����������ھ��������
        var sortingSettings = new SortingSettings(camera) { criteria = SortingCriteria.CommonOpaque };
        var drawingSettings = new DrawingSettings(forwardShaderTagId, sortingSettings);
        drawingSettings.perObjectData =
                PerObjectData.ReflectionProbes |
                PerObjectData.Lightmaps | PerObjectData.ShadowMask |
                PerObjectData.LightProbe | PerObjectData.OcclusionProbe |
                PerObjectData.LightProbeProxyVolume |
                PerObjectData.OcclusionProbeProxyVolume;


        // ָ��������Щ��Ⱦ����
        var filteringSettings = new FilteringSettings(RenderQueueRange.opaque);

        context.DrawRenderers(cullingResults, ref drawingSettings, ref filteringSettings);

        // ������պ�
        context.DrawSkybox(camera);

        // ����͸��
        sortingSettings.criteria = SortingCriteria.CommonTransparent;
        drawingSettings.sortingSettings = sortingSettings;
        filteringSettings.renderQueueRange = RenderQueueRange.transparent;
        context.DrawRenderers(cullingResults, ref drawingSettings, ref filteringSettings);
    }

    void Setup()
    {
        // �����ȾĿ��
        context.SetupCameraProperties(camera);
        CameraClearFlags flags = camera.clearFlags;
        buffer.ClearRenderTarget(flags <= CameraClearFlags.Depth,
                                 flags == CameraClearFlags.Color,
                                 flags == CameraClearFlags.Color ? camera.backgroundColor.linear
                                                                 : Color.clear);

        // ʹ���������ע���Profilerע����������Щ������ͬʱ��ʾ��Profiler��֡��������
        buffer.BeginSample(SampleName);
        ExecuteBuffer();
    }

    void Submit()
    {
        buffer.EndSample(SampleName);
        ExecuteBuffer();

        // �����������ķ���������ǻ���ġ�����ͨ�����������ϵ���Submit���ύ�ŶӵĹ����Ż�ִ��
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
