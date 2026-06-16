// =============================================================================
//  StylizedMetal.shader  —  Stylized Toon World Kit / P4 Surface
// -----------------------------------------------------------------------------
//  KIM LOẠI / VÀNG toon (opaque, đổ bóng):
//    • Toon lit nền (trỏ P0) + tint kim loại (vàng/đồng/bạc).
//    • Anisotropic highlight bậc kéo theo tangent (ánh kim quét) — keyword _ANISO.
//    • Stylized env: phản chiếu môi trường từ SH theo reflect-vector rồi toon-band
//      (không phụ thuộc GlossyEnvironmentReflection → ổn định mọi version URP).
//    • Fresnel viền HDR cho mép kim loại sáng.
//  Opaque (ForwardLit + ShadowCaster + DepthNormals).
//  URP 17 / Unity 6 · SRP Batcher · GPU Instancing · VR SPI.
// =============================================================================
Shader "StylizedToonWorldKit/Surface/Metal"
{
    Properties
    {
        [MainTexture] _BaseMap   ("Base Map", 2D) = "white" {}
        [MainColor]   _BaseColor ("Metal Tint", Color) = (1,0.78,0.32,1)

        [Header(Toon Lighting)][Space(4)]
        _ShadowTint   ("Shadow Tint", Color) = (0.35,0.25,0.1,1)
        _RampSteps    ("Cel Steps", Range(1,6)) = 3
        _RampSmooth   ("Ramp Softness", Range(0,1)) = 0.06
        _GIStrength   ("GI Strength", Range(0,2)) = 1.0

        [Header(Stylized Environment)][Space(4)]
        _Metallic     ("Metallic (env mix)", Range(0,1)) = 0.8
        [HDR] _EnvColor ("Env Tint", Color) = (1,1,1,1)
        _EnvStrength  ("Env Strength", Range(0,3)) = 1
        _EnvSteps     ("Env Cel Steps", Range(1,6)) = 3
        _EnvSmooth    ("Env Softness", Range(0,1)) = 0.1

        [Header(Anisotropic Highlight)][Space(4)]
        [Toggle(_ANISO)] _AnisoToggle ("Enable Aniso", Float) = 1
        [HDR] _AnisoColor ("Aniso Color", Color) = (1,1,1,1)
        _AnisoShift   ("Aniso Shift", Range(-1,1)) = 0
        _AnisoExponent ("Aniso Sharpness", Range(1,256)) = 64
        _AnisoStrength ("Aniso Strength", Range(0,4)) = 1.2

        [Header(Rim)][Space(4)]
        [HDR] _RimColor ("Rim Color", Color) = (1,0.9,0.5,1)
        _RimPower     ("Rim Power", Range(0.2,8)) = 4
        _RimStrength  ("Rim Strength", Range(0,3)) = 0.6

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
            half   _Metallic;
            half4  _EnvColor;
            half   _EnvStrength;
            half   _EnvSteps;
            half   _EnvSmooth;
            half4  _AnisoColor;
            half   _AnisoShift;
            half   _AnisoExponent;
            half   _AnisoStrength;
            half4  _RimColor;
            half   _RimPower;
            half   _RimStrength;
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

            #pragma shader_feature_local _ANISO

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

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float4 tangentOS  : TANGENT;
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
                half4  tangentWS  : TEXCOORD3;
                float4 shadowCoord: TEXCOORD4;
                half   fogCoord   : TEXCOORD5;
                DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 6);
                STW_VERTEX_OUTPUT_STEREO
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT = (Varyings)0;
                STW_SETUP_INSTANCE_VERT(IN, OUT);

                VertexPositionInputs pos = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs   nrm = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);

                OUT.positionCS  = pos.positionCS;
                OUT.positionWS  = pos.positionWS;
                OUT.normalWS    = nrm.normalWS;
                OUT.tangentWS   = half4(nrm.tangentWS, IN.tangentOS.w * GetOddNegativeScale());
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
                s.smoothness = 0.2h;
                s.occlusion  = 1.0h;
                s.emission   = half3(0,0,0);

                STWToonParams p;
                p.shadowTint       = _ShadowTint.rgb;
                p.rampSteps        = _RampSteps;
                p.rampSmoothness   = _RampSmooth;
                p.shadowThreshold  = 0.5h;
                p.specularStrength = 0.0h;
                p.specularSize     = 0.2h;
                p.rimColor         = _RimColor.rgb;
                p.rimPower         = _RimPower;
                p.rimStrength      = _RimStrength;
                p.giStrength       = _GIStrength;

                half4 shadowMask = half4(1,1,1,1);
                half3 color = STW_ToonLighting(s, p, IN.shadowCoord, shadowMask);

                // --- stylized env reflection (SH theo reflect vector, toon-band) ---
                half3 reflectVec = reflect(-viewDirWS, normalWS);
                half3 envRaw = SampleSH(reflectVec);
                half  envLum = dot(envRaw, half3(0.299h, 0.587h, 0.114h));
                half  envBand = STW_RampStep(saturate(envLum), _EnvSteps, _EnvSmooth);
                half3 env = envRaw * envBand * _EnvColor.rgb * _EnvStrength;
                color += env * _Metallic * s.albedo;

                // --- anisotropic highlight (ánh kim quét) ---
            #if defined(_ANISO)
                Light ml = STW_GetMainLight(IN.shadowCoord, IN.positionWS, shadowMask);
                half aniso = STW_AnisoSpecular(IN.tangentWS.xyz, ml.direction, viewDirWS,
                                               _AnisoShift, _AnisoExponent);
                aniso = smoothstep(0.5h, 0.7h, aniso); // bậc cứng kiểu toon
                color += aniso * _AnisoStrength * _AnisoColor.rgb * ml.color
                       * (ml.shadowAttenuation * ml.distanceAttenuation);
            #endif

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
    CustomEditor "StylizedToonWorldKit.Editor.MetalGUI"
}
