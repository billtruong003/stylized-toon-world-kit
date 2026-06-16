// =============================================================================
//  ScreenSpaceOutlineFeature.cs  —  Stylized Toon World Kit / P1
// -----------------------------------------------------------------------------
//  RENDERER FEATURE (RenderGraph, URP 17 / Unity 6) cho biến thể outline
//  "optimized" — edge-detection toàn màn hình (1 fullscreen draw, giữ batch scene).
//    • ConfigureInput(Depth|Normal) → ép URP có _CameraDepthTexture + _CameraNormalsTexture.
//    • Blit material qua RenderGraphUtils.AddBlitPass (tự xử XR single-pass instanced).
//    • Tránh same source==destination: blit sang temp rồi trỏ cameraColor = temp.
//  Người dùng: thêm feature này vào URP Renderer asset, KHÔNG gắn shader lên material.
//
//  ⚠️ GOTCHA U6: PHẢI override RecordRenderGraph (KHÔNG dùng Execute() compatibility
//  mode — deprecated). Lệnh vẽ nằm trong AddBlitPass; không add cmd ngoài SetRenderFunc.
//  Down-version (URP 14 / U2022): cần viết lại bằng API CommandBuffer + Blit cũ
//  (xem README "Down-version"); RenderGraph path chỉ chạy U6+.
// =============================================================================
using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;

namespace StylizedToonWorldKit
{
    [DisallowMultipleRendererFeature("STW Screen-Space Outline")]
    public class ScreenSpaceOutlineFeature : ScriptableRendererFeature
    {
        [Serializable]
        public class Settings
        {
            public RenderPassEvent injectionPoint = RenderPassEvent.AfterRenderingSkybox;
            [ColorUsage(true, true)] public Color outlineColor = Color.black;
            [Range(1f, 4f)] public float thickness   = 1f;
            [Range(0f, 10f)] public float depthScale  = 2f;
            [Range(0f, 2f)]  public float depthBias   = 0.2f;
            [Range(0f, 10f)] public float normalScale = 3f;
            [Range(0f, 2f)]  public float normalBias  = 0.4f;
        }

        public Settings settings = new Settings();
        [SerializeField, HideInInspector] private Shader shader;
        private Material _material;
        private OutlinePass _pass;

        public override void Create()
        {
            if (shader == null)
                shader = Shader.Find("Hidden/StylizedToonWorldKit/Screen-Space Outline");
            _pass = new OutlinePass { renderPassEvent = settings.injectionPoint };
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            if (shader == null) return;
            if (_material == null) _material = CoreUtils.CreateEngineMaterial(shader);

            _pass.renderPassEvent = settings.injectionPoint;
            _pass.Setup(_material, settings);
            // Ép DepthNormals prepass để có _CameraDepthTexture + _CameraNormalsTexture.
            _pass.ConfigureInput(ScriptableRenderPassInput.Depth | ScriptableRenderPassInput.Normal);
            renderer.EnqueuePass(_pass);
        }

        protected override void Dispose(bool disposing)
        {
            CoreUtils.Destroy(_material);
            _material = null;
        }

        // ---------------------------------------------------------------------
        private class OutlinePass : ScriptableRenderPass
        {
            private Material _mat;
            private Settings _s;

            private static readonly int ID_Color       = Shader.PropertyToID("_OutlineColor");
            private static readonly int ID_Thickness   = Shader.PropertyToID("_OutlineThickness");
            private static readonly int ID_DepthScale  = Shader.PropertyToID("_DepthScale");
            private static readonly int ID_DepthBias   = Shader.PropertyToID("_DepthBias");
            private static readonly int ID_NormalScale = Shader.PropertyToID("_NormalScale");
            private static readonly int ID_NormalBias  = Shader.PropertyToID("_NormalBias");

            public void Setup(Material m, Settings s) { _mat = m; _s = s; }

            public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
            {
                if (_mat == null) return;

                var resourceData = frameData.Get<UniversalResourceData>();
                var cameraData   = frameData.Get<UniversalCameraData>();
                if (resourceData.isActiveTargetBackBuffer) return; // không đọc/ghi thẳng backbuffer

                // Đẩy tham số material (làm trước khi blit).
                _mat.SetColor(ID_Color,      _s.outlineColor);
                _mat.SetFloat(ID_Thickness,  _s.thickness);
                _mat.SetFloat(ID_DepthScale, _s.depthScale);
                _mat.SetFloat(ID_DepthBias,  _s.depthBias);
                _mat.SetFloat(ID_NormalScale,_s.normalScale);
                _mat.SetFloat(ID_NormalBias, _s.normalBias);

                TextureHandle source = resourceData.activeColorTexture;

                var desc = cameraData.cameraTargetDescriptor;
                desc.depthBufferBits = 0;
                desc.msaaSamples     = 1;
                TextureHandle dest = UniversalRenderer.CreateRenderGraphTexture(
                    renderGraph, desc, "STW_SSOutline", false);

                // AddBlitPass: fullscreen + XR-safe; đọc source, ghi dest qua _mat (pass 0).
                var para = new RenderGraphUtils.BlitMaterialParameters(source, dest, _mat, 0);
                renderGraph.AddBlitPass(para, "STW SS Outline");

                // Trỏ camera color sang dest → tránh blit ngược same source/dest.
                resourceData.cameraColor = dest;
            }
        }
    }
}
