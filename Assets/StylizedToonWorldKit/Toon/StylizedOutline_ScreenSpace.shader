// =============================================================================
//  StylizedOutline_ScreenSpace.shader  —  Stylized Toon World Kit / P1 (Hidden)
// -----------------------------------------------------------------------------
//  BIẾN THỂ OUTLINE "optimized" (nguyên tắc #1): edge-detection toàn màn hình.
//  Đây là SHADER FULLSCREEN BLIT do ScreenSpaceOutlineFeature.cs (RenderGraph)
//  gọi — KHÔNG gắn lên material của object. Người dùng chỉ thêm Renderer Feature.
//    • Roberts cross trên DEPTH (bắt silhouette) + NORMALS (bắt crease) → max.
//    • 1 fullscreen draw → GIỮ batch của scene (không +draw mỗi material như hull).
//    • ⚠️ Cần DepthNormals prepass — Feature gọi ConfigureInput(Depth|Normal).
//    • XR: blit qua Blitter/AddBlitPass tự xử single-pass instanced.
//  Roberts math = đồng bộ với OutlineCommon.hlsl (P0) — ở đây inline để fullscreen
//  pass không kéo theo include lighting nặng.
//  Target: URP 17 / Unity 6 (RenderGraph).
// =============================================================================
Shader "Hidden/StylizedToonWorldKit/Screen-Space Outline"
{
    Properties
    {
        [HDR] _OutlineColor    ("Outline Color", Color) = (0,0,0,1)
        _OutlineThickness ("Thickness (px)", Range(1,4)) = 1
        _DepthScale  ("Depth Edge Scale", Range(0,10)) = 2.0
        _DepthBias   ("Depth Edge Bias", Range(0,2)) = 0.2
        _NormalScale ("Normal Edge Scale", Range(0,10)) = 3.0
        _NormalBias  ("Normal Edge Bias", Range(0,2)) = 0.4
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" }
        ZWrite Off ZTest Always Cull Off

        Pass
        {
            Name "STW SS Outline"

            HLSLPROGRAM
            #pragma vertex   Vert
            #pragma fragment frag

            // Core.hlsl phải đứng TRƯỚC Blit.hlsl: nó định nghĩa TEXTURE2D_X / SAMPLE_TEXTURE2D_X
            // (texture XR macros) mà Blit.hlsl dùng bên trong — đảo thứ tự sẽ lỗi 'unrecognized TEXTURE2D_X'.
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            // Blit.hlsl: cung cấp Vert/Varyings fullscreen + _BlitTexture + sampler_LinearClamp
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"

            half4 _OutlineColor;
            half  _OutlineThickness;
            half  _DepthScale, _DepthBias, _NormalScale, _NormalBias;

            // Roberts cross — khớp STW_EdgeRoberts* trong OutlineCommon.hlsl (P0).
            half edgeRobertsDepth(float dTL, float dTR, float dBL, float dBR, half scale, half bias)
            {
                half d0 = abs(dTL - dBR);
                half d1 = abs(dTR - dBL);
                return saturate(sqrt(d0*d0 + d1*d1) * scale - bias);
            }
            half edgeRobertsNormal(half3 nTL, half3 nTR, half3 nBL, half3 nBR, half scale, half bias)
            {
                half3 n0 = nTL - nBR;
                half3 n1 = nTR - nBL;
                return saturate(sqrt(dot(n0,n0) + dot(n1,n1)) * scale - bias);
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float2 uv = IN.texcoord;
                // texel theo kích thước target hiện tại (_ScreenParams.xy = w,h) — chắc ăn hơn
                // _BlitTexture_TexelSize (không phải lúc nào Blit.hlsl cũng auto-bind).
                float2 texel = (1.0 / _ScreenParams.xy) * _OutlineThickness;

                float2 uvTL = uv + float2(-texel.x,  texel.y);
                float2 uvTR = uv + float2( texel.x,  texel.y);
                float2 uvBL = uv + float2(-texel.x, -texel.y);
                float2 uvBR = uv + float2( texel.x, -texel.y);

                // Depth (linear eye) — bắt silhouette
                float dTL = LinearEyeDepth(SampleSceneDepth(uvTL), _ZBufferParams);
                float dTR = LinearEyeDepth(SampleSceneDepth(uvTR), _ZBufferParams);
                float dBL = LinearEyeDepth(SampleSceneDepth(uvBL), _ZBufferParams);
                float dBR = LinearEyeDepth(SampleSceneDepth(uvBR), _ZBufferParams);
                half edgeD = edgeRobertsDepth(dTL, dTR, dBL, dBR, _DepthScale, _DepthBias);

                // Normals (world) — bắt crease cùng độ sâu
                half3 nTL = SampleSceneNormals(uvTL);
                half3 nTR = SampleSceneNormals(uvTR);
                half3 nBL = SampleSceneNormals(uvBL);
                half3 nBR = SampleSceneNormals(uvBR);
                half edgeN = edgeRobertsNormal(nTL, nTR, nBL, nBR, _NormalScale, _NormalBias);

                half edge = saturate(max(edgeD, edgeN));

                half4 src = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, uv);
                half3 col = lerp(src.rgb, _OutlineColor.rgb, edge * _OutlineColor.a);
                return half4(col, src.a);
            }
            ENDHLSL
        }
    }
    Fallback Off
}
