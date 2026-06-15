// =============================================================================
//  OutlineCommon.hlsl  —  Stylized Toon World Kit / P0 Core Library
// -----------------------------------------------------------------------------
//  MỤC ĐÍCH: nền cho 2 kiểu outline (P1):
//    (A) INVERTED-HULL (per-material, 1 pass thêm) — phình mesh theo normal rồi
//        vẽ mặt sau màu outline. Rẻ, chạy MỌI platform (kể cả mobile/VR), NHƯNG
//        thêm 1 draw/pass → có thể phá batch khi khác material. Hợp prop/character.
//    (B) SCREEN-SPACE edge (Renderer Feature, 1 fullscreen draw) — so sánh
//        depth + normal pixel lân cận. Đẹp/đồng đều, giữ batch scene, NHƯNG cần
//        DepthNormals prepass + viết kiểu RenderGraph ở C# (U6). Helper edge ở đây.
//
//  GHI CHÚ VR: inverted-hull phải dùng macro stereo của URPCompat (phình ở clip
//  space đúng cho từng mắt). SS outline chạy ở fullscreen pass nên ít lo SPI hơn
//  nhưng vẫn cần đọc đúng eye-index trong RenderGraph (xử ở C#).
// =============================================================================

#ifndef STW_OUTLINE_COMMON_INCLUDED
#define STW_OUTLINE_COMMON_INCLUDED

#ifndef STW_URP_COMPAT_INCLUDED
    #include "URPCompat.hlsl"
#endif

// =============================================================================
//  (A) INVERTED-HULL — tính vị trí clip đã phình theo normal.
// -----------------------------------------------------------------------------
//  width: độ dày outline (đơn vị tuỳ mode bên dưới).
//  mode 0 = world-space (dày theo world, xa nhỏ dần — chân thực).
//  mode 1 = screen-space (dày đều theo pixel bất kể khoảng cách — đồng đều game).
// =============================================================================

// World-space hull: dời vertex theo normal world rồi transform clip.
float4 STW_OutlineHull_World(float3 positionOS, float3 normalOS, half width)
{
    VertexPositionInputs  posIn = GetVertexPositionInputs(positionOS);
    VertexNormalInputs    nrmIn = GetVertexNormalInputs(normalOS);
    float3 positionWS = posIn.positionWS + nrmIn.normalWS * width;
    return TransformWorldToHClip(positionWS);
}

// Screen-space hull: phình trong clip space để dày outline đều theo pixel.
// width tính theo tỉ lệ chiều cao màn hình (vd 0.002). Bù aspect để không méo.
float4 STW_OutlineHull_Screen(float3 positionOS, float3 normalOS, half width)
{
    VertexPositionInputs posIn = GetVertexPositionInputs(positionOS);
    VertexNormalInputs   nrmIn = GetVertexNormalInputs(normalOS);

    float3 normalCS = TransformWorldToHClipDir(nrmIn.normalWS);
    float4 clip = posIn.positionCS;

    float2 offset = normalize(normalCS.xy) * width * clip.w;
    // bù aspect ratio (_ScreenParams.x/y) để outline tròn đều
    offset.x *= _ScreenParams.y / _ScreenParams.x;
    clip.xy += offset;
    return clip;
}

// =============================================================================
//  (B) SCREEN-SPACE EDGE DETECTION — Roberts cross trên depth + normal.
// -----------------------------------------------------------------------------
//  Dùng trong fragment của fullscreen pass (Renderer Feature). Cần sample
//  _CameraDepthTexture + DepthNormals (_CameraNormalsTexture). Trả 0..1 edge.
//  texelSize: 1/width, 1/height. thickness: số pixel toả.
// =============================================================================

// So sánh chênh lệch 4 góc chéo (Roberts cross). depthSamp/normalSamp truyền vào.
half STW_EdgeRobertsDepth(float depthTL, float depthTR, float depthBL, float depthBR, half scale, half bias)
{
    half d0 = abs(depthTL - depthBR);
    half d1 = abs(depthTR - depthBL);
    half edge = sqrt(d0 * d0 + d1 * d1) * scale;
    return saturate(edge - bias);
}

half STW_EdgeRobertsNormal(half3 nTL, half3 nTR, half3 nBL, half3 nBR, half scale, half bias)
{
    half3 n0 = nTL - nBR;
    half3 n1 = nTR - nBL;
    half edge = sqrt(dot(n0, n0) + dot(n1, n1)) * scale;
    return saturate(edge - bias);
}

// Gộp edge depth + normal: lấy max để bắt cả cạnh silhouette lẫn cạnh gấp khúc.
half STW_CombineEdge(half edgeDepth, half edgeNormal)
{
    return saturate(max(edgeDepth, edgeNormal));
}

#endif // STW_OUTLINE_COMMON_INCLUDED
