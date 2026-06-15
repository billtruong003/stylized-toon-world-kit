// =============================================================================
//  URPCompat.hlsl  —  Stylized Toon World Kit / P0 Core Library
// -----------------------------------------------------------------------------
//  MỤC ĐÍCH (single source of truth cho mọi shader trong kit):
//    • Include đúng các ShaderLibrary lõi của URP (Core / Lighting / Shadows).
//    • Che khác biệt version (URP 12 / 14 / 17 — Unity 2021 / 2022 / 6) bằng macro.
//    • Bật đúng pragma cho: Forward & Forward+ (cluster light), GPU Instancing,
//      VR Single-Pass Instanced (SPI) stereo, fog, shadow cascade, lightmap/GI.
//    • Cung cấp macro stereo/instancing gọn để Attributes/Varyings của mọi shader
//      khai báo nhất quán (đỡ lặp, đỡ quên → tránh lỗi VR lệch mắt).
//
//  CÁCH DÙNG:
//    #include "URPCompat.hlsl"  (ĐẦU TIÊN trong khối HLSLPROGRAM, trước core khác)
//    Trong Attributes  : STW_VERTEX_INPUT_INSTANCE_ID
//    Trong Varyings    : STW_VERTEX_OUTPUT_STEREO
//    Đầu vertex shader : STW_SETUP_INSTANCE_VERT(IN, OUT)
//    Đầu fragment      : STW_SETUP_INSTANCE_FRAG(IN)
//
//  GHI CHÚ VERSION (xem memory `unity-shader-version-gotchas`):
//    • URP 17 / U6: Forward+ là default → cần keyword _FORWARD_PLUS. Renderer
//      Feature (SS outline/post) BẮT BUỘC RenderGraph (xử lý ở file C# riêng, không ở đây).
//    • Mọi material property phải nằm trong CBUFFER_START(UnityPerMaterial) → SRP Batcher.
//    • Dùng macro TEXTURE2D/SAMPLER/SAMPLE_TEXTURE2D (không sampler2D/tex2D Built-in).
// =============================================================================

#ifndef STW_URP_COMPAT_INCLUDED
#define STW_URP_COMPAT_INCLUDED

// --- Core URP ShaderLibrary -------------------------------------------------
// Đường dẫn package ổn định từ URP 10+ (U2020.2) tới URP 17 (U6). Tên file không
// đổi giữa các version; nội dung hàm có đổi → ta bọc qua wrapper bên dưới.
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"

// =============================================================================
//  PRAGMA HELPER (copy khối này vào từng Pass — pragma KHÔNG include được)
// -----------------------------------------------------------------------------
//  HLSL không cho #pragma trong include theo cách dùng lại được; nên ta để đây
//  như "checklist chuẩn" để dán vào mỗi Pass ForwardLit:
//
//      // -- Lighting / GI keywords (URP) --
//      #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
//      #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
//      #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
//      #pragma multi_compile_fragment _ _SHADOWS_SOFT
//      #pragma multi_compile _ _FORWARD_PLUS                     // Forward+ cluster (U6 default)
//      #pragma multi_compile _ _REFLECTION_PROBE_BLENDING _REFLECTION_PROBE_BOX_PROJECTION
//      #pragma multi_compile _ LIGHTMAP_ON DYNAMICLIGHTMAP_ON
//      #pragma multi_compile _ DIRLIGHTMAP_COMBINED
//      #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
//      #pragma multi_compile_fog
//      // -- Instancing + VR Single-Pass Instanced --
//      #pragma multi_compile_instancing
//      #pragma instancing_options renderinglayer
//      #pragma multi_compile _ DOTS_INSTANCING_ON
// =============================================================================

// =============================================================================
//  VR SINGLE-PASS INSTANCED (SPI) + GPU INSTANCING — macro gọn, nhất quán
// -----------------------------------------------------------------------------
//  Các macro UNITY_* gốc nằm trong Core.hlsl (qua UnityInstancing.hlsl). Ta gói
//  lại tên ngắn STW_* để mọi shader khai báo giống nhau → không quên bước nào
//  (thiếu 1 macro = VR render lệch / chỉ 1 mắt).
// =============================================================================

// Đặt trong struct Attributes (input vertex)
#define STW_VERTEX_INPUT_INSTANCE_ID  UNITY_VERTEX_INPUT_INSTANCE_ID

// Đặt trong struct Varyings (vertex -> fragment)
#define STW_VERTEX_OUTPUT_STEREO \
    UNITY_VERTEX_INPUT_INSTANCE_ID \
    UNITY_VERTEX_OUTPUT_STEREO

// Đầu vertex shader: lấy instance id từ IN, ghi stereo + instance id vào OUT
#define STW_SETUP_INSTANCE_VERT(IN, OUT) \
    UNITY_SETUP_INSTANCE_ID(IN); \
    UNITY_TRANSFER_INSTANCE_ID(IN, OUT); \
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT)

// Đầu fragment shader: set eye index để sample đúng mắt VR
#define STW_SETUP_INSTANCE_FRAG(IN) \
    UNITY_SETUP_INSTANCE_ID(IN); \
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN)

// =============================================================================
//  WRAPPER HÀM LIGHTING / SHADOW — che signature đổi theo version
// -----------------------------------------------------------------------------
//  GetMainLight()/GetAdditionalLight() ổn định từ URP 10→17. Wrapper để nếu
//  version sau đổi signature ta chỉ sửa 1 chỗ. Mặc định gọi thẳng API URP.
// =============================================================================

// Lấy shadow coord cho main light: URP 17 hỗ trợ screen-space shadow
// (_MAIN_LIGHT_SHADOWS_SCREEN) — TransformWorldToShadowCoord tự xử khi keyword bật.
float4 STW_GetShadowCoord(float3 positionWS, float4 positionCS)
{
#if defined(_MAIN_LIGHT_SHADOWS_SCREEN) && !defined(_SURFACE_TYPE_TRANSPARENT)
    return ComputeScreenPos(positionCS);
#else
    return TransformWorldToShadowCoord(positionWS);
#endif
}

// Main light đã kèm shadow + light-cookie attenuation (URP chuẩn).
Light STW_GetMainLight(float4 shadowCoord, float3 positionWS, half4 shadowMask)
{
#if defined(_MAIN_LIGHT_SHADOWS) || defined(_MAIN_LIGHT_SHADOWS_CASCADE) || defined(_MAIN_LIGHT_SHADOWS_SCREEN)
    return GetMainLight(shadowCoord, positionWS, shadowMask);
#else
    return GetMainLight();
#endif
}

// Số additional light — bọc vì Forward+ dùng path khác (URP tự xử qua macro
// GetAdditionalLightsCount() khi _FORWARD_PLUS bật). Trả uint chuẩn URP.
uint STW_GetAdditionalLightsCount()
{
    return GetAdditionalLightsCount();
}

// =============================================================================
//  FOG — wrapper áp fog đúng kiểu URP (MixFog) cho cả Forward/Forward+
// =============================================================================
half3 STW_ApplyFog(half3 color, float fogCoord)
{
    return MixFog(color, fogCoord);
}

// =============================================================================
//  TIỆN ÍCH chung — clamp an toàn, safe-normalize, luminance.
// =============================================================================
#define STW_EPSILON 1e-5

half3 STW_SafeNormalize(half3 v)
{
    half len = max(STW_EPSILON, length(v));
    return v / len;
}

half STW_Luminance(half3 c)
{
    return dot(c, half3(0.2126h, 0.7152h, 0.0722h));
}

#endif // STW_URP_COMPAT_INCLUDED
