// =============================================================================
//  StylizedHologram.shader  —  Stylized Toon World Kit / P3 VFX
// -----------------------------------------------------------------------------
//  HOLOGRAM: vỏ UNLIT trong suốt cho hiệu ứng chiếu ảnh sci-fi:
//    • Scanline ngang chạy + fresnel rim.
//    • Glitch: dịch UV ngang theo band noise (random nhảy hình).
//    • Flicker: nhấp nháy độ sáng theo thời gian.
//    • Tuỳ chọn texture nội dung (_BaseMap) hoặc thuần màu.
//  Alpha-blend mặc định (giữ chi tiết tối). URP 17 / Unity 6 · SRP Batcher · VR SPI.
// =============================================================================
Shader "StylizedToonWorldKit/VFX/Hologram"
{
    Properties
    {
        [MainTexture] _BaseMap ("Base Map", 2D) = "white" {}
        [HDR] _Color   ("Hologram Color", Color) = (0.3,1.4,1.8,1)
        _FresnelColor ("Fresnel Color", Color) = (0.6,2.0,2.4,1)
        _FresnelPower ("Fresnel Power", Range(0.2,8)) = 2

        [Header(Scanlines)][Space(4)]
        _ScanDensity ("Scan Density", Range(1,400)) = 120
        _ScanSpeed   ("Scan Speed", Range(-20,20)) = 4
        _ScanSharp   ("Scan Sharpness", Range(0.1,8)) = 1
        _ScanStrength("Scan Strength", Range(0,1)) = 0.5

        [Header(Glitch)][Space(4)]
        _GlitchAmount ("Glitch Amount", Range(0,0.3)) = 0.04
        _GlitchSpeed  ("Glitch Speed", Range(0,30)) = 8
        _GlitchBands  ("Glitch Bands", Range(1,60)) = 12

        [Header(Flicker)][Space(4)]
        _Flicker  ("Flicker Amount", Range(0,1)) = 0.15
        _FlickerSpeed ("Flicker Speed", Range(0,40)) = 14
        _Alpha ("Overall Alpha", Range(0,1)) = 0.8

        [Header(Render State)][Space(4)]
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("Src Blend", Float) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("Dst Blend", Float) = 10
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

            #include "../Core/URPCompat.hlsl"
            #include "../Core/StylizedNoise.hlsl"
            #include "../Core/StylizedVFX.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4  _Color;
                half4  _FresnelColor;
                half   _FresnelPower;
                half   _ScanDensity;
                half   _ScanSpeed;
                half   _ScanSharp;
                half   _ScanStrength;
                half   _GlitchAmount;
                half   _GlitchSpeed;
                half   _GlitchBands;
                half   _Flicker;
                half   _FlickerSpeed;
                half   _Alpha;
                half   _SrcBlend; half _DstBlend; half _ZWrite; half _Cull;
            CBUFFER_END

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);

            half4 frag(VFXVaryings IN) : SV_Target
            {
                STW_SETUP_INSTANCE_FRAG(IN);

                // glitch: dịch UV ngang theo band hash (nhảy theo thời gian).
                float band = floor(IN.uv.y * _GlitchBands);
                float gh = STW_Hash21(float2(band, floor(_Time.y * _GlitchSpeed)));
                float shift = (gh - 0.5) * 2.0 * _GlitchAmount * step(0.7, gh);
                float2 uv = TRANSFORM_TEX(IN.uv, _BaseMap) + float2(shift, 0);

                half4 tex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv);
                half3 color = tex.rgb * _Color.rgb;

                // scanline.
                half scan = STW_Scanline(IN.uv.y, _ScanDensity, _ScanSpeed, _ScanSharp, _Time.y);
                half scanMul = lerp(1.0h, scan, _ScanStrength);
                color *= scanMul;

                // fresnel rim.
                half fres = STW_FresnelVFX(IN.normalWS, IN.viewDirWS, _FresnelPower);
                color += _FresnelColor.rgb * fres;

                // flicker (nhấp nháy toàn cục).
                half flick = 1.0h - _Flicker * (STW_Hash11(floor(_Time.y * _FlickerSpeed)) );
                color *= flick;

                half alpha = saturate(tex.a * _Color.a * scanMul + fres * _FresnelColor.a) * _Alpha * flick;

                color *= IN.color.rgb;
                alpha *= IN.color.a;

                color = STW_ApplyFog(color, IN.fogCoord);
                return half4(color, saturate(alpha));
            }
            ENDHLSL
        }
    }

    FallBack Off
    CustomEditor "StylizedToonWorldKit.Editor.HologramGUI"
}
