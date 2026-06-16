// =============================================================================
//  StylizedLiquid.shader  —  Stylized Toon World Kit / P4 Surface
// -----------------------------------------------------------------------------
//  CHẤT LỎNG / POTION trong bình (transparent, 2 mặt):
//    • Fill level: clip theo trục Y object-space → mực chất lỏng đổ vơi/đầy,
//      có wobble sin (lắc nhẹ theo world X/Z).
//    • Surface band: dải foam/màng sáng ngay mặt thoáng (nơi clip).
//    • Depth gradient: nông→sâu theo nghịch-fresnel (giả độ dày khối lỏng).
//    • Bubble: bọt nổi bằng voronoi cuộn lên + fresnel rim viền.
//  Transparent (alpha blend, ZWrite Off). Cull Off mặc định (nhìn xuyên thành).
//  URP 17 / Unity 6 · SRP Batcher · VR SPI.
// =============================================================================
Shader "StylizedToonWorldKit/Surface/Liquid"
{
    Properties
    {
        [Header(Body Color)][Space(4)]
        [HDR] _ShallowColor ("Shallow Color", Color) = (0.5,0.95,0.4,0.7)
        [HDR] _DeepColor    ("Deep Color", Color)    = (0.1,0.5,0.15,0.95)
        _DepthPower    ("Depth Power", Range(0.2,6)) = 2

        [Header(Fill Level)][Space(4)]
        _FillLevel     ("Fill Level (object Y)", Range(-2,2)) = 0
        _WaveAmp       ("Wobble Amplitude", Range(0,0.5)) = 0.04
        _WaveFreq      ("Wobble Frequency", Range(0,20)) = 6
        _WaveSpeed     ("Wobble Speed", Range(0,8)) = 2

        [Header(Surface Band)][Space(4)]
        [HDR] _SurfaceColor ("Surface Color", Color) = (0.8,1,0.6,1)
        _SurfaceBand   ("Surface Band Width", Range(0.001,0.5)) = 0.06
        _SurfaceStrength ("Surface Strength", Range(0,4)) = 1.5

        [Header(Bubbles)][Space(4)]
        [Toggle(_BUBBLE)] _BubbleToggle ("Enable Bubbles", Float) = 1
        [HDR] _BubbleColor ("Bubble Color", Color) = (1,1,1,1)
        _BubbleScale   ("Bubble Scale", Range(1,40)) = 10
        _BubbleSpeed   ("Bubble Rise Speed", Range(0,4)) = 0.6
        _BubbleStrength ("Bubble Strength", Range(0,3)) = 0.8

        [Header(Rim and Lighting)][Space(4)]
        [HDR] _RimColor ("Rim Color", Color) = (0.7,1,0.6,1)
        _RimPower      ("Rim Power", Range(0.2,8)) = 2.5
        _RimStrength   ("Rim Strength", Range(0,3)) = 1
        _GIStrength    ("GI Strength", Range(0,2)) = 0.8

        [Header(Render State)][Space(4)]
        _Alpha         ("Overall Alpha", Range(0,1)) = 1
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull", Float) = 0
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Transparent" "Queue"="Transparent" "IgnoreProjector"="True" }
        LOD 200

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull [_Cull]

            HLSLPROGRAM
            #pragma vertex   vert
            #pragma fragment frag
            #pragma target 3.0

            #pragma shader_feature_local _BUBBLE

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fog
            #pragma multi_compile_instancing

            #include "../Core/StylizedLighting.hlsl"
            #include "../Core/StylizedNoise.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half4  _ShallowColor;
                half4  _DeepColor;
                half   _DepthPower;
                half   _FillLevel;
                half   _WaveAmp;
                half   _WaveFreq;
                half   _WaveSpeed;
                half4  _SurfaceColor;
                half   _SurfaceBand;
                half   _SurfaceStrength;
                half4  _BubbleColor;
                half   _BubbleScale;
                half   _BubbleSpeed;
                half   _BubbleStrength;
                half4  _RimColor;
                half   _RimPower;
                half   _RimStrength;
                half   _GIStrength;
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
                float3 positionOS : TEXCOORD3;
                half   fogCoord   : TEXCOORD4;
                STW_VERTEX_OUTPUT_STEREO
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT = (Varyings)0;
                STW_SETUP_INSTANCE_VERT(IN, OUT);

                VertexPositionInputs pos = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs   nrm = GetVertexNormalInputs(IN.normalOS);

                OUT.positionCS = pos.positionCS;
                OUT.positionWS = pos.positionWS;
                OUT.normalWS   = nrm.normalWS;
                OUT.positionOS = IN.positionOS.xyz;
                OUT.uv         = IN.uv;
                OUT.fogCoord   = ComputeFogFactor(pos.positionCS.z);
                return OUT;
            }

            half4 frag(Varyings IN, FRONT_FACE_TYPE cullFace : FRONT_FACE_SEMANTIC) : SV_Target
            {
                STW_SETUP_INSTANCE_FRAG(IN);

                // --- fill line (object Y) + wobble theo world XZ ---
                half wobble = sin(IN.positionWS.x * _WaveFreq + _Time.y * _WaveSpeed) * _WaveAmp
                            + sin(IN.positionWS.z * _WaveFreq * 1.3h - _Time.y * _WaveSpeed * 0.7h) * _WaveAmp;
                half fillY = _FillLevel + wobble;
                clip(fillY - IN.positionOS.y);   // bỏ phần trên mặt thoáng

                // normal 2 mặt: backface lật để lighting đúng (macro URP, cross-platform)
                half faceSign = IS_FRONT_VFACE(cullFace, 1.0h, -1.0h);
                half3 normalWS = STW_SafeNormalize(IN.normalWS) * faceSign;
                half3 viewDirWS = STW_SafeNormalize(GetWorldSpaceViewDir(IN.positionWS));

                // --- depth gradient theo độ dày (nghịch fresnel) ---
                half facingV = saturate(dot(normalWS, viewDirWS));
                half depthGrad = pow(1.0h - facingV, _DepthPower);
                half4 body = lerp(_ShallowColor, _DeepColor, depthGrad);

                // --- toon lighting đơn (main light ramp 2 tông mềm) ---
                float4 shadowCoord = TransformWorldToShadowCoord(IN.positionWS);
                half4 sm = half4(1,1,1,1);
                Light ml = STW_GetMainLight(shadowCoord, IN.positionWS, sm);
                half atten = ml.shadowAttenuation * ml.distanceAttenuation;
                half ndotl = STW_HalfLambert(dot(normalWS, ml.direction)) * atten;
                half3 color = body.rgb * (0.45h + 0.55h * ndotl) * ml.color;
                color += SampleSH(normalWS) * body.rgb * _GIStrength;

                // --- bubbles nổi lên ---
            #if defined(_BUBBLE)
                float2 buv = float2(IN.positionWS.x, IN.positionWS.y) * (_BubbleScale * 0.1)
                           - float2(0, _Time.y * _BubbleSpeed);
                half b = STW_Voronoi(buv, 0);
                half bubble = 1.0h - smoothstep(0.0h, 0.12h, b);
                color += _BubbleColor.rgb * bubble * _BubbleStrength;
            #endif

                // --- surface band (mặt thoáng sáng) ---
                half band = 1.0h - saturate(abs(fillY - IN.positionOS.y) / max(STW_EPSILON, _SurfaceBand));
                color += _SurfaceColor.rgb * band * _SurfaceStrength;

                // --- rim ---
                half rim = STW_Fresnel(normalWS, viewDirWS, _RimPower);
                color += rim * _RimStrength * _RimColor.rgb;

                half alpha = saturate(lerp(_ShallowColor.a, _DeepColor.a, depthGrad) + band) * _Alpha;

                color = STW_ApplyFog(color, IN.fogCoord);
                return half4(color, alpha);
            }
            ENDHLSL
        }
    }

    FallBack Off
    CustomEditor "StylizedToonWorldKit.Editor.LiquidGUI"
}
