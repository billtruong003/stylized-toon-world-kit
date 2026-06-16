// =============================================================================
//  StylizedTree.shader  —  Stylized Toon World Kit / P2 Environment
// -----------------------------------------------------------------------------
//  CÂY / TÁN LÁ (trunk + leaf cards):
//    • Wind 2 tầng: lắc thân (thấp tần, theo world) + rung lá (cao tần) — mask
//      theo vertex color.a (chuẩn foliage Unity) HOẶC uv.y nếu không vẽ màu đỉnh.
//    • Subsurface (translucency) cho lá xuyên nắng.
//    • Alpha-clip DITHER (keyword _ALPHADITHER): khử răng cưa mép lá bằng nhiễu
//      ổn định màn hình (mịn hơn clip cứng, hợp cây nhiều lớp lá).
//    • Toon ramp colored shadow + GI.
//  Opaque/cutout lit. ShadowCaster + DepthNormals dùng CHUNG wind. URP 17 / U6.
// =============================================================================
Shader "StylizedToonWorldKit/Environment/Tree"
{
    Properties
    {
        [MainTexture] _BaseMap ("Base Map (RGB, A=mask)", 2D) = "white" {}
        [MainColor]   _BaseColor ("Base Color", Color) = (1,1,1,1)
        _TipColor  ("Leaf Tip Tint", Color) = (0.7,0.9,0.45,1)
        _TipBlend  ("Tip Tint Blend", Range(0,1)) = 0.35

        _Cutoff ("Alpha Cutoff", Range(0,1)) = 0.4
        [Toggle(_ALPHADITHER)] _DitherToggle ("Dither Alpha Edge", Float) = 1

        [Header(Wind)][Space(4)]
        _WindDir   ("Wind Direction (xz)", Vector) = (1,0,0.4,0)
        _TrunkSway ("Trunk Sway", Range(0,1)) = 0.1
        _LeafFlutter ("Leaf Flutter", Range(0,1)) = 0.25
        _WindSpeed ("Wind Speed", Range(0,8)) = 1.5
        _WindFreq  ("Wind Spatial Freq", Range(0,2)) = 0.25
        [Toggle(_VERTEXCOLOR_MASK)] _VCMaskToggle ("Use Vertex Color.a as Wind Mask", Float) = 0

        [Header(Lighting)][Space(4)]
        _ShadowTint ("Shadow Tint", Color) = (0.18,0.28,0.16,1)
        _RampSteps  ("Cel Steps", Range(1,6)) = 2
        _RampSmooth ("Ramp Softness", Range(0,1)) = 0.12
        _GIStrength ("GI Strength", Range(0,2)) = 1
        _Occlusion  ("Occlusion", Range(0,1)) = 1

        [Header(Translucency)][Space(4)]
        [HDR] _TransColor ("Translucency Color", Color) = (0.35,0.65,0.2,1)
        _TransStrength ("Translucency Strength", Range(0,4)) = 1
        _TransPower ("Translucency Power", Range(0.5,8)) = 3

        [HideInInspector] _Cull ("Cull", Float) = 0
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest  ("ZTest", Float) = 4
        [Enum(Off,0,On,1)]                            _ZWrite ("ZWrite", Float) = 1
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="TransparentCutout" "Queue"="AlphaTest" }
        LOD 250

        HLSLINCLUDE
        #include "../Core/StylizedLighting.hlsl"
        #include "../Core/StylizedNoise.hlsl"   // STW_Hash21 cho DitherClip

        CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            half4  _BaseColor;
            half4  _TipColor;
            half   _TipBlend;
            half   _Cutoff;
            float4 _WindDir;
            half   _TrunkSway;
            half   _LeafFlutter;
            half   _WindSpeed;
            half   _WindFreq;
            half4  _ShadowTint;
            half   _RampSteps;
            half   _RampSmooth;
            half   _GIStrength;
            half   _Occlusion;
            half4  _TransColor;
            half   _TransStrength;
            half   _TransPower;
            half   _Cull; half _ZTest; half _ZWrite;
        CBUFFER_END

        // Wind cây: thân lắc chậm (theo world) + lá rung nhanh, mask = bendMask.
        float3 TreeWind(float3 positionWS, half bendMask)
        {
            float2 dir = normalize(_WindDir.xz + float2(1e-4, 0));
            float t = _Time.y * _WindSpeed;
            // thân: sóng chậm theo XZ
            float trunkPhase = dot(positionWS.xz, float2(0.07, 0.05)) + t * 0.5;
            float trunk = sin(trunkPhase) * _TrunkSway;
            // lá: rung nhanh theo vị trí + thời gian
            float leafPhase = dot(positionWS.xz, float2(1.0, 1.0)) * _WindFreq + t * 3.0;
            float leaf = (sin(leafPhase) + sin(leafPhase * 1.9 + 2.1)) * 0.5 * _LeafFlutter;
            float bend = (trunk + leaf) * bendMask;
            float3 offset = float3(dir.x * bend, leaf * bendMask * 0.3, dir.y * bend);
            return offset;
        }

        // Dither: hash màn hình ổn định → so với alpha cho mép mịn (alpha-to-coverage giả).
        void DitherClip(half alpha, float4 positionCS)
        {
            float d = STW_Hash21(floor(positionCS.xy));
            clip(alpha - max(_Cutoff, d * (1.0 - _Cutoff)));
        }
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

            #pragma shader_feature_local _ALPHADITHER
            #pragma shader_feature_local _VERTEXCOLOR_MASK

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile _ _CLUSTER_LIGHT_LOOP
            #pragma multi_compile _ LIGHTMAP_ON DYNAMICLIGHTMAP_ON
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile_fog
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
                float2 lightmapUV : TEXCOORD1;
                half4  color      : COLOR;
                STW_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                half3  normalWS   : TEXCOORD2;
                float4 shadowCoord: TEXCOORD3;
                half   fogCoord   : TEXCOORD4;
                half   tipMask    : TEXCOORD5;
                DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 6);
                STW_VERTEX_OUTPUT_STEREO
            };

            half BendMask(half4 color, float2 uv)
            {
            #if defined(_VERTEXCOLOR_MASK)
                return color.a;
            #else
                return saturate(uv.y);
            #endif
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT = (Varyings)0;
                STW_SETUP_INSTANCE_VERT(IN, OUT);

                half mask = BendMask(IN.color, IN.uv);
                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                positionWS += TreeWind(positionWS, mask);

                OUT.positionWS = positionWS;
                OUT.positionCS = TransformWorldToHClip(positionWS);
                OUT.normalWS   = TransformObjectToWorldNormal(IN.normalOS);
                OUT.uv         = TRANSFORM_TEX(IN.uv, _BaseMap);
                OUT.shadowCoord= TransformWorldToShadowCoord(positionWS);
                OUT.fogCoord   = ComputeFogFactor(OUT.positionCS.z);
                OUT.tipMask    = mask;
                OUTPUT_LIGHTMAP_UV(IN.lightmapUV, unity_LightmapST, OUT.lightmapUV);
                OUTPUT_SH(OUT.normalWS, OUT.vertexSH);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                STW_SETUP_INSTANCE_FRAG(IN);

                half4 tex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);
            #if defined(_ALPHADITHER)
                DitherClip(tex.a, IN.positionCS);
            #else
                clip(tex.a - _Cutoff);
            #endif

                half3 albedo = tex.rgb * _BaseColor.rgb;
                albedo = lerp(albedo, albedo * _TipColor.rgb, IN.tipMask * _TipBlend);

                half3 normalWS = STW_SafeNormalize(IN.normalWS);
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

                half3 color = STW_ToonLighting(s, p, IN.shadowCoord, shadowMask);

                Light ml = STW_GetMainLight(IN.shadowCoord, IN.positionWS, shadowMask);
                half trans = pow(saturate(dot(s.viewDirWS, -ml.direction)), _TransPower);
                color += trans * _TransStrength * _TransColor.rgb * ml.color * IN.tipMask;

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
            #pragma shader_feature_local _ALPHADITHER
            #pragma shader_feature_local _VERTEXCOLOR_MASK
            #pragma multi_compile_instancing
            #pragma multi_compile _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            float3 _LightDirection;
            float3 _LightPosition;

            struct AttributesS { float4 positionOS:POSITION; float3 normalOS:NORMAL; float2 uv:TEXCOORD0; half4 color:COLOR; STW_VERTEX_INPUT_INSTANCE_ID };
            struct VaryingsS   { float4 positionCS:SV_POSITION; float2 uv:TEXCOORD0; STW_VERTEX_OUTPUT_STEREO };

            half BendMaskS(half4 color, float2 uv)
            {
            #if defined(_VERTEXCOLOR_MASK)
                return color.a;
            #else
                return saturate(uv.y);
            #endif
            }

            VaryingsS shadowVert(AttributesS IN)
            {
                VaryingsS OUT = (VaryingsS)0;
                STW_SETUP_INSTANCE_VERT(IN, OUT);

                half mask = BendMaskS(IN.color, IN.uv);
                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                positionWS += TreeWind(positionWS, mask);
                float3 normalWS = TransformObjectToWorldNormal(IN.normalOS);

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
                OUT.positionCS = cs;
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                return OUT;
            }

            half4 shadowFrag(VaryingsS IN) : SV_Target
            {
                half a = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv).a;
            #if defined(_ALPHADITHER)
                DitherClip(a, IN.positionCS);
            #else
                clip(a - _Cutoff);
            #endif
                return 0;
            }
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
            #pragma shader_feature_local _ALPHADITHER
            #pragma shader_feature_local _VERTEXCOLOR_MASK
            #pragma multi_compile_instancing

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);

            struct AttributesDN { float4 positionOS:POSITION; float3 normalOS:NORMAL; float2 uv:TEXCOORD0; half4 color:COLOR; STW_VERTEX_INPUT_INSTANCE_ID };
            struct VaryingsDN   { float4 positionCS:SV_POSITION; half3 normalWS:TEXCOORD0; float2 uv:TEXCOORD1; STW_VERTEX_OUTPUT_STEREO };

            half BendMaskDN(half4 color, float2 uv)
            {
            #if defined(_VERTEXCOLOR_MASK)
                return color.a;
            #else
                return saturate(uv.y);
            #endif
            }

            VaryingsDN dnVert(AttributesDN IN)
            {
                VaryingsDN OUT = (VaryingsDN)0;
                STW_SETUP_INSTANCE_VERT(IN, OUT);
                half mask = BendMaskDN(IN.color, IN.uv);
                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                positionWS += TreeWind(positionWS, mask);
                OUT.positionCS = TransformWorldToHClip(positionWS);
                OUT.normalWS   = TransformObjectToWorldNormal(IN.normalOS);
                OUT.uv         = TRANSFORM_TEX(IN.uv, _BaseMap);
                return OUT;
            }

            half4 dnFrag(VaryingsDN IN) : SV_Target
            {
                STW_SETUP_INSTANCE_FRAG(IN);
                half a = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv).a;
            #if defined(_ALPHADITHER)
                DitherClip(a, IN.positionCS);
            #else
                clip(a - _Cutoff);
            #endif
                float3 n = NormalizeNormalPerPixel(IN.normalWS);
                return half4(n * 0.5 + 0.5, 0);
            }
            ENDHLSL
        }
    }

    FallBack Off
    CustomEditor "StylizedToonWorldKit.Editor.TreeGUI"
}
