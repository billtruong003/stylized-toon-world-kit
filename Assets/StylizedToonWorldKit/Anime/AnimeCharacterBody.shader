// =============================================================================
//  AnimeCharacterBody.shader  —  Stylized Toon World Kit / P5 Anime NPR
// -----------------------------------------------------------------------------
//  Body NPR cho nhân vật anime: cel ramp + colored shadow + ILM mask (kiểu
//  Genshin/Honkai) điều khiển specular & AO theo vùng + rim + emission.
//    • Toon lighting đầy đủ (main + additional Forward+ + GI) trỏ P0.
//    • ILM map (keyword _ILM): R = cường độ specular per-vùng, G = AO/bóng vùng.
//      (artist vẽ mask để áp giáp/da/vải khác nhau bằng 1 material.)
//    • Toon specular bậc (anime highlight phẳng), rim/fresnel, emission map.
//    • SDF-ready & outline-ready: pass DepthNormals + ShadowCaster đủ để dùng
//      với Screen-Space Outline feature hoặc Inverted-Hull (P1).
//  PERF: 1 draw, SRP Batcher + GPU instancing + VR SPI. Target URP 17 / Unity 6.
// =============================================================================
Shader "StylizedToonWorldKit/Anime/Character Body"
{
    Properties
    {
        [MainTexture] _BaseMap   ("Base Map", 2D) = "white" {}
        [MainColor]   _BaseColor ("Base Color", Color) = (1,1,1,1)

        [Toggle(_NORMALMAP)] _NormalMapToggle ("Enable Normal Map", Float) = 0
        [Normal] _BumpMap ("Normal Map", 2D) = "bump" {}
        _BumpScale ("Normal Scale", Range(0,2)) = 1

        // Cel shading
        _ShadowTint  ("Shadow Tint", Color) = (0.55,0.5,0.62,1)
        _RampSteps   ("Cel Steps", Range(1,6)) = 2
        _RampSmooth  ("Ramp Softness", Range(0,1)) = 0.06
        _GIStrength  ("GI Strength", Range(0,2)) = 1.0
        _Occlusion   ("Occlusion", Range(0,1)) = 1.0

        // ILM material mask (R=spec intensity, G=AO)
        [Toggle(_ILM)] _ILMToggle ("Enable ILM Mask (R spec / G AO)", Float) = 0
        _ILMMap ("ILM Mask", 2D) = "white" {}

        // Toon specular
        [HDR] _SpecColor2 ("Specular Color", Color) = (1,1,1,1)
        _SpecStrength ("Specular Strength", Range(0,2)) = 0.0
        _SpecSize     ("Specular Size", Range(0,1)) = 0.2

        // Rim
        [Toggle(_RIM)] _RimToggle ("Enable Rim", Float) = 0
        [HDR] _RimColor ("Rim Color", Color) = (1,1,1,1)
        _RimPower    ("Rim Power", Range(0.5,8)) = 4
        _RimStrength ("Rim Strength", Range(0,2)) = 1.0

        // Emission
        [Toggle(_EMISSION)] _EmissionToggle ("Enable Emission", Float) = 0
        _EmissionMap ("Emission Map", 2D) = "white" {}
        [HDR] _Emission ("Emission Color", Color) = (0,0,0,0)

        [HideInInspector] _Cull ("Cull", Float) = 2
        [HideInInspector] _Surface ("Surface", Float) = 0
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
            float4 _BumpMap_ST;
            float4 _ILMMap_ST;
            float4 _EmissionMap_ST;
            half4  _BaseColor;
            half   _BumpScale;
            half4  _ShadowTint;
            half   _RampSteps;
            half   _RampSmooth;
            half   _GIStrength;
            half   _Occlusion;
            half4  _SpecColor2;
            half   _SpecStrength;
            half   _SpecSize;
            half4  _RimColor;
            half   _RimPower;
            half   _RimStrength;
            half4  _Emission;
            half   _Cull;
            half   _Surface; half _ZTest; half _ZWrite;
        CBUFFER_END
        ENDHLSL

        // -- PASS 1: ForwardLit ------------------------------------------------
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
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _ILM
            #pragma shader_feature_local _RIM
            #pragma shader_feature_local _EMISSION
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

            TEXTURE2D(_BaseMap);     SAMPLER(sampler_BaseMap);
            TEXTURE2D(_BumpMap);     SAMPLER(sampler_BumpMap);
            TEXTURE2D(_ILMMap);      SAMPLER(sampler_ILMMap);
            TEXTURE2D(_EmissionMap); SAMPLER(sampler_EmissionMap);

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
                float4 tangentWS  : TEXCOORD3;
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
                OUT.tangentWS   = float4(nrm.tangentWS, IN.tangentOS.w * GetOddNegativeScale());
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
                half4 baseTex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);

                half3 normalWS = STW_SafeNormalize(IN.normalWS);
            #if defined(_NORMALMAP)
                half3 nTS = UnpackNormalScale(
                    SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, TRANSFORM_TEX(IN.uv, _BumpMap)), _BumpScale);
                half3 bitangent = IN.tangentWS.w * cross(normalWS, IN.tangentWS.xyz);
                half3x3 tbn = half3x3(IN.tangentWS.xyz, bitangent, normalWS);
                normalWS = STW_SafeNormalize(mul(nTS, tbn));
            #endif

                // ILM mask: R spec intensity, G AO
                half specMask = 1.0h;
                half ao = _Occlusion;
            #if defined(_ILM)
                half4 ilm = SAMPLE_TEXTURE2D(_ILMMap, sampler_ILMMap, TRANSFORM_TEX(IN.uv, _ILMMap));
                specMask = ilm.r;
                ao *= ilm.g;
            #endif

                STWToonSurface s;
                s.albedo     = baseTex.rgb * _BaseColor.rgb;
                s.normalWS   = normalWS;
                s.viewDirWS  = STW_SafeNormalize(GetWorldSpaceViewDir(IN.positionWS));
                s.positionWS = IN.positionWS;
                s.screenUV   = GetNormalizedScreenSpaceUV(IN.positionCS);
                s.smoothness = _SpecSize;
                s.occlusion  = ao;
            #if defined(_EMISSION)
                s.emission   = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap,
                                  TRANSFORM_TEX(IN.uv, _EmissionMap)).rgb * _Emission.rgb;
            #else
                s.emission   = half3(0,0,0);
            #endif

                STWToonParams p;
                p.shadowTint       = _ShadowTint.rgb;
                p.rampSteps        = _RampSteps;
                p.rampSmoothness   = _RampSmooth;
                p.shadowThreshold  = 0.5h;
                p.specularStrength = 0.0h;   // specular ILM-masked tự thêm dưới
                p.specularSize     = _SpecSize;
            #if defined(_RIM)
                p.rimColor         = _RimColor.rgb;
                p.rimPower         = _RimPower;
                p.rimStrength      = _RimStrength;
            #else
                p.rimColor         = half3(0,0,0);
                p.rimPower         = 1.0h;
                p.rimStrength      = 0.0h;
            #endif
                p.giStrength       = _GIStrength;

                half4 shadowMask = half4(1,1,1,1);
                half3 color = STW_ToonLighting(s, p, IN.shadowCoord, shadowMask);

                // ILM-masked toon specular (anime highlight phẳng)
                if (_SpecStrength > 0.0h)
                {
                    Light ml = STW_GetMainLight(IN.shadowCoord, IN.positionWS, shadowMask);
                    half atten = ml.shadowAttenuation * ml.distanceAttenuation;
                    half spec = STW_ToonSpecular(s.normalWS, ml.direction, s.viewDirWS, _SpecSize);
                    color += spec * _SpecStrength * specMask * _SpecColor2.rgb * ml.color * atten;
                }

                color = STW_ApplyFog(color, IN.fogCoord);
                return half4(color, baseTex.a * _BaseColor.a);
            }
            ENDHLSL
        }

        // -- PASS 2: ShadowCaster ----------------------------------------------
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode"="ShadowCaster" }
            ZWrite On ZTest LEqual ColorMask 0 Cull [_Cull]
            HLSLPROGRAM
            #pragma vertex   sv
            #pragma fragment sf
            #pragma multi_compile_instancing
            #pragma multi_compile _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            float3 _LightDirection; float3 _LightPosition;
            struct A { float4 positionOS:POSITION; float3 normalOS:NORMAL; STW_VERTEX_INPUT_INSTANCE_ID };
            struct V { float4 positionCS:SV_POSITION; STW_VERTEX_OUTPUT_STEREO };
            float4 SP(float3 pWS, float3 nWS)
            {
            #if _CASTING_PUNCTUAL_LIGHT_SHADOW
                float3 d = normalize(_LightPosition - pWS);
            #else
                float3 d = _LightDirection;
            #endif
                float4 cs = TransformWorldToHClip(ApplyShadowBias(pWS, nWS, d));
            #if UNITY_REVERSED_Z
                cs.z = min(cs.z, UNITY_NEAR_CLIP_VALUE);
            #else
                cs.z = max(cs.z, UNITY_NEAR_CLIP_VALUE);
            #endif
                return cs;
            }
            V sv(A IN){ V o=(V)0; STW_SETUP_INSTANCE_VERT(IN,o);
                VertexPositionInputs p=GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs nrm=GetVertexNormalInputs(IN.normalOS);
                o.positionCS=SP(p.positionWS, nrm.normalWS); return o; }
            half4 sf(V IN):SV_Target { return 0; }
            ENDHLSL
        }

        // -- PASS 3: DepthNormals ----------------------------------------------
        Pass
        {
            Name "DepthNormals"
            Tags { "LightMode"="DepthNormals" }
            ZWrite On Cull [_Cull]
            HLSLPROGRAM
            #pragma vertex   dv
            #pragma fragment df
            #pragma multi_compile_instancing
            struct A { float4 positionOS:POSITION; float3 normalOS:NORMAL; STW_VERTEX_INPUT_INSTANCE_ID };
            struct V { float4 positionCS:SV_POSITION; float3 normalWS:TEXCOORD0; STW_VERTEX_OUTPUT_STEREO };
            V dv(A IN){ V o=(V)0; STW_SETUP_INSTANCE_VERT(IN,o);
                VertexPositionInputs p=GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs nrm=GetVertexNormalInputs(IN.normalOS);
                o.positionCS=p.positionCS; o.normalWS=nrm.normalWS; return o; }
            half4 df(V IN):SV_Target { STW_SETUP_INSTANCE_FRAG(IN);
                float3 n=NormalizeNormalPerPixel(IN.normalWS); return half4(n*0.5+0.5,0); }
            ENDHLSL
        }
    }
    FallBack "Universal Render Pipeline/Lit"
    CustomEditor "StylizedToonWorldKit.Editor.AnimeBodyGUI"
}
