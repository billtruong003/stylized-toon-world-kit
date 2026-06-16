// =============================================================================
//  StylizedSurface.hlsl  —  Stylized Toon World Kit / P0 Core Library
// -----------------------------------------------------------------------------
//  MỤC ĐÍCH: helper bề mặt/không gian màn hình dùng chung cho water, terrain,
//  glass, dissolve, force-field...
//    • Triplanar mapping (đỡ stretch UV trên terrain/rock).
//    • Height gradient (blend theo độ cao world — snow/sand line).
//    • Depth fade (mềm mép nơi giao mặt nước/khối với scene — cần _CameraDepthTexture).
//    • Screen-space UV (cho refraction/grab, hologram scanline).
//
//  GHI CHÚ: depth-fade & screen UV cần URP bật Depth Texture + Opaque Texture
//  (Renderer settings). README ghi rõ để người dùng bật.
// =============================================================================

#ifndef STW_STYLIZED_SURFACE_INCLUDED
#define STW_STYLIZED_SURFACE_INCLUDED

#ifndef STW_URP_COMPAT_INCLUDED
    #include "URPCompat.hlsl"
#endif

// DeclareDepthTexture cung cấp SampleSceneDepth() + _CameraDepthTexture.
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

// -----------------------------------------------------------------------------
//  TRIPLANAR — sample texture theo 3 trục world rồi blend theo |normal|.
//  TEXTURE2D_PARAM cho phép truyền tex+sampler vào hàm (URP macro).
// -----------------------------------------------------------------------------
half4 STW_Triplanar(TEXTURE2D_PARAM(tex, samp), float3 positionWS, float3 normalWS, float scale, float blendSharpness)
{
    float2 uvX = positionWS.zy * scale;
    float2 uvY = positionWS.xz * scale;
    float2 uvZ = positionWS.xy * scale;

    half4 cX = SAMPLE_TEXTURE2D(tex, samp, uvX.xy);
    half4 cY = SAMPLE_TEXTURE2D(tex, samp, uvY.xy);
    half4 cZ = SAMPLE_TEXTURE2D(tex, samp, uvZ.xy);

    half3 w = pow(abs(normalWS), blendSharpness);
    w /= max(STW_EPSILON, (w.x + w.y + w.z));

    return cX * w.x + cY * w.y + cZ * w.z;
}

// -----------------------------------------------------------------------------
//  HEIGHT GRADIENT — trọng số blend theo độ cao world (vd snow ở trên).
//  worldY: positionWS.y; trả 0..1 mượt giữa [minH, maxH].
// -----------------------------------------------------------------------------
half STW_HeightGradient(float worldY, float minH, float maxH, half sharpness)
{
    half t = saturate((worldY - minH) / max(STW_EPSILON, (maxH - minH)));
    return pow(t, max(STW_EPSILON, sharpness));
}

// Blend theo độ dốc (slope) — vd cỏ ở mặt phẳng, đá ở vách dốc.
half STW_SlopeMask(float3 normalWS, half threshold, half softness)
{
    half up = saturate(normalWS.y);
    half hw = max(STW_EPSILON, softness * 0.5h);
    return smoothstep(threshold - hw, threshold + hw, up);
}

// -----------------------------------------------------------------------------
//  SCREEN-SPACE UV — từ positionCS (clip) hoặc screenPos đã ComputeScreenPos.
// -----------------------------------------------------------------------------
float2 STW_ScreenUV(float4 screenPos)
{
    return screenPos.xy / max(STW_EPSILON, screenPos.w);
}

// -----------------------------------------------------------------------------
//  DEPTH FADE — mềm nơi mặt (nước/force-field) cắt vào geometry phía sau.
//  screenPos: ComputeScreenPos(positionCS) truyền từ vertex.
//  fadeDistance: khoảng (world units) để fade về 0 ở mép giao.
//  Trả 0 ở sát mép → 1 khi đủ xa (nhân vào alpha/foam).
// -----------------------------------------------------------------------------
half STW_DepthFade(float4 screenPos, float3 positionWS, float fadeDistance)
{
    float2 uv = STW_ScreenUV(screenPos);
    float  sceneDepthRaw = SampleSceneDepth(uv);
    float  sceneEyeDepth = LinearEyeDepth(sceneDepthRaw, _ZBufferParams);
    // eye depth của fragment hiện tại
    float  fragEyeDepth  = screenPos.w;
    float  diff = sceneEyeDepth - fragEyeDepth;
    return saturate(diff / max(STW_EPSILON, fadeDistance));
}

// -----------------------------------------------------------------------------
//  PARALLAX (offset) — UV dịch theo view + height, cho iris/crystal nông.
//  viewDirTS: view direction trong tangent space.
// -----------------------------------------------------------------------------
float2 STW_ParallaxOffset(float2 uv, half height, half scale, half3 viewDirTS)
{
    half2 offset = (viewDirTS.xy / max(STW_EPSILON, viewDirTS.z)) * (height * scale);
    return uv + offset;
}

#endif // STW_STYLIZED_SURFACE_INCLUDED
