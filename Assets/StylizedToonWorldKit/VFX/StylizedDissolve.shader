// =============================================================================
//  StylizedDissolve.shader  —  Stylized Toon World Kit / P3 VFX
// -----------------------------------------------------------------------------
//  Hiệu ứng TAN BIẾN (spawn / death / teleport-out). Áp lên mesh OPAQUE:
//    • Cutout theo noise (procedural fBm hoặc noise texture) — clip dần theo _Dissolve.
//    • Viền phát sáng (edge glow HDR) ở mép đang tan → cảm giác cháy/năng-lượng.
//    • Vẫn cel-shading (dùng STW_ToonLighting P0) → khớp world toon.
//    • UV hoặc WORLD-space noise (keyword) — world tránh seam khi scale mesh.
//    • Clip lan sang ShadowCaster + DepthNormals → bóng & SS-outline tan đồng bộ.
//  Target: URP 17 / Unity 6 (Forward & Forward+). SRP Batcher · Instancing · VR SPI.
// =============================================================================
Shader "StylizedToonWorldKit/VFX/Dissolve"
{
    Properties
    {
        [MainTexture] _BaseMap   ("Base Map", 2D) = "white" {}
        [MainColor]   _BaseColor ("Base Color", Color) = (1,1,1,1)

        [Header(Cel Shading)][Space(4)]
        _ShadowTint   ("Shadow Tint", Color) = (0.45,0.5,0.6,1)
        _RampSteps    ("Cel Steps", Range(1,6)) = 3
        _RampSmooth   ("Ramp Softness", Range(0,1)) = 0.05
        _GIStrength   ("GI Strength", Range(0,2)) = 1.0

        [Header(Dissolve)][Space(4)]
        _Dissolve     ("Dissolve Amount", Range(0,1)) = 0.0
        _NoiseMap     ("Noise Map (optional)", 2D) = "white" {}
        _NoiseScale   ("Procedural Noise Scale", Range(0.5,40)) = 8
        _NoiseOctaves ("Procedural Octaves", Range(1,5)) = 3
        [Toggle(_NOISEMAP)] _UseNoiseMap ("Use Noise Texture", Float) = 0
        [Toggle(_DISSOLVE_WORLD)] _DissolveWorld ("World-space Noise", Float) = 0

        [Header(Edge Glow)][Space(4)]
        _EdgeWidth    ("Edge Width", Range(0.001,0.5)) = 0.08
        [HDR] _EdgeColor ("Edge Color", Color) = (4,1.4,0.2,1)
        _EdgeStrength ("Edge Strength", Range(0,8)) = 3
        [HDR] _Emission ("Base Emission", Color) = (0,0,0,0)

        // Render state (ShaderGUI Advanced)
        [HideInInspector] _Cull ("Cull", Float) = 2
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="TransparentCutout" "Queue"="AlphaTest" }
        LOD 300

        // -------- helper include block dùng lại trong 3 pass --------
        HLSLINCLUDE
        #include "URPCompat.hlsl"
        #include "StylizedNoise.hlsl"

        CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            float4 _NoiseMap_ST;
            half4  _BaseColor;
            half4  _ShadowTint;
            half   _RampSteps;
            half   _RampSmooth;
            half   _GIStrength;
            half   _Dissolve;
            half   _NoiseScale;
            half   _NoiseOctaves;
            half   _EdgeWidth;
            half4  _EdgeColor;
            half   _EdgeStrength;
            half4  _Emission;
            half   _Cull;
        CBUFFER_END

        // Mask tan biến (0..1). uvOrWorld: UV nếu local, positionWS.xy nếu world.
        float STW_DissolveNoise(float2 coord, TEXTURE2D_PARAM(noiseTex, noiseSamp))
        {
        #if defined(_NOISEMAP)
            return SAMPLE_TEXTURE2D_LOD(noiseTex, noiseSamp, coord, 0).r;
        #else
            int oct = (int)clamp(_NoiseOctaves, 1, 5);
            return saturate(STW_FBM(coord * _NoiseScale, oct, 2.0, 0.5));
        #endif
        }
        ENDHLSL

        // ---------------------------------------------------------------------
        //  PASS 1 — ForwardLit (toon + dissolve clip + edge glow)
        // ---------------------------------------------------------------------
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }
            Cull [_Cull]

            HLSLPROGRAM
            #pragma vertex   vert
            #pragma fragment frag
            #pragma target 3.0

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile _ _FORWARD_PLUS
            #pragma multi_compile _ LIGHTMAP_ON DYNAMICLIGHTMAP_ON
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fog
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #pragma shader_feature_local _NOISEMAP
            #pragma shader_feature_local _DISSOLVE_WORLD

            #include "StylizedLighting.hlsl"

            TEXTURE2D(_BaseMap);  SAMPLER(sampler_BaseMap);
            TEXTURE2D(_NoiseMap); SAMPLER(sampler_NoiseMap);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
                float2 lightmapUV : TEXCOORD1;
                STW_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS   : TEXCOORD2;
                float4 shadowCoord: TEXCOORD3;
                half   fogCoord   : TEXCOORD4;
                DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 5)
                STW_VERTEX_OUTPUT_STEREO
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT = (Varyings)0;
                STW_SETUP_INSTANCE_VERT(IN, OUT);
                VertexPositionInputs pos = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs   nrm = GetVertexNormalInputs(IN.normalOS);
                OUT.positionCS  = pos.positionCS;
                OUT.positionWS  = pos.positionWS;
                OUT.normalWS    = nrm.normalWS;
                OUT.uv          = TRANSFORM_TEX(IN.uv, _BaseMap);
                OUT.shadowCoord = STW_GetShadowCoord(pos.positionWS, pos.positionCS);
                OUT.fogCoord    = ComputeFogFactor(pos.positionCS.z);
                OUTPUT_LIGHTMAP_UV(IN.lightmapUV, unity_LightmapST, OUT.lightmapUV);
                OUTPUT_SH(OUT.normalWS, OUT.vertexSH);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                STW_SETUP_INSTANCE_FRAG(IN);

            #if defined(_DISSOLVE_WORLD)
                float2 nco = IN.positionWS.xy + IN.positionWS.zz * 0.5;
            #else
                float2 nco = TRANSFORM_TEX(IN.uv, _NoiseMap);
            #endif
                float noise = STW_DissolveNoise(nco, TEXTURE2D_ARGS(_NoiseMap, sampler_NoiseMap));

                // clip: vùng noise < ngưỡng bị tan. _Dissolve=1 -> tan hết.
                float cut = noise - _Dissolve;
                clip(cut - 1e-4);

                half4 baseTex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);

                STWToonSurface s;
                s.albedo     = baseTex.rgb * _BaseColor.rgb;
                s.normalWS   = STW_SafeNormalize(IN.normalWS);
                s.viewDirWS  = STW_SafeNormalize(GetWorldSpaceViewDir(IN.positionWS));
                s.positionWS = IN.positionWS;
                s.screenUV   = GetNormalizedScreenSpaceUV(IN.positionCS);
                s.smoothness = 0.2h;
                s.occlusion  = 1.0h;
                s.emission   = _Emission.rgb;

                STWToonParams p;
                p.shadowTint       = _ShadowTint.rgb;
                p.rampSteps        = _RampSteps;
                p.rampSmoothness   = _RampSmooth;
                p.shadowThreshold  = 0.5h;
                p.specularStrength = 0.0h;
                p.specularSize     = 0.2h;
                p.rimColor         = half3(0,0,0);
                p.rimPower         = 3.0h;
                p.rimStrength      = 0.0h;
                p.giStrength       = _GIStrength;

                half4 shadowMask = half4(1,1,1,1);
                half3 color = STW_ToonLighting(s, p, IN.shadowCoord, shadowMask);

                // edge glow: dải mỏng ngay trên ngưỡng clip.
                half edge = 1.0h - saturate(cut / max(STW_EPSILON, _EdgeWidth));
                color += _EdgeColor.rgb * _EdgeColor.a * edge * _EdgeStrength;

                color = STW_ApplyFog(color, IN.fogCoord);
                return half4(color, 1.0h);
            }
            ENDHLSL
        }

        // ---------------------------------------------------------------------
        //  PASS 2 — ShadowCaster (clip theo dissolve để bóng tan đồng bộ)
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
            #pragma shader_feature_local _NOISEMAP
            #pragma shader_feature_local _DISSOLVE_WORLD

            TEXTURE2D(_NoiseMap); SAMPLER(sampler_NoiseMap);

            float3 _LightDirection;
            float3 _LightPosition;

            struct AttributesS { float4 positionOS:POSITION; float3 normalOS:NORMAL; float2 uv:TEXCOORD0; STW_VERTEX_INPUT_INSTANCE_ID };
            struct VaryingsS   { float4 positionCS:SV_POSITION; float2 uv:TEXCOORD0; float3 positionWS:TEXCOORD1; STW_VERTEX_OUTPUT_STEREO };

            float4 GetShadowPositionCS(float3 positionWS, float3 normalWS)
            {
            #if _CASTING_PUNCTUAL_LIGHT_SHADOW
                float3 dir = normalize(_LightPosition - positionWS);
            #else
                float3 dir = _LightDirection;
            #endif
                float4 cs = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, dir));
            #if UNITY_REVERSED_Z
                cs.z = min(cs.z, UNITY_NEAR_CLIP_VALUE);
            #else
                cs.z = max(cs.z, UNITY_NEAR_CLIP_VALUE);
            #endif
                return cs;
            }

            VaryingsS shadowVert(AttributesS IN)
            {
                VaryingsS OUT = (VaryingsS)0;
                STW_SETUP_INSTANCE_VERT(IN, OUT);
                VertexPositionInputs pos = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs   nrm = GetVertexNormalInputs(IN.normalOS);
                OUT.positionCS = GetShadowPositionCS(pos.positionWS, nrm.normalWS);
                OUT.positionWS = pos.positionWS;
                OUT.uv         = TRANSFORM_TEX(IN.uv, _NoiseMap);
                return OUT;
            }

            half4 shadowFrag(VaryingsS IN) : SV_Target
            {
            #if defined(_DISSOLVE_WORLD)
                float2 nco = IN.positionWS.xy + IN.positionWS.zz * 0.5;
            #else
                float2 nco = IN.uv;
            #endif
                float noise = STW_DissolveNoise(nco, TEXTURE2D_ARGS(_NoiseMap, sampler_NoiseMap));
                clip(noise - _Dissolve - 1e-4);
                return 0;
            }
            ENDHLSL
        }

        // ---------------------------------------------------------------------
        //  PASS 3 — DepthNormals (clip để SS outline/SSAO tan đồng bộ)
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
            #pragma shader_feature_local _NOISEMAP
            #pragma shader_feature_local _DISSOLVE_WORLD

            TEXTURE2D(_NoiseMap); SAMPLER(sampler_NoiseMap);

            struct AttributesDN { float4 positionOS:POSITION; float3 normalOS:NORMAL; float2 uv:TEXCOORD0; STW_VERTEX_INPUT_INSTANCE_ID };
            struct VaryingsDN   { float4 positionCS:SV_POSITION; float3 normalWS:TEXCOORD0; float2 uv:TEXCOORD1; float3 positionWS:TEXCOORD2; STW_VERTEX_OUTPUT_STEREO };

            VaryingsDN dnVert(AttributesDN IN)
            {
                VaryingsDN OUT = (VaryingsDN)0;
                STW_SETUP_INSTANCE_VERT(IN, OUT);
                VertexPositionInputs pos = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs   nrm = GetVertexNormalInputs(IN.normalOS);
                OUT.positionCS = pos.positionCS;
                OUT.normalWS   = nrm.normalWS;
                OUT.positionWS = pos.positionWS;
                OUT.uv         = TRANSFORM_TEX(IN.uv, _NoiseMap);
                return OUT;
            }

            half4 dnFrag(VaryingsDN IN) : SV_Target
            {
                STW_SETUP_INSTANCE_FRAG(IN);
            #if defined(_DISSOLVE_WORLD)
                float2 nco = IN.positionWS.xy + IN.positionWS.zz * 0.5;
            #else
                float2 nco = IN.uv;
            #endif
                float noise = STW_DissolveNoise(nco, TEXTURE2D_ARGS(_NoiseMap, sampler_NoiseMap));
                clip(noise - _Dissolve - 1e-4);
                float3 n = NormalizeNormalPerPixel(IN.normalWS);
                return half4(n * 0.5 + 0.5, 0);
            }
            ENDHLSL
        }
    }

    FallBack "Universal Render Pipeline/Lit"
    CustomEditor "StylizedToonWorldKit.Editor.DissolveGUI"
}
