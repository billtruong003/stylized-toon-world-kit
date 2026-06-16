// =============================================================================
//  StylizedTeleport.shader  —  Stylized Toon World Kit / P3 VFX
// -----------------------------------------------------------------------------
//  Hiệu ứng TELEPORT / SPAWN: vỏ năng-lượng UNLIT trong suốt phủ lên mesh, build
//  dần từ dưới lên theo _Progress, có:
//    • Scanline chạy dọc (cảm giác quét hologram).
//    • Viền sáng (front glow) ở mặt build hiện tại.
//    • Fresnel rim + noise flicker → rung động năng lượng.
//  Additive mặc định. Dùng làm overlay (đặt material thứ 2) lúc nhân vật hiện ra.
//  URP 17 / Unity 6 · SRP Batcher · Instancing · VR SPI · particle vertex color.
// =============================================================================
Shader "StylizedToonWorldKit/VFX/Teleport"
{
    Properties
    {
        [HDR] _BaseColor ("Energy Color", Color) = (0.2,1.4,3.0,1)
        _Progress    ("Build Progress", Range(0,1)) = 0.5
        _Axis        ("Build Axis (0=UV.y,1=World.y)", Range(0,1)) = 0
        _WorldMin    ("World Min Y", Float) = 0
        _WorldMax    ("World Max Y", Float) = 2

        [Header(Front Glow)][Space(4)]
        [HDR] _EdgeColor ("Front Color", Color) = (4,2,0.4,1)
        _EdgeWidth   ("Front Width", Range(0.001,0.6)) = 0.12

        [Header(Scanline)][Space(4)]
        _ScanDensity ("Scan Density", Range(1,200)) = 40
        _ScanSpeed   ("Scan Speed", Range(-20,20)) = 6
        _ScanSharp   ("Scan Sharpness", Range(0.1,8)) = 2

        [Header(Energy Noise)][Space(4)]
        _NoiseScale  ("Noise Scale", Range(0.5,30)) = 6
        _NoiseSpeed  ("Noise Speed", Range(0,5)) = 1.2
        _Fresnel     ("Fresnel Power", Range(0.2,8)) = 2.5
        _Alpha       ("Overall Alpha", Range(0,1)) = 1

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

            #include "../Core/URPCompat.hlsl"
            #include "../Core/StylizedNoise.hlsl"
            #include "../Core/StylizedVFX.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                half  _Progress;
                half  _Axis;
                float _WorldMin;
                float _WorldMax;
                half4 _EdgeColor;
                half  _EdgeWidth;
                half  _ScanDensity;
                half  _ScanSpeed;
                half  _ScanSharp;
                half  _NoiseScale;
                half  _NoiseSpeed;
                half  _Fresnel;
                half  _Alpha;
                half  _SrcBlend; half _DstBlend; half _ZWrite; half _Cull;
            CBUFFER_END

            half4 frag(VFXVaryings IN) : SV_Target
            {
                STW_SETUP_INSTANCE_FRAG(IN);

                // trục build: UV.y hoặc world Y normalize.
                float worldH = saturate((IN.positionWS.y - _WorldMin) / max(STW_EPSILON, _WorldMax - _WorldMin));
                float h = lerp(IN.uv.y, worldH, _Axis);

                // vùng đã hiện (dưới front).
                float front = _Progress;
                float visible = step(h, front);

                // front glow band.
                half band = 1.0h - saturate((front - h) / max(STW_EPSILON, _EdgeWidth));
                band = visible * band * band;

                // scanline + noise flicker.
                half scan  = STW_Scanline(h, _ScanDensity, _ScanSpeed, _ScanSharp, _Time.y);
                half noise = saturate(STW_FBM(IN.uv * _NoiseScale + _Time.y * _NoiseSpeed, 3, 2.0, 0.5));
                half fres  = STW_FresnelVFX(IN.normalWS, IN.viewDirWS, _Fresnel);

                half body = visible * (scan * 0.6h + 0.2h) * (noise * 0.6h + 0.4h);
                half3 color = _BaseColor.rgb * (body + fres * 0.5h) + _EdgeColor.rgb * _EdgeColor.a * band;
                half  alpha = saturate(body + band + fres * 0.4h) * _BaseColor.a * _Alpha;

                color *= IN.color.rgb;
                alpha *= IN.color.a;

                color = STW_ApplyFog(color, IN.fogCoord);
                return half4(color, alpha);
            }
            ENDHLSL
        }
    }

    FallBack Off
    CustomEditor "StylizedToonWorldKit.Editor.TeleportGUI"
}
