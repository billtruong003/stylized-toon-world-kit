// =============================================================================
//  StylizedVFX.hlsl  —  Stylized Toon World Kit / P0 Core Library (VFX support)
// -----------------------------------------------------------------------------
//  MỤC ĐÍCH: nền dùng chung cho pack P3 (VFX/Effects) — các shader UNLIT trong
//  suốt (additive/alpha). Gom phần lặp lại để mỗi shader chỉ còn frag riêng:
//    • VFXAttributes / VFXVaryings: input-output chuẩn (kèm vertex COLOR cho
//      Particle System truyền màu+alpha per-particle).
//    • STW_VFXVert(): vertex stage chung (world pos, view dir, screenPos, fog,
//      VR Single-Pass Instanced) — KHÔNG đụng material property nên dùng được
//      cho mọi shader (UV transform để frag tự làm bằng _XXX_ST của nó).
//    • Helper FX: fresnel, scanline, hex grid, polar UV, soft-particle fade.
//
//  CÁCH DÙNG trong .shader (sau khi #include "URPCompat.hlsl"):
//      #include "StylizedNoise.hlsl"   // nếu cần noise
//      #include "StylizedVFX.hlsl"
//      CBUFFER_START(UnityPerMaterial) ... CBUFFER_END
//      TEXTURE2D(_MainMap); SAMPLER(sampler_MainMap);
//      half4 frag(VFXVaryings IN):SV_Target { ... }
//  Vertex: #pragma vertex STW_VFXVert  (dùng thẳng, không tự viết).
// =============================================================================

#ifndef STW_STYLIZED_VFX_INCLUDED
#define STW_STYLIZED_VFX_INCLUDED

#ifndef STW_URP_COMPAT_INCLUDED
    #include "URPCompat.hlsl"
#endif

// DeclareDepthTexture: SampleSceneDepth() cho soft-particle fade (shield/fire).
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

// -----------------------------------------------------------------------------
//  Input / Output chuẩn cho VFX unlit.
// -----------------------------------------------------------------------------
struct VFXAttributes
{
    float4 positionOS : POSITION;
    float3 normalOS   : NORMAL;
    float2 uv         : TEXCOORD0;
    half4  color      : COLOR;      // particle color/alpha (vertex stream)
    STW_VERTEX_INPUT_INSTANCE_ID
};

struct VFXVaryings
{
    float4 positionCS : SV_POSITION;
    float2 uv         : TEXCOORD0;
    float3 positionWS : TEXCOORD1;
    half3  normalWS   : TEXCOORD2;
    half3  viewDirWS  : TEXCOORD3;
    float4 screenPos  : TEXCOORD4;
    half   fogCoord   : TEXCOORD5;
    half4  color      : TEXCOORD6;
    STW_VERTEX_OUTPUT_STEREO
};

// Vertex stage chung — KHÔNG transform UV (frag tự TRANSFORM_TEX theo map riêng).
VFXVaryings STW_VFXVert(VFXAttributes IN)
{
    VFXVaryings OUT = (VFXVaryings)0;
    STW_SETUP_INSTANCE_VERT(IN, OUT);

    VertexPositionInputs pos = GetVertexPositionInputs(IN.positionOS.xyz);
    VertexNormalInputs   nrm = GetVertexNormalInputs(IN.normalOS);

    OUT.positionCS = pos.positionCS;
    OUT.positionWS = pos.positionWS;
    OUT.normalWS   = nrm.normalWS;
    OUT.viewDirWS  = STW_SafeNormalize(GetWorldSpaceViewDir(pos.positionWS));
    OUT.screenPos  = ComputeScreenPos(pos.positionCS);
    OUT.fogCoord   = ComputeFogFactor(pos.positionCS.z);
    OUT.uv         = IN.uv;
    OUT.color      = IN.color;
    return OUT;
}

// -----------------------------------------------------------------------------
//  HELPER FX.
// -----------------------------------------------------------------------------
// Fresnel (rim) độc lập — không cần lighting include.
half STW_FresnelVFX(half3 normalWS, half3 viewDirWS, half power)
{
    half f = 1.0h - saturate(dot(STW_SafeNormalize(normalWS), STW_SafeNormalize(viewDirWS)));
    return pow(f, max(STW_EPSILON, power));
}

// Scanline (hologram/teleport): dải sáng chạy theo trục, trả 0..1.
//   coord: thường dùng toạ độ dọc (uv.y hoặc world.y). density: số dải.
half STW_Scanline(float coord, half density, half speed, half sharpness, float time)
{
    half s = sin((coord * density - time * speed) * 6.2831853h) * 0.5h + 0.5h;
    return pow(s, max(STW_EPSILON, sharpness));
}

// Hex pattern (force-field/shield): trả khoảng cách tới cạnh hex gần nhất (0 ở
// cạnh, lớn ở tâm) — dùng để vẽ lưới tổ ong. scale = mật độ.
half STW_HexEdge(float2 uv, float scale)
{
    uv *= scale;
    const float2 r = float2(1.0, 1.7320508); // 1, sqrt(3)
    const float2 h = r * 0.5;
    float2 a = fmod(uv, r) - h;
    float2 b = fmod(uv + h, r) - h;
    float2 gv = dot(a, a) < dot(b, b) ? a : b;
    // khoảng cách tới cạnh hex (metric lục giác)
    float2 ag = abs(gv);
    float c = max(dot(ag, normalize(float2(1.0, 1.7320508))), ag.x);
    return 0.5 - c; // ~0.5 ở tâm cell, ~0 ở cạnh
}

// Polar UV (magic circle / radial): x = góc (0..1), y = bán kính.
float2 STW_PolarUV(float2 uv, float2 center)
{
    float2 d = uv - center;
    float  ang = atan2(d.y, d.x) / 6.2831853 + 0.5; // 0..1
    float  rad = length(d) * 2.0;
    return float2(ang, rad);
}

// Soft-particle fade: mềm nơi quad VFX cắt geometry (cần Depth Texture URP).
half STW_SoftParticle(float4 screenPos, half fadeDistance)
{
    float2 uv = screenPos.xy / max(STW_EPSILON, screenPos.w);
    float sceneEye = LinearEyeDepth(SampleSceneDepth(uv), _ZBufferParams);
    float fragEye  = screenPos.w;
    return saturate((sceneEye - fragEye) / max(STW_EPSILON, fadeDistance));
}

#endif // STW_STYLIZED_VFX_INCLUDED
