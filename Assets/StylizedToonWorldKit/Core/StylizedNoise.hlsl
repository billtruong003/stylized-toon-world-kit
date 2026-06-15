// =============================================================================
//  StylizedNoise.hlsl  —  Stylized Toon World Kit / P0 Core Library
// -----------------------------------------------------------------------------
//  MỤC ĐÍCH: noise & motion helpers cho VFX (dissolve/fire/magic), nước, mây,
//  grass wind... — dùng chung P2/P3/P4.
//    • Hash (1D/2D/3D) không cần texture (GPU-friendly, deterministic).
//    • Value noise, Gradient (Perlin-like) noise, Voronoi (cellular).
//    • fBm (fractal sum) nhiều octave.
//    • Panner (cuộn UV theo thời gian) + Flow (distort theo flow map).
//
//  GHI CHÚ PERF: noise procedural rẻ hơn sample texture trên mobile khi octave
//  thấp; octave cao (fBm 5+) thì nên bake ra texture. Tài liệu README ghi rõ.
// =============================================================================

#ifndef STW_STYLIZED_NOISE_INCLUDED
#define STW_STYLIZED_NOISE_INCLUDED

#ifndef STW_URP_COMPAT_INCLUDED
    #include "URPCompat.hlsl"
#endif

// -----------------------------------------------------------------------------
//  HASH — pseudo-random từ toạ độ. Hằng số kiểu "fract sine" phổ biến, ổn định
//  trên đa số GPU mobile/PC (tránh sin precision kém thì có bản dot-fract).
// -----------------------------------------------------------------------------
float STW_Hash11(float p)
{
    p = frac(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return frac(p);
}

float STW_Hash21(float2 p)
{
    float3 p3 = frac(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return frac((p3.x + p3.y) * p3.z);
}

float2 STW_Hash22(float2 p)
{
    float3 p3 = frac(float3(p.xyx) * float3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return frac((p3.xx + p3.yz) * p3.zy);
}

float STW_Hash31(float3 p)
{
    p = frac(p * 0.1031);
    p += dot(p, p.zyx + 31.32);
    return frac((p.x + p.y) * p.z);
}

// -----------------------------------------------------------------------------
//  VALUE NOISE — nội suy hash tại các góc lưới (smoothstep fade).
// -----------------------------------------------------------------------------
float STW_ValueNoise(float2 uv)
{
    float2 i = floor(uv);
    float2 f = frac(uv);
    float2 u = f * f * (3.0 - 2.0 * f); // smoothstep
    float a = STW_Hash21(i + float2(0,0));
    float b = STW_Hash21(i + float2(1,0));
    float c = STW_Hash21(i + float2(0,1));
    float d = STW_Hash21(i + float2(1,1));
    return lerp(lerp(a, b, u.x), lerp(c, d, u.x), u.y);
}

// -----------------------------------------------------------------------------
//  GRADIENT NOISE (Perlin-like) — mượt hơn value noise, hợp mây/khói/flow.
// -----------------------------------------------------------------------------
float STW_GradientNoise(float2 uv)
{
    float2 i = floor(uv);
    float2 f = frac(uv);
    float2 u = f * f * (3.0 - 2.0 * f);

    float2 ga = STW_Hash22(i + float2(0,0)) * 2.0 - 1.0;
    float2 gb = STW_Hash22(i + float2(1,0)) * 2.0 - 1.0;
    float2 gc = STW_Hash22(i + float2(0,1)) * 2.0 - 1.0;
    float2 gd = STW_Hash22(i + float2(1,1)) * 2.0 - 1.0;

    float va = dot(ga, f - float2(0,0));
    float vb = dot(gb, f - float2(1,0));
    float vc = dot(gc, f - float2(0,1));
    float vd = dot(gd, f - float2(1,1));

    return lerp(lerp(va, vb, u.x), lerp(vc, vd, u.x), u.y) * 0.5 + 0.5;
}

// -----------------------------------------------------------------------------
//  VORONOI (cellular) — trả khoảng cách tới điểm gần nhất (F1). Cho caustic,
//  vảy băng, crack, cell nước. 'angleOffset' để animate ô.
// -----------------------------------------------------------------------------
float STW_Voronoi(float2 uv, float angleOffset)
{
    float2 i = floor(uv);
    float2 f = frac(uv);
    float minDist = 8.0;
    [unroll]
    for (int y = -1; y <= 1; y++)
    {
        [unroll]
        for (int x = -1; x <= 1; x++)
        {
            float2 n = float2(x, y);
            float2 p = STW_Hash22(i + n);
            // animate điểm cell theo offset
            p = 0.5 + 0.5 * sin(angleOffset + 6.2831 * p);
            float2 diff = n + p - f;
            minDist = min(minDist, dot(diff, diff));
        }
    }
    return sqrt(minDist);
}

// -----------------------------------------------------------------------------
//  fBm — tổng nhiều octave gradient noise (clouds, smoke, dissolve mask).
// -----------------------------------------------------------------------------
float STW_FBM(float2 uv, int octaves, float lacunarity, float gain)
{
    float sum = 0.0;
    float amp = 0.5;
    float freq = 1.0;
    [loop]
    for (int o = 0; o < octaves; o++)
    {
        sum += amp * STW_GradientNoise(uv * freq);
        freq *= lacunarity;
        amp  *= gain;
    }
    return sum;
}

// -----------------------------------------------------------------------------
//  MOTION helpers.
// -----------------------------------------------------------------------------
// Panner: cuộn UV theo thời gian (dùng _Time.y truyền vào để giữ purity).
float2 STW_Panner(float2 uv, float2 direction, float speed, float time)
{
    return uv + direction * speed * time;
}

// Flow: distort UV theo flow vector (flow map .rg dạng -1..1) + thời gian tuần
// hoàn 2 phase (kỹ thuật flow-map của Valve) — trả 2 lớp + trọng số blend.
void STW_Flow(float2 uv, float2 flowDir, float time, float speed,
              out float2 uv0, out float2 uv1, out float weight)
{
    float t = time * speed;
    float phase0 = frac(t);
    float phase1 = frac(t + 0.5);
    uv0 = uv - flowDir * phase0;
    uv1 = uv - flowDir * phase1;
    weight = abs(0.5 - phase0) * 2.0; // tam giác blend giữa 2 phase
}

#endif // STW_STYLIZED_NOISE_INCLUDED
