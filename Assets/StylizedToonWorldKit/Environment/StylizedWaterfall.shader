// =============================================================================
//  StylizedWaterfall.shader  —  Stylized Toon World Kit / P2 Environment
// -----------------------------------------------------------------------------
//  THÁC NƯỚC (mesh phẳng/cong dọc — uv.y: đỉnh 1 → đáy 0):
//    • Dòng chảy: 2 lớp noise cuộn dọc + distortion → cảm giác nước đổ.
//    • Bọt (foam) toon: dải bọt theo ngưỡng noise + đậm ở đỉnh & chân thác.
//    • Mist/soft fade ở chân thác (soft-particle theo Depth Texture).
//    • Fresnel viền + tint theo main light. Trong suốt (alpha blend).
//  UNLIT transparent. URP 17 / U6 · SRP Batcher · VR SPI.
//  ⚠️ Bật URP Depth Texture cho mist/soft fade ở chân thác.
// =============================================================================
Shader "StylizedToonWorldKit/Environment/Waterfall"
{
    Properties
    {
        [Header(Water Color)][Space(4)]
        _TopColor    ("Top Color", Color) = (0.6,0.85,0.95,0.6)
        _BottomColor ("Bottom Color", Color) = (0.85,0.95,1,0.9)
        _LightTint   ("Main Light Tint", Range(0,1)) = 0.5

        [Header(Flow)][Space(4)]
        _FlowSpeed ("Flow Speed", Range(0,8)) = 2
        _FlowScale ("Flow Scale (xy)", Vector) = (1,2,0,0)
        _Distortion ("Distortion", Range(0,0.3)) = 0.06

        [Header(Foam)][Space(4)]
        _FoamColor ("Foam Color", Color) = (1,1,1,1)
        _FoamScale ("Foam Scale", Range(0.5,30)) = 8
        _FoamCutoff ("Foam Cutoff", Range(0,1)) = 0.55
        _FoamSharp ("Foam Sharpness", Range(0.01,0.5)) = 0.1
        _TopFoam ("Top Foam", Range(0,1)) = 0.4
        _BottomFoam ("Bottom Foam", Range(0,1)) = 0.5

        [Header(Edges and Mist)][Space(4)]
        [HDR] _FresnelColor ("Fresnel Color", Color) = (0.8,0.95,1,1)
        _FresnelPower ("Fresnel Power", Range(0.2,8)) = 2
        _SoftFade ("Soft Particle Fade", Range(0.01,5)) = 0.6
        _Alpha ("Overall Alpha", Range(0,1)) = 1

        [Header(Render State)][Space(4)]
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull", Float) = 0
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Transparent" "Queue"="Transparent" "IgnoreProjector"="True" }
        LOD 200

        Pass
        {
            Name "ForwardUnlit"
            Tags { "LightMode"="UniversalForward" }
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull [_Cull]

            HLSLPROGRAM
            #pragma vertex   vert
            #pragma fragment frag
            #pragma target 3.0
            #pragma multi_compile_fog
            #pragma multi_compile_instancing

            #include "../Core/StylizedLighting.hlsl"   // STW_Fresnel
            #include "../Core/StylizedSurface.hlsl"
            #include "../Core/StylizedNoise.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half4  _TopColor;
                half4  _BottomColor;
                half   _LightTint;
                half   _FlowSpeed;
                float4 _FlowScale;
                half   _Distortion;
                half4  _FoamColor;
                half   _FoamScale;
                half   _FoamCutoff;
                half   _FoamSharp;
                half   _TopFoam;
                half   _BottomFoam;
                half4  _FresnelColor;
                half   _FresnelPower;
                half   _SoftFade;
                half   _Alpha;
                half   _Cull;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
                STW_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                half3  normalWS   : TEXCOORD2;
                half3  viewDirWS  : TEXCOORD3;
                float4 screenPos  : TEXCOORD4;
                half   fogCoord   : TEXCOORD5;
                STW_VERTEX_OUTPUT_STEREO
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT = (Varyings)0;
                STW_SETUP_INSTANCE_VERT(IN, OUT);
                VertexPositionInputs pos = GetVertexPositionInputs(IN.positionOS.xyz);
                OUT.positionCS = pos.positionCS;
                OUT.positionWS = pos.positionWS;
                OUT.normalWS   = TransformObjectToWorldNormal(IN.normalOS);
                OUT.viewDirWS  = STW_SafeNormalize(GetWorldSpaceViewDir(pos.positionWS));
                OUT.uv         = IN.uv;
                OUT.screenPos  = ComputeScreenPos(pos.positionCS);
                OUT.fogCoord   = ComputeFogFactor(pos.positionCS.z);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                STW_SETUP_INSTANCE_FRAG(IN);

                float t = _Time.y * _FlowSpeed;
                float2 fscale = _FlowScale.xy;

                // distortion: noise ngang đẩy UV → dòng nước không thẳng đơ
                float dist = (STW_GradientNoise(IN.uv * fscale * 1.7 + float2(0, t * 0.6)) - 0.5) * _Distortion;

                // 2 lớp noise cuộn xuống (uv.y giảm theo thời gian)
                float2 uv0 = IN.uv * fscale + float2(dist, -t);
                float2 uv1 = IN.uv * fscale * 1.9 + float2(-dist, -t * 1.4);
                half n = saturate(STW_GradientNoise(uv0) * 0.6 + STW_GradientNoise(uv1) * 0.6);

                // màu nền theo chiều cao thác
                half3 baseCol = lerp(_BottomColor.rgb, _TopColor.rgb, saturate(IN.uv.y));
                half baseA   = lerp(_BottomColor.a, _TopColor.a, saturate(IN.uv.y));

                // tint theo main light
                baseCol = lerp(baseCol, baseCol * _MainLightColor.rgb, _LightTint);

                // foam: ngưỡng noise + tăng ở đỉnh (uv.y~1) & chân (uv.y~0)
                half edgeFoam = max(_TopFoam * smoothstep(0.7h, 1.0h, IN.uv.y),
                                    _BottomFoam * smoothstep(0.3h, 0.0h, IN.uv.y));
                half foamN = saturate(n + edgeFoam);
                half foam = smoothstep(_FoamCutoff, _FoamCutoff + _FoamSharp, foamN);

                half3 color = lerp(baseCol, _FoamColor.rgb, foam);

                // fresnel viền
                half fres = STW_Fresnel(IN.normalWS, IN.viewDirWS, _FresnelPower);
                color += fres * _FresnelColor.rgb;

                // alpha + soft fade chân thác (mist nơi cắt geometry)
                half soft = STW_DepthFade(IN.screenPos, IN.positionWS, _SoftFade);
                half alpha = saturate(max(baseA, foam * _FoamColor.a) + fres * _FresnelColor.a);
                alpha *= soft * _Alpha;

                color = STW_ApplyFog(color, IN.fogCoord);
                return half4(color, alpha);
            }
            ENDHLSL
        }
    }

    FallBack Off
    CustomEditor "StylizedToonWorldKit.Editor.WaterfallGUI"
}
