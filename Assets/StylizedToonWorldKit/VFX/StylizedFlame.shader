// =============================================================================
//  StylizedFlame.shader  —  Stylized Toon World Kit / P3 VFX
// -----------------------------------------------------------------------------
//  LỬA / FLAME stylized — 2 chế độ:
//    • Procedural (mặc định): fBm noise cuộn lên + distortion → ngọn lửa anime,
//      KHÔNG cần texture. Gradient màu 3 chặng (inner→mid→outer) theo độ cao.
//    • Flipbook (keyword _FLIPBOOK): sample sprite sheet _FlameMap (_Cols x _Rows)
//      chạy theo thời gian — cho lửa vẽ tay.
//  Cutout mềm theo độ cao + noise → hình ngọn lửa thon. Additive.
//  URP 17 / Unity 6 · SRP Batcher · Instancing · VR SPI · particle vertex color.
// =============================================================================
Shader "StylizedToonWorldKit/VFX/Flame"
{
    Properties
    {
        [Header(Color Ramp)][Space(4)]
        [HDR] _ColorInner ("Inner Color", Color) = (6,5,1.5,1)
        [HDR] _ColorMid   ("Mid Color", Color) = (5,1.6,0.2,1)
        [HDR] _ColorOuter ("Outer Color", Color) = (1.6,0.1,0.0,1)

        [Header(Procedural Flame)][Space(4)]
        _NoiseScale  ("Noise Scale", Vector) = (3,2,0,0)
        _ScrollSpeed ("Scroll Speed", Range(0,8)) = 2.5
        _Distortion  ("Distortion", Range(0,1)) = 0.25
        _FlameHeight ("Flame Height", Range(0.1,1)) = 0.85
        _FlameSharp  ("Edge Sharpness", Range(0.5,6)) = 2

        [Header(Flipbook (optional))][Space(4)]
        [Toggle(_FLIPBOOK)] _UseFlipbook ("Use Flipbook", Float) = 0
        _FlameMap ("Flipbook Sheet", 2D) = "black" {}
        _Cols ("Columns", Range(1,16)) = 4
        _Rows ("Rows", Range(1,16)) = 4
        _FPS  ("Frames / sec", Range(1,60)) = 24

        _Alpha ("Overall Alpha", Range(0,1)) = 1

        [Header(Render State)][Space(4)]
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("Src Blend", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("Dst Blend", Float) = 1
        [Enum(Off,0,On,1)] _ZWrite ("ZWrite", Float) = 0
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull", Float) = 0
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Transparent" "Queue"="Transparent" "IgnoreProjector"="True" }
        LOD 100

        Pass
        {
            Name "ForwardUnlit"
            Tags { "LightMode"="UniversalForward" }
            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]
            Cull [_Cull]

            HLSLPROGRAM
            #pragma vertex   STW_VFXVert
            #pragma fragment frag
            #pragma target 3.0
            #pragma multi_compile_fog
            #pragma multi_compile_instancing
            #pragma shader_feature_local _FLIPBOOK

            #include "../Core/URPCompat.hlsl"
            #include "../Core/StylizedNoise.hlsl"
            #include "../Core/StylizedVFX.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _FlameMap_ST;
                half4  _ColorInner;
                half4  _ColorMid;
                half4  _ColorOuter;
                float4 _NoiseScale;
                half   _ScrollSpeed;
                half   _Distortion;
                half   _FlameHeight;
                half   _FlameSharp;
                half   _Cols;
                half   _Rows;
                half   _FPS;
                half   _Alpha;
                half   _SrcBlend; half _DstBlend; half _ZWrite; half _Cull;
            CBUFFER_END

            TEXTURE2D(_FlameMap); SAMPLER(sampler_FlameMap);

            // ramp 3 chặng theo t (0 đáy lửa nóng → 1 đỉnh nguội).
            half3 FlameRamp(half t)
            {
                half3 lo = lerp(_ColorInner.rgb, _ColorMid.rgb, saturate(t * 2.0h));
                half3 hi = lerp(_ColorMid.rgb, _ColorOuter.rgb, saturate(t * 2.0h - 1.0h));
                return lerp(lo, hi, step(0.5h, t));
            }

            half4 frag(VFXVaryings IN) : SV_Target
            {
                STW_SETUP_INSTANCE_FRAG(IN);

                half mask; half3 color;

            #if defined(_FLIPBOOK)
                int total = (int)(_Cols * _Rows);
                int frame = (int)floor(_Time.y * _FPS) % max(1, total);
                int col = frame % (int)_Cols;
                int row = (int)_Rows - 1 - frame / (int)_Cols;
                float2 fuv = (TRANSFORM_TEX(IN.uv, _FlameMap) + float2(col, row)) / float2(_Cols, _Rows);
                half4 tex = SAMPLE_TEXTURE2D(_FlameMap, sampler_FlameMap, fuv);
                mask = tex.a * tex.r;
                color = FlameRamp(saturate(1.0h - IN.uv.y)) * tex.rgb;
            #else
                // distort UV ngang theo noise rồi cuộn lên.
                float2 baseUV = IN.uv * _NoiseScale.xy;
                float t = _Time.y * _ScrollSpeed;
                float distort = STW_GradientNoise(baseUV * 0.5 + float2(0, -t * 0.5)) - 0.5;
                float2 nuv = baseUV + float2(distort * _Distortion, -t);
                half n = saturate(STW_FBM(nuv, 3, 2.0, 0.5));

                // hình ngọn lửa: thon dần lên đỉnh, cắt theo độ cao.
                half h = IN.uv.y;
                half shape = saturate((1.0h - h / max(STW_EPSILON, _FlameHeight)));
                half flame = saturate(n * shape * 2.0h);
                mask = pow(flame, _FlameSharp);
                color = FlameRamp(saturate(h / _FlameHeight)) * mask;
            #endif

                color *= IN.color.rgb;
                half alpha = mask * _Alpha * IN.color.a;

                color = STW_ApplyFog(color, IN.fogCoord);
                return half4(color, saturate(alpha));
            }
            ENDHLSL
        }
    }

    FallBack Off
    CustomEditor "StylizedToonWorldKit.Editor.FlameGUI"
}
