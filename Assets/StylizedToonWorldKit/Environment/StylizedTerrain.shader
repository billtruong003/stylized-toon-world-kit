// =============================================================================
//  StylizedTerrain.shader  —  Stylized Toon World Kit / P2 Environment
// -----------------------------------------------------------------------------
//  ĐỊA HÌNH (mesh terrain stylized — không phải Unity Terrain splatmap):
//    • 3 lớp blend tự động: NỀN (cỏ/đất) → VÁCH DỐC (đá, triplanar) → ĐỈNH (tuyết/cát).
//    • Lớp dốc chọn theo slope mask (normal.y), lớp đỉnh theo height gradient (world Y).
//    • Triplanar cho lớp đá (đỡ stretch trên vách đứng).
//    • Toon ramp colored shadow + GI + macro variation noise (đỡ lặp texture).
//  Opaque lit. ShadowCaster + DepthNormals. URP 17 / U6 · SRP Batcher · VR SPI.
// =============================================================================
Shader "StylizedToonWorldKit/Environment/Terrain"
{
    Properties
    {
        [Header(Ground Layer)][Space(4)]
        _GroundMap ("Ground Albedo", 2D) = "white" {}
        _GroundColor ("Ground Tint", Color) = (0.35,0.5,0.25,1)
        _GroundScale ("Ground Scale", Range(0.01,2)) = 0.2

        [Header(Cliff Layer Triplanar)][Space(4)]
        _CliffMap ("Cliff Albedo", 2D) = "gray" {}
        _CliffColor ("Cliff Tint", Color) = (0.45,0.42,0.4,1)
        _CliffScale ("Cliff Scale", Range(0.01,2)) = 0.15
        _SlopeThreshold ("Slope Threshold", Range(0,1)) = 0.6
        _SlopeSharp ("Slope Blend Sharpness", Range(0.01,1)) = 0.15
        _TriplanarSharp ("Triplanar Sharpness", Range(1,16)) = 4

        [Header(Peak Layer Snow or Sand)][Space(4)]
        [Toggle(_PEAK_LAYER)] _PeakToggle ("Enable Peak Layer", Float) = 1
        _PeakMap ("Peak Albedo", 2D) = "white" {}
        _PeakColor ("Peak Tint", Color) = (0.95,0.97,1,1)
        _PeakScale ("Peak Scale", Range(0.01,2)) = 0.2
        _PeakMinHeight ("Peak Min Height", Float) = 8
        _PeakMaxHeight ("Peak Max Height", Float) = 14
        _PeakSharp ("Peak Gradient Sharpness", Range(0.2,4)) = 1
        _PeakSlopeBias ("Peak Avoids Slope", Range(0,1)) = 0.5

        [Header(Macro Variation)][Space(4)]
        _MacroStrength ("Macro Variation", Range(0,1)) = 0.2
        _MacroScale ("Macro Scale", Range(0.005,0.5)) = 0.03

        [Header(Lighting)][Space(4)]
        _ShadowTint ("Shadow Tint", Color) = (0.3,0.32,0.4,1)
        _RampSteps  ("Cel Steps", Range(1,6)) = 3
        _RampSmooth ("Ramp Softness", Range(0,1)) = 0.08
        _GIStrength ("GI Strength", Range(0,2)) = 1
        _Occlusion  ("Occlusion", Range(0,1)) = 1

        [HideInInspector] _Cull ("Cull", Float) = 2
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest  ("ZTest", Float) = 4
        [Enum(Off,0,On,1)]                            _ZWrite ("ZWrite", Float) = 1
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" "Queue"="Geometry" }
        LOD 300

        HLSLINCLUDE
        #include "../Core/StylizedLighting.hlsl"
        #include "../Core/StylizedSurface.hlsl"
        #include "../Core/StylizedNoise.hlsl"

        CBUFFER_START(UnityPerMaterial)
            float4 _GroundMap_ST;
            half4  _GroundColor;
            half   _GroundScale;
            float4 _CliffMap_ST;
            half4  _CliffColor;
            half   _CliffScale;
            half   _SlopeThreshold;
            half   _SlopeSharp;
            half   _TriplanarSharp;
            float4 _PeakMap_ST;
            half4  _PeakColor;
            half   _PeakScale;
            float  _PeakMinHeight;
            float  _PeakMaxHeight;
            half   _PeakSharp;
            half   _PeakSlopeBias;
            half   _MacroStrength;
            half   _MacroScale;
            half4  _ShadowTint;
            half   _RampSteps;
            half   _RampSmooth;
            half   _GIStrength;
            half   _Occlusion;
            half   _Cull; half _ZTest; half _ZWrite;
        CBUFFER_END
        ENDHLSL

        // ---------------------------------------------------------------------
        //  PASS 1 — ForwardLit
        // ---------------------------------------------------------------------
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }
            Cull   [_Cull]
            ZTest  [_ZTest]
            ZWrite [_ZWrite]
            HLSLPROGRAM
            #pragma vertex   vert
            #pragma fragment frag
            #pragma target 3.0

            #pragma shader_feature_local _PEAK_LAYER

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile _ _CLUSTER_LIGHT_LOOP
            #pragma multi_compile _ LIGHTMAP_ON DYNAMICLIGHTMAP_ON
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fog
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer

            TEXTURE2D(_GroundMap); SAMPLER(sampler_GroundMap);
            TEXTURE2D(_CliffMap);  SAMPLER(sampler_CliffMap);
            TEXTURE2D(_PeakMap);   SAMPLER(sampler_PeakMap);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 lightmapUV : TEXCOORD1;
                STW_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                half3  normalWS   : TEXCOORD1;
                float4 shadowCoord: TEXCOORD2;
                half   fogCoord   : TEXCOORD3;
                DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 4);
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
                OUT.shadowCoord= STW_GetShadowCoord(pos.positionWS, pos.positionCS);
                OUT.fogCoord   = ComputeFogFactor(pos.positionCS.z);
                OUTPUT_LIGHTMAP_UV(IN.lightmapUV, unity_LightmapST, OUT.lightmapUV);
                OUTPUT_SH(OUT.normalWS, OUT.vertexSH);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                STW_SETUP_INSTANCE_FRAG(IN);

                half3 normalWS = STW_SafeNormalize(IN.normalWS);
                float3 p = IN.positionWS;

                // --- lớp nền (planar XZ) ---
                half3 ground = SAMPLE_TEXTURE2D(_GroundMap, sampler_GroundMap, p.xz * _GroundScale).rgb * _GroundColor.rgb;

                // --- lớp đá (triplanar) ---
                half3 cliff = STW_Triplanar(TEXTURE2D_ARGS(_CliffMap, sampler_CliffMap), p, normalWS, _CliffScale, _TriplanarSharp).rgb * _CliffColor.rgb;

                // slope mask: 1 ở mặt phẳng, 0 ở vách dốc → đảo cho lớp đá
                half flat_ = STW_SlopeMask(normalWS, _SlopeThreshold, _SlopeSharp);
                half cliffMask = 1.0h - flat_;

                half3 albedo = lerp(ground, cliff, cliffMask);

                // --- lớp đỉnh (tuyết/cát) theo height + tránh dốc ---
            #if defined(_PEAK_LAYER)
                half hg = STW_HeightGradient(p.y, _PeakMinHeight, _PeakMaxHeight, _PeakSharp);
                half peakMask = hg * lerp(1.0h, flat_, _PeakSlopeBias);
                half3 peak = SAMPLE_TEXTURE2D(_PeakMap, sampler_PeakMap, p.xz * _PeakScale).rgb * _PeakColor.rgb;
                albedo = lerp(albedo, peak, saturate(peakMask));
            #endif

                // macro variation: noise tần thấp phá lặp texture
                half macro = STW_GradientNoise(p.xz * _MacroScale);
                albedo *= lerp(1.0h, macro * 1.4h, _MacroStrength);

                half4 shadowMask = half4(1,1,1,1);
                STWToonSurface s;
                s.albedo     = albedo;
                s.normalWS   = normalWS;
                s.viewDirWS  = STW_SafeNormalize(GetWorldSpaceViewDir(IN.positionWS));
                s.positionWS = IN.positionWS;
                s.screenUV   = GetNormalizedScreenSpaceUV(IN.positionCS);
                s.smoothness = 0.1h;
                s.occlusion  = _Occlusion;
                s.emission   = half3(0,0,0);

                STWToonParams pr;
                pr.shadowTint       = _ShadowTint.rgb;
                pr.rampSteps        = _RampSteps;
                pr.rampSmoothness   = _RampSmooth;
                pr.shadowThreshold  = 0.5h;
                pr.specularStrength = 0.0h;
                pr.specularSize     = 0.2h;
                pr.rimColor         = half3(0,0,0);
                pr.rimPower         = 1.0h;
                pr.rimStrength      = 0.0h;
                pr.giStrength       = _GIStrength;

                half3 color = STW_ToonLighting(s, pr, IN.shadowCoord, shadowMask);
                color = STW_ApplyFog(color, IN.fogCoord);
                return half4(color, 1);
            }
            ENDHLSL
        }

        // ---------------------------------------------------------------------
        //  PASS 2 — ShadowCaster
        // ---------------------------------------------------------------------
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode"="ShadowCaster" }
            ZWrite On ZTest LEqual ColorMask 0 Cull [_Cull]

            HLSLPROGRAM
            #pragma vertex   shadowVert
            #pragma fragment shadowFrag
            #pragma multi_compile_instancing
            #pragma multi_compile _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            float3 _LightDirection;
            float3 _LightPosition;

            struct AttributesS { float4 positionOS:POSITION; float3 normalOS:NORMAL; STW_VERTEX_INPUT_INSTANCE_ID };
            struct VaryingsS   { float4 positionCS:SV_POSITION; STW_VERTEX_OUTPUT_STEREO };

            VaryingsS shadowVert(AttributesS IN)
            {
                VaryingsS OUT = (VaryingsS)0;
                STW_SETUP_INSTANCE_VERT(IN, OUT);
                VertexPositionInputs pos = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs   nrm = GetVertexNormalInputs(IN.normalOS);
            #if _CASTING_PUNCTUAL_LIGHT_SHADOW
                float3 dir = normalize(_LightPosition - pos.positionWS);
            #else
                float3 dir = _LightDirection;
            #endif
                float4 cs = TransformWorldToHClip(ApplyShadowBias(pos.positionWS, nrm.normalWS, dir));
            #if UNITY_REVERSED_Z
                cs.z = min(cs.z, UNITY_NEAR_CLIP_VALUE);
            #else
                cs.z = max(cs.z, UNITY_NEAR_CLIP_VALUE);
            #endif
                OUT.positionCS = cs;
                return OUT;
            }
            half4 shadowFrag(VaryingsS IN) : SV_Target { return 0; }
            ENDHLSL
        }

        // ---------------------------------------------------------------------
        //  PASS 3 — DepthNormals
        // ---------------------------------------------------------------------
        Pass
        {
            Name "DepthNormals"
            Tags { "LightMode"="DepthNormals" }
            ZWrite On Cull [_Cull]

            HLSLPROGRAM
            #pragma vertex   dnVert
            #pragma fragment dnFrag
            #pragma multi_compile_instancing

            struct AttributesDN { float4 positionOS:POSITION; float3 normalOS:NORMAL; STW_VERTEX_INPUT_INSTANCE_ID };
            struct VaryingsDN   { float4 positionCS:SV_POSITION; half3 normalWS:TEXCOORD0; STW_VERTEX_OUTPUT_STEREO };

            VaryingsDN dnVert(AttributesDN IN)
            {
                VaryingsDN OUT = (VaryingsDN)0;
                STW_SETUP_INSTANCE_VERT(IN, OUT);
                VertexPositionInputs pos = GetVertexPositionInputs(IN.positionOS.xyz);
                OUT.positionCS = pos.positionCS;
                OUT.normalWS   = TransformObjectToWorldNormal(IN.normalOS);
                return OUT;
            }

            half4 dnFrag(VaryingsDN IN) : SV_Target
            {
                STW_SETUP_INSTANCE_FRAG(IN);
                float3 n = NormalizeNormalPerPixel(IN.normalWS);
                return half4(n * 0.5 + 0.5, 0);
            }
            ENDHLSL
        }
    }

    FallBack Off
    CustomEditor "StylizedToonWorldKit.Editor.TerrainGUI"
}
