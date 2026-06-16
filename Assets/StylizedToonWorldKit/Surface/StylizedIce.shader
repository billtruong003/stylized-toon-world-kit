// =============================================================================
//  StylizedIce.shader  —  Stylized Toon World Kit / P4 Surface
// -----------------------------------------------------------------------------
//  BĂNG / TUYẾT stylized (opaque, nhận bóng + đổ bóng):
//    • Toon lit nền (trỏ P0 STW_ToonLighting) — ramp bậc + colored shadow.
//    • Sparkle: glint lấp lánh theo voronoi + per-cell twinkle, view-dependent.
//    • Depth tint giả subsurface: lõi xanh theo nghịch-fresnel (băng dày = xanh).
//    • Frost edge: viền trắng phủ tuyết theo fresnel (mép sần).
//  Opaque (ForwardLit + ShadowCaster + DepthNormals cho SS-outline/SSAO).
//  URP 17 / Unity 6 · SRP Batcher · GPU Instancing · VR SPI.
// =============================================================================
Shader "StylizedToonWorldKit/Surface/Ice"
{
    Properties
    {
        [MainTexture] _BaseMap   ("Base Map", 2D) = "white" {}
        [MainColor]   _BaseColor ("Base Color", Color) = (0.78,0.9,0.97,1)

        [Header(Toon Lighting)][Space(4)]
        _ShadowTint   ("Shadow Tint", Color) = (0.4,0.55,0.7,1)
        _RampSteps    ("Cel Steps", Range(1,6)) = 3
        _RampSmooth   ("Ramp Softness", Range(0,1)) = 0.08
        _GIStrength   ("GI Strength", Range(0,2)) = 1.0

        [Header(Depth Tint (fake subsurface))][Space(4)]
        [HDR] _DepthColor ("Depth Color", Color) = (0.15,0.45,0.7,1)
        _DepthStrength ("Depth Strength", Range(0,2)) = 0.8
        _DepthPower    ("Depth Power", Range(0.2,6)) = 2

        [Header(Sparkle)][Space(4)]
        [Toggle(_SPARKLE)] _SparkleToggle ("Enable Sparkle", Float) = 1
        [HDR] _SparkleColor ("Sparkle Color", Color) = (1,1,1,1)
        _SparkleScale   ("Sparkle Density (scale)", Range(1,120)) = 40
        _SparkleAmount  ("Sparkle Amount", Range(0,1)) = 0.5
        _SparkleSpeed   ("Twinkle Speed", Range(0,6)) = 2
        _SparkleStrength ("Sparkle Strength", Range(0,4)) = 1.5

        [Header(Frost Edge)][Space(4)]
        _FrostColor   ("Frost Color", Color) = (1,1,1,1)
        _FrostPower   ("Frost Power", Range(0.2,8)) = 3
        _FrostStrength ("Frost Strength", Range(0,2)) = 0.6

        [Header(Specular)][Space(4)]
        _SpecStrength ("Specular Strength", Range(0,4)) = 1.2
        _SpecSize     ("Specular Size", Range(0,1)) = 0.12

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
            float4 _BaseMap_ST;
            half4  _BaseColor;
            half4  _ShadowTint;
            half   _RampSteps;
            half   _RampSmooth;
            half   _GIStrength;
            half4  _DepthColor;
            half   _DepthStrength;
            half   _DepthPower;
            half4  _SparkleColor;
            half   _SparkleScale;
            half   _SparkleAmount;
            half   _SparkleSpeed;
            half   _SparkleStrength;
            half4  _FrostColor;
            half   _FrostPower;
            half   _FrostStrength;
            half   _SpecStrength;
            half   _SpecSize;
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

            #pragma shader_feature_local _SPARKLE

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

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);

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

                half4 baseTex   = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);
                half3 normalWS  = STW_SafeNormalize(IN.normalWS);
                half3 viewDirWS = STW_SafeNormalize(GetWorldSpaceViewDir(IN.positionWS));

                STWToonSurface s;
                s.albedo     = baseTex.rgb * _BaseColor.rgb;
                s.normalWS   = normalWS;
                s.viewDirWS  = viewDirWS;
                s.positionWS = IN.positionWS;
                s.screenUV   = GetNormalizedScreenSpaceUV(IN.positionCS);
                s.smoothness = _SpecSize;
                s.occlusion  = 1.0h;
                s.emission   = half3(0,0,0);

                STWToonParams p;
                p.shadowTint       = _ShadowTint.rgb;
                p.rampSteps        = _RampSteps;
                p.rampSmoothness   = _RampSmooth;
                p.shadowThreshold  = 0.5h;
                p.specularStrength = _SpecStrength;
                p.specularSize     = _SpecSize;
                p.rimColor         = half3(0,0,0);
                p.rimPower         = 1.0h;
                p.rimStrength      = 0.0h;
                p.giStrength       = _GIStrength;

                half4 shadowMask = half4(1,1,1,1);
                half3 color = STW_ToonLighting(s, p, IN.shadowCoord, shadowMask);

                // --- depth tint (băng dày = xanh) theo nghịch fresnel ---
                half facing = saturate(dot(normalWS, viewDirWS));
                half depth  = pow(facing, _DepthPower);
                color = lerp(color, color * _DepthColor.rgb, depth * _DepthStrength);

                // --- sparkle: glint voronoi + per-cell twinkle ---
            #if defined(_SPARKLE)
                float2 suv = IN.uv * _SparkleScale;
                half cell  = STW_Voronoi(suv, _Time.y * _SparkleSpeed);
                half glint = 1.0h - smoothstep(0.0h, 0.06h, cell);
                half twink = step(1.0h - _SparkleAmount, STW_Hash21(floor(suv)));
                half sparkle = glint * twink * (0.4h + 0.6h * facing);
                color += _SparkleColor.rgb * sparkle * _SparkleStrength;
            #endif

                // --- frost edge (viền phủ tuyết) ---
                half frost = STW_Fresnel(normalWS, viewDirWS, _FrostPower);
                color = lerp(color, _FrostColor.rgb, saturate(frost * _FrostStrength));

                color = STW_ApplyFog(color, IN.fogCoord);
                return half4(color, baseTex.a * _BaseColor.a);
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
    CustomEditor "StylizedToonWorldKit.Editor.IceGUI"
}
