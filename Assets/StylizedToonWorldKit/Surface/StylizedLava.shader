// =============================================================================
//  StylizedLava.shader  —  Stylized Toon World Kit / P4 Surface
// -----------------------------------------------------------------------------
//  DUNG NHAM / MAGMA (opaque, đổ bóng):
//    • Flow molten: FBM méo theo flow-map 2-phase (Valve flow) → dòng chảy nóng.
//    • Crust gradient: lớp đá nguội phủ trên, khe nứt để lộ lava phát sáng.
//    • Emission ramp nhiệt: đỏ thẫm → cam → vàng trắng theo heat field, có pulse.
//    • Crust nhận toon lighting (trỏ P0); lava là emissive (không phụ thuộc đèn).
//  Opaque (ForwardLit + ShadowCaster + DepthNormals).
//  URP 17 / Unity 6 · SRP Batcher · GPU Instancing · VR SPI.
// =============================================================================
Shader "StylizedToonWorldKit/Surface/Lava"
{
    Properties
    {
        [Header(Crust (cooled rock))][Space(4)]
        _CrustColor    ("Crust Color A", Color) = (0.08,0.06,0.06,1)
        _CrustColor2   ("Crust Color B", Color) = (0.18,0.12,0.1,1)
        _ShadowTint    ("Shadow Tint", Color) = (0.03,0.02,0.02,1)
        _RampSteps     ("Cel Steps", Range(1,6)) = 2
        _RampSmooth    ("Ramp Softness", Range(0,1)) = 0.15
        _GIStrength    ("GI Strength", Range(0,2)) = 0.4

        [Header(Lava (molten cracks))][Space(4)]
        [HDR] _LavaLow  ("Lava Color Low", Color) = (1.5,0.25,0.05,1)
        [HDR] _LavaHigh ("Lava Color High", Color) = (3,1.6,0.4,1)
        _CrustCoverage ("Crust Coverage", Range(0,1)) = 0.55
        _CrustSharpness ("Crust Sharpness", Range(0.01,0.5)) = 0.12
        _EmissionStrength ("Emission Strength", Range(0,8)) = 2.5
        _PulseSpeed    ("Glow Pulse Speed", Range(0,6)) = 1.5

        [Header(Flow)][Space(4)]
        _NoiseScale    ("Noise Scale", Range(0.2,12)) = 2
        _FlowDir       ("Flow Direction (xy)", Vector) = (0,1,0,0)
        _FlowSpeed     ("Flow Speed", Range(0,2)) = 0.25

        [HideInInspector] _Cull ("Cull", Float) = 2
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest  ("ZTest", Float) = 4
        [Enum(Off,0,On,1)]                            _ZWrite ("ZWrite", Float) = 1
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" "Queue"="Geometry" }
        LOD 300

        HLSLINCLUDE
        #include "../Core/URPCompat.hlsl"
        CBUFFER_START(UnityPerMaterial)
            half4  _CrustColor;
            half4  _CrustColor2;
            half4  _ShadowTint;
            half   _RampSteps;
            half   _RampSmooth;
            half   _GIStrength;
            half4  _LavaLow;
            half4  _LavaHigh;
            half   _CrustCoverage;
            half   _CrustSharpness;
            half   _EmissionStrength;
            half   _PulseSpeed;
            half   _NoiseScale;
            float4 _FlowDir;
            half   _FlowSpeed;
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

            #include "../Core/StylizedLighting.hlsl"
            #include "../Core/StylizedNoise.hlsl"

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
                DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 5);
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
                OUT.uv          = IN.uv;
                OUT.shadowCoord = STW_GetShadowCoord(pos.positionWS, pos.positionCS);
                OUT.fogCoord    = ComputeFogFactor(pos.positionCS.z);
                OUTPUT_LIGHTMAP_UV(IN.lightmapUV, unity_LightmapST, OUT.lightmapUV);
                OUTPUT_SH(OUT.normalWS, OUT.vertexSH);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                STW_SETUP_INSTANCE_FRAG(IN);

                // --- heat field: FBM méo theo flow 2-phase ---
                float2 uv = IN.uv * _NoiseScale;
                float2 dir = normalize(_FlowDir.xy + half2(0.001,0));
                float2 uv0, uv1; float w;
                STW_Flow(uv, dir, _Time.y, _FlowSpeed, uv0, uv1, w);
                half heat = lerp(STW_FBM(uv0, 4, 2.0, 0.5), STW_FBM(uv1, 4, 2.0, 0.5), w);
                heat = saturate(heat * 0.5h + 0.5h);

                // crust mask: 1 = đá nguội, 0 = khe lava
                half crustMask = smoothstep(_CrustCoverage - _CrustSharpness,
                                            _CrustCoverage + _CrustSharpness, heat);
                half cracks = 1.0h - crustMask;

                // --- crust shaded (toon) ---
                half3 normalWS  = STW_SafeNormalize(IN.normalWS);
                half3 crustAlb  = lerp(_CrustColor.rgb, _CrustColor2.rgb, heat);

                STWToonSurface s;
                s.albedo     = crustAlb;
                s.normalWS   = normalWS;
                s.viewDirWS  = STW_SafeNormalize(GetWorldSpaceViewDir(IN.positionWS));
                s.positionWS = IN.positionWS;
                s.screenUV   = GetNormalizedScreenSpaceUV(IN.positionCS);
                s.smoothness = 0.1h;
                s.occlusion  = 1.0h;
                s.emission   = half3(0,0,0);

                STWToonParams p;
                p.shadowTint       = _ShadowTint.rgb;
                p.rampSteps        = _RampSteps;
                p.rampSmoothness   = _RampSmooth;
                p.shadowThreshold  = 0.5h;
                p.specularStrength = 0.0h;
                p.specularSize     = 0.2h;
                p.rimColor         = half3(0,0,0);
                p.rimPower         = 1.0h;
                p.rimStrength      = 0.0h;
                p.giStrength       = _GIStrength;

                half4 shadowMask = half4(1,1,1,1);
                half3 color = STW_ToonLighting(s, p, IN.shadowCoord, shadowMask);

                // --- lava emission ở khe nứt ---
                half pulse = 0.8h + 0.2h * sin(_Time.y * _PulseSpeed + heat * 6.2831853h);
                half lavaHeat = saturate((heat - _CrustCoverage) / max(STW_EPSILON, _CrustCoverage));
                half3 lava = lerp(_LavaLow.rgb, _LavaHigh.rgb, lavaHeat);
                color += lava * cracks * _EmissionStrength * pulse;

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
            struct VaryingsDN   { float4 positionCS:SV_POSITION; float3 normalWS:TEXCOORD0; STW_VERTEX_OUTPUT_STEREO };

            VaryingsDN dnVert(AttributesDN IN)
            {
                VaryingsDN OUT = (VaryingsDN)0;
                STW_SETUP_INSTANCE_VERT(IN, OUT);
                VertexPositionInputs pos = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs   nrm = GetVertexNormalInputs(IN.normalOS);
                OUT.positionCS = pos.positionCS;
                OUT.normalWS   = nrm.normalWS;
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

    FallBack "Universal Render Pipeline/Lit"
    CustomEditor "StylizedToonWorldKit.Editor.LavaGUI"
}
