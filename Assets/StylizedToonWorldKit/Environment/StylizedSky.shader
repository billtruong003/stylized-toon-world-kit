// =============================================================================
//  StylizedSky.shader  —  Stylized Toon World Kit / P2 Environment
// -----------------------------------------------------------------------------
//  BẦU TRỜI / MÂY (sky dome mesh — gắn vào quả cầu lật mặt trong):
//    • Gradient 3 chặng: chân trời → giữa → đỉnh trời (anime sky band).
//    • Mây fBm cuộn 2 lớp + ngưỡng hoá toon (mép mây sắc kiểu cel).
//    • Đĩa mặt trời + quầng sáng theo hướng _MainLightPosition.
//    • Day-night: pha trộn bảng màu ngày/đêm theo độ cao mặt trời (sunY).
//  UNLIT, vẽ nền (Background queue, ZWrite Off, Cull Front). Không fog.
//  ⚠️ Dùng cho DOME MESH (không phải Skybox material slot). URP 17 / U6 · VR SPI.
// =============================================================================
Shader "StylizedToonWorldKit/Environment/Sky"
{
    Properties
    {
        [Header(Sky Gradient - Day)][Space(4)]
        [HDR] _HorizonDay ("Horizon (Day)", Color) = (0.85,0.9,1,1)
        [HDR] _MidDay     ("Mid (Day)", Color)     = (0.4,0.65,1,1)
        [HDR] _ZenithDay  ("Zenith (Day)", Color)  = (0.15,0.35,0.85,1)
        [Header(Sky Gradient - Night)][Space(4)]
        [HDR] _HorizonNight ("Horizon (Night)", Color) = (0.1,0.12,0.22,1)
        [HDR] _MidNight     ("Mid (Night)", Color)     = (0.04,0.05,0.13,1)
        [HDR] _ZenithNight  ("Zenith (Night)", Color)  = (0.01,0.01,0.05,1)
        _GradientPower ("Gradient Power", Range(0.2,4)) = 1
        _HorizonSharp  ("Horizon Sharpness", Range(0.2,8)) = 2

        [Header(Sun)][Space(4)]
        [HDR] _SunColor ("Sun Color", Color) = (1,0.95,0.8,1)
        _SunSize  ("Sun Size", Range(0.001,0.3)) = 0.04
        _SunHalo  ("Sun Halo Size", Range(0,2)) = 0.5
        _SunHaloStrength ("Sun Halo Strength", Range(0,4)) = 1

        [Header(Clouds)][Space(4)]
        [Toggle(_CLOUDS)] _CloudsToggle ("Enable Clouds", Float) = 1
        [HDR] _CloudColor ("Cloud Color", Color) = (1,1,1,1)
        [HDR] _CloudShadow ("Cloud Shadow Color", Color) = (0.6,0.65,0.78,1)
        _CloudScale  ("Cloud Scale", Range(0.2,8)) = 2
        _CloudSpeed  ("Cloud Speed", Range(0,1)) = 0.05
        _CloudCover  ("Cloud Cover", Range(0,1)) = 0.5
        _CloudSharp  ("Cloud Edge Sharpness", Range(0.01,0.5)) = 0.08
        _CloudHeight ("Cloud Band Height", Range(0,1)) = 0.3
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Background" "Queue"="Background" }
        LOD 100

        Pass
        {
            Name "Sky"
            Tags { "LightMode"="UniversalForward" }
            ZWrite Off
            Cull Front   // vẽ mặt trong quả cầu dome

            HLSLPROGRAM
            #pragma vertex   vert
            #pragma fragment frag
            #pragma target 3.0
            #pragma shader_feature_local _CLOUDS
            #pragma multi_compile_instancing

            #include "../Core/StylizedNoise.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half4 _HorizonDay; half4 _MidDay; half4 _ZenithDay;
                half4 _HorizonNight; half4 _MidNight; half4 _ZenithNight;
                half  _GradientPower;
                half  _HorizonSharp;
                half4 _SunColor;
                half  _SunSize;
                half  _SunHalo;
                half  _SunHaloStrength;
                half4 _CloudColor;
                half4 _CloudShadow;
                half  _CloudScale;
                half  _CloudSpeed;
                half  _CloudCover;
                half  _CloudSharp;
                half  _CloudHeight;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                STW_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 dirWS      : TEXCOORD0; // hướng từ tâm dome ra (object-space dir)
                STW_VERTEX_OUTPUT_STEREO
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT = (Varyings)0;
                STW_SETUP_INSTANCE_VERT(IN, OUT);
                OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.dirWS = normalize(TransformObjectToWorld(IN.positionOS.xyz) - GetCameraPositionWS());
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                STW_SETUP_INSTANCE_FRAG(IN);

                half3 dir = STW_SafeNormalize(IN.dirWS);
                half h = saturate(dir.y);   // 0 chân trời → 1 đỉnh

                // mặt trời + độ cao mặt trời (day-night blend)
                half3 sunDir = STW_SafeNormalize(_MainLightPosition.xyz);
                half sunY = saturate(sunDir.y * 0.5h + 0.5h);            // 0 đêm → 1 trưa
                half dayFactor = smoothstep(0.45h, 0.6h, sunY);

                // gradient 3 chặng (horizon→mid→zenith) cho cả ngày & đêm
                half hp = pow(h, _GradientPower);
                half hb = pow(h, _HorizonSharp);
                half3 dayCol   = lerp(lerp(_HorizonDay.rgb, _MidDay.rgb, hb), _ZenithDay.rgb, hp);
                half3 nightCol = lerp(lerp(_HorizonNight.rgb, _MidNight.rgb, hb), _ZenithNight.rgb, hp);
                half3 color = lerp(nightCol, dayCol, dayFactor);

                // mặt trời + halo
                half sd = saturate(dot(dir, sunDir));
                half disk = smoothstep(1.0h - _SunSize, 1.0h - _SunSize * 0.5h, sd);
                half halo = pow(saturate(sd), lerp(256.0h, 4.0h, saturate(_SunHalo)));
                color += _SunColor.rgb * (disk + halo * _SunHaloStrength) * (0.2h + dayFactor);

                // mây fBm 2 lớp, ngưỡng toon, chỉ ở dải gần chân trời→giữa
            #if defined(_CLOUDS)
                float2 cuv = dir.xz / max(0.15, dir.y + 0.15);  // chiếu vòm phẳng (đỡ dồn ở đỉnh)
                cuv *= _CloudScale;
                float t = _Time.y * _CloudSpeed;
                float n = STW_FBM(cuv + float2(t, t * 0.3), 5, 2.0, 0.5);
                n += 0.5 * STW_FBM(cuv * 2.0 - float2(t * 0.7, t), 3, 2.0, 0.5);
                n = saturate(n / 1.5);
                half cover = 1.0h - _CloudCover;
                half cloudMask = smoothstep(cover, cover + _CloudSharp, n);
                // dải mây: đậm gần chân trời, mỏng ở đỉnh theo _CloudHeight
                half band = saturate(1.0h - abs(h - _CloudHeight) / max(STW_EPSILON, _CloudHeight + 0.4h));
                cloudMask *= band;
                half3 cloudCol = lerp(_CloudShadow.rgb, _CloudColor.rgb, dayFactor);
                color = lerp(color, cloudCol, cloudMask);
            #endif

                return half4(color, 1);
            }
            ENDHLSL
        }
    }

    FallBack Off
    CustomEditor "StylizedToonWorldKit.Editor.SkyGUI"
}
