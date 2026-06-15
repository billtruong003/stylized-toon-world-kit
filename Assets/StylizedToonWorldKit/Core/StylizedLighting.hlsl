// =============================================================================
//  StylizedLighting.hlsl  —  Stylized Toon World Kit / P0 Core Library
// -----------------------------------------------------------------------------
//  MỤC ĐÍCH: toàn bộ math toon/cel lighting dùng chung cho P1..P5.
//    • Ramp: step (banding cứng), smooth (banding mềm), texture-ramp (1D LUT).
//    • Half-Lambert (Valve) để mặt tối không đen tịt.
//    • Toon specular (cứng/glossy step) + anisotropic highlight (tóc).
//    • Rim / Fresnel viền phát sáng.
//    • STW_ToonLighting(): gộp main light + additional lights (Forward+) + GI +
//      shadow + rim thành 1 hàm dùng nhanh trong fragment.
//
//  PHỤ THUỘC: URPCompat.hlsl (include trước file này).
//  THAM SỐ: truyền qua struct STWToonSurface + STWToonParams (khai ở dưới) để
//  shader gọi sạch, không nhồi 15 đối số.
// =============================================================================

#ifndef STW_STYLIZED_LIGHTING_INCLUDED
#define STW_STYLIZED_LIGHTING_INCLUDED

#ifndef STW_URP_COMPAT_INCLUDED
    #include "URPCompat.hlsl"
#endif

// -----------------------------------------------------------------------------
//  DỮ LIỆU bề mặt + tham số toon (gói cho gọn).
// -----------------------------------------------------------------------------
struct STWToonSurface
{
    half3  albedo;
    half3  normalWS;     // đã normalize
    half3  viewDirWS;    // hướng tới camera (đã normalize)
    half3  positionWS;
    half   smoothness;   // 0..1 → kích thước highlight
    half   occlusion;    // AO
    half3  emission;
};

struct STWToonParams
{
    half3  shadowTint;       // màu vùng tối (thay vì đen)
    half   rampSteps;        // số bậc cel (vd 2,3,4) cho step ramp
    half   rampSmoothness;   // độ mềm mép ramp (0=cứng,1=gradient)
    half   shadowThreshold;  // ngưỡng N·L chuyển sáng/tối (0..1)
    half   specularStrength; // 0 tắt
    half   specularSize;     // độ rộng highlight (0..1)
    half3  rimColor;
    half   rimPower;         // mũ fresnel (cao = viền mảnh)
    half   rimStrength;      // 0 tắt
    half   giStrength;       // hệ số ambient/SH
};

// -----------------------------------------------------------------------------
//  RAMP helpers — biến N·L liên tục thành bậc cel.
// -----------------------------------------------------------------------------

// Step ramp: chia [0,1] thành 'steps' bậc đều, 'softness' làm mềm mép từng bậc.
half STW_RampStep(half ndotl, half steps, half softness)
{
    steps = max(1.0h, steps);
    half scaled = saturate(ndotl) * steps;
    half lower  = floor(scaled);
    half frac_  = scaled - lower;
    // smoothstep mép giữa 2 bậc theo softness (0 = cạnh cứng)
    half edge   = smoothstep(0.5h - softness * 0.5h, 0.5h + softness * 0.5h, frac_);
    return saturate((lower + edge) / steps);
}

// Smooth ramp: 1 ngưỡng sáng/tối mềm — cel 2 tông kinh điển.
half STW_RampSmooth(half ndotl, half threshold, half softness)
{
    half hw = max(STW_EPSILON, softness * 0.5h);
    return smoothstep(threshold - hw, threshold + hw, ndotl);
}

// Texture ramp: dùng 1D LUT (toon ramp tex) — artist vẽ gradient tùy ý.
// rampTex: TEXTURE2D đã khai ngoài; trả màu theo trục U = halfLambert.
half3 STW_RampTexture(TEXTURE2D_PARAM(rampTex, samplerRamp), half ndotl)
{
    half u = saturate(ndotl * 0.5h + 0.5h); // half-lambert remap vào [0,1]
    return SAMPLE_TEXTURE2D(rampTex, samplerRamp, float2(u, 0.5h)).rgb;
}

// Half-Lambert (Valve): (N·L*0.5+0.5)^2 — wrap sáng quanh vật, tránh đen tịt.
half STW_HalfLambert(half ndotl)
{
    half h = ndotl * 0.5h + 0.5h;
    return h * h;
}

// -----------------------------------------------------------------------------
//  SPECULAR toon — highlight bậc (stylized), và anisotropic cho tóc.
// -----------------------------------------------------------------------------
half STW_ToonSpecular(half3 normalWS, half3 lightDirWS, half3 viewDirWS, half size)
{
    half3 h = STW_SafeNormalize(lightDirWS + viewDirWS);
    half ndh = saturate(dot(normalWS, h));
    half spec = pow(ndh, lerp(256.0h, 8.0h, saturate(size)));
    // step cứng để ra mảng highlight phẳng kiểu anime
    return smoothstep(0.5h - 0.05h, 0.5h + 0.05h, spec);
}

// Anisotropic (tóc): highlight kéo dài theo tangent, có thể shift bằng noise.
half STW_AnisoSpecular(half3 tangentWS, half3 lightDirWS, half3 viewDirWS, half shift, half exponent)
{
    half3 h = STW_SafeNormalize(lightDirWS + viewDirWS);
    half3 t = STW_SafeNormalize(tangentWS);
    half tdh = dot(t, h) + shift;
    half sinTH = sqrt(saturate(1.0h - tdh * tdh));
    return pow(sinTH, max(1.0h, exponent));
}

// -----------------------------------------------------------------------------
//  RIM / FRESNEL — viền phát sáng theo góc nhìn.
// -----------------------------------------------------------------------------
half STW_Fresnel(half3 normalWS, half3 viewDirWS, half power)
{
    half f = 1.0h - saturate(dot(normalWS, viewDirWS));
    return pow(f, max(STW_EPSILON, power));
}

// -----------------------------------------------------------------------------
//  HÀM TỔNG: toon lighting đầy đủ (main + additional Forward+ + GI + rim).
//  shadowCoord/shadowMask: shader tự tính (xem STW_GetShadowCoord ở URPCompat).
// -----------------------------------------------------------------------------
half3 STW_ToonLighting(STWToonSurface s, STWToonParams p, float4 shadowCoord, half4 shadowMask)
{
    // --- Main light ---
    Light mainLight = STW_GetMainLight(shadowCoord, s.positionWS, shadowMask);
    half  atten     = mainLight.shadowAttenuation * mainLight.distanceAttenuation;
    half  ndotl     = dot(s.normalWS, mainLight.direction);

    // ramp bậc cel rồi áp shadow attenuation (giữ banding khi vào bóng)
    half  rampMain  = STW_RampStep(ndotl, p.rampSteps, p.rampSmoothness) * atten;
    half3 litColor  = lerp(p.shadowTint, half3(1,1,1), rampMain) * mainLight.color;

    half3 result = s.albedo * litColor;

    // specular main
    if (p.specularStrength > 0.0h)
    {
        half spec = STW_ToonSpecular(s.normalWS, mainLight.direction, s.viewDirWS, p.specularSize);
        result += spec * p.specularStrength * mainLight.color * rampMain;
    }

    // --- Additional lights (point/spot) — Forward & Forward+ cùng API ---
    uint count = STW_GetAdditionalLightsCount();
#if USE_FORWARD_PLUS
    // Forward+ duyệt qua cluster (URP cung cấp macro vòng lặp)
    LIGHT_LOOP_BEGIN(count)
        Light light = GetAdditionalLight(lightIndex, s.positionWS, shadowMask);
        half a   = light.shadowAttenuation * light.distanceAttenuation;
        half nl  = dot(s.normalWS, light.direction);
        half rmp = STW_RampStep(nl, p.rampSteps, p.rampSmoothness) * a;
        result  += s.albedo * lerp(p.shadowTint, half3(1,1,1), rmp) * light.color * rmp;
    LIGHT_LOOP_END
#else
    for (uint li = 0u; li < count; li++)
    {
        Light light = GetAdditionalLight(li, s.positionWS, shadowMask);
        half a   = light.shadowAttenuation * light.distanceAttenuation;
        half nl  = dot(s.normalWS, light.direction);
        half rmp = STW_RampStep(nl, p.rampSteps, p.rampSmoothness) * a;
        result  += s.albedo * light.color * rmp;
    }
#endif

    // --- GI / Ambient (SH) ---
    half3 gi = SampleSH(s.normalWS) * s.albedo * p.giStrength * s.occlusion;
    result += gi;

    // --- Rim / Fresnel ---
    if (p.rimStrength > 0.0h)
    {
        half rim = STW_Fresnel(s.normalWS, s.viewDirWS, p.rimPower);
        // rim chỉ ăn ở phần sáng để không loé trong bóng
        result += rim * p.rimColor * p.rimStrength * saturate(rampMain + 0.25h);
    }

    // --- Emission ---
    result += s.emission;

    return result;
}

#endif // STW_STYLIZED_LIGHTING_INCLUDED
