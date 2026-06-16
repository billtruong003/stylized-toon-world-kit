// =============================================================================
//  StylizedGrass.shader  —  Stylized Toon World Kit / P2 Environment
// -----------------------------------------------------------------------------
//  CỎ / TÁN LÁ (grass card / billboard / quad):
//    • Wind sway vertex: dao động sin theo world XZ + gust noise, mask theo
//      chiều cao blade (uv.y: gốc 0 → ngọn 1) → gốc đứng yên, ngọn lắc.
//    • Gradient gốc→ngọn (root/tip color) cho chiều sâu màu.
//    • Translucency (back-light SSS giả): ánh sáng xuyên lá khi nhìn ngược nắng.
//    • Alpha-clip (keyword _ALPHATEST) cho texture cỏ; toon ramp colored shadow.
//  Opaque/cutout lit. ShadowCaster + DepthNormals dùng CHUNG hàm wind (đồng bộ).
//  URP 17 / U6 · SRP Batcher · GPU Instancing · VR SPI.
// =============================================================================
Shader "StylizedToonWorldKit/Environment/Grass"
{
    Properties
    {
        [MainTexture] _BaseMap ("Base Map (RGB, A=mask)", 2D) = "white" {}
        _RootColor ("Root Color", Color) = (0.12,0.35,0.1,1)
        _TipColor  ("Tip Color", Color)  = (0.5,0.8,0.25,1)
        _GradientPower ("Gradient Power", Range(0.2,4)) = 1

        [Toggle(_ALPHATEST)] _AlphaClipToggle ("Enable Alpha Clip", Float) = 1
        _Cutoff ("Alpha Cutoff", Range(0,1)) = 0.4

        [Header(Wind)][Space(4)]
        _WindDir   ("Wind Direction (xz)", Vector) = (1,0,0.3,0)
        _WindStrength ("Wind Strength", Range(0,2)) = 0.3
        _WindSpeed ("Wind Speed", Range(0,8)) = 2
        _WindFreq  ("Wind Spatial Freq", Range(0,2)) = 0.4
        _GustStrength ("Gust Strength", Range(0,1)) = 0.4

        [Header(Lighting)][Space(4)]
        _ShadowTint ("Shadow Tint", Color) = (0.2,0.3,0.18,1)
        _RampSteps  ("Cel Steps", Range(1,6)) = 2
        _RampSmooth ("Ramp Softness", Range(0,1)) = 0.1
        _GIStrength ("GI Strength", Range(0,2)) = 1
        _Occlusion  ("Occlusion", Range(0,1)) = 1

        [Header(Translucency)][Space(4)]
        [HDR] _TransColor ("Translucency Color", Color) = (0.4,0.7,0.2,1)
        _TransStrength ("Translucency Strength", Range(0,4)) = 1
        _TransPower ("Translucency Power", Range(0.5,8)) = 3

        [HideInInspector] _Cull ("Cull", Float) = 0
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="TransparentCutout" "Queue"="AlphaTest" }
        LOD 250

        HLSLINCLUDE
        #include "../Core/StylizedLighting.hlsl"

        CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            half4  _RootColor;
            half4  _TipColor;
            half   _GradientPower;
            half   _Cutoff;
            float4 _WindDir;
            half   _WindStrength;
            half   _WindSpeed;
            half   _WindFreq;
            half   _GustStrength;
            half4  _ShadowTint;
            half   _RampSteps;
            half   _RampSmooth;
            half   _GIStrength;
            half   _Occlusion;
            half4  _TransColor;
            half   _TransStrength;
            half   _TransPower;
            half   _Cull;
        CBUFFER_END

        // Wind sway: lắc ngọn theo world XZ + thời gian, mask theo heightMask (uv.y).
        // Trả offset world-space (chỉ XZ). Dùng chung mọi pass để bóng/depth khớp.
        float3 GrassWind(float3 positionWS, float heightMask)
        {
            float2 dir = normalize(_WindDir.xz + float2(1e-4, 0));
            float phase = dot(positionWS.xz, dir) * _WindFreq + _Time.y * _WindSpeed;
            float sway = sin(phase) + 0.5 * sin(phase * 2.3 + 1.7);
            // gust: dao động chậm toàn vùng tạo "đợt gió"
            float gust = sin(_Time.y * _WindSpeed * 0.27 + dot(positionWS.xz, float2(0.13, 0.09)));
            float amp = _WindStrength * (1.0 + gust * _GustStrength);
            float bend = sway * amp * heightMask * heightMask; // bậc 2: cong tự nhiên
            return float3(dir.x * bend, 0, dir.y * bend);
        }
        ENDHLSL

        // ---------------------------------------------------------------------
        //  PASS 1 — ForwardLit
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

            #pragma shader_feature_local _ALPHATEST

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile _ _FORWARD_PLUS
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
                DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 5)
                STW_VERTEX_OUTPUT_STEREO
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT = (Varyings)0;
                STW_SETUP_INSTANCE_VERT(IN, OUT);

                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                positionWS += GrassWind(positionWS, IN.uv.y);

                OUT.positionWS = positionWS;
                OUT.positionCS = TransformWorldToHClip(positionWS);
                OUT.normalWS   = TransformObjectToWorldNormal(IN.normalOS);
                OUT.uv         = TRANSFORM_TEX(IN.uv, _BaseMap);
                OUT.shadowCoord= TransformWorldToShadowCoord(positionWS);
                OUT.fogCoord   = ComputeFogFactor(OUT.positionCS.z);
                OUTPUT_LIGHTMAP_UV(IN.lightmapUV, unity_LightmapST, OUT.lightmapUV);
                OUTPUT_SH(OUT.normalWS, OUT.vertexSH);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                STW_SETUP_INSTANCE_FRAG(IN);

                half4 tex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);
            #if defined(_ALPHATEST)
                clip(tex.a - _Cutoff);
            #endif

                // gradient gốc→ngọn theo uv.y
                half grad = pow(saturate(IN.uv.y), _GradientPower);
                half3 albedo = tex.rgb * lerp(_RootColor.rgb, _TipColor.rgb, grad);

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

                // translucency: ánh sáng xuyên lá khi view ngược light
                Light ml = STW_GetMainLight(IN.shadowCoord, IN.positionWS, shadowMask);
                half trans = pow(saturate(dot(s.viewDirWS, -ml.direction)), _TransPower);
                color += trans * _TransStrength * _TransColor.rgb * ml.color * grad;

                color = STW_ApplyFog(color, IN.fogCoord);
                return half4(color, 1);
            }
            ENDHLSL
        }

        // ---------------------------------------------------------------------
        //  PASS 2 — ShadowCaster (wind khớp ForwardLit)
        // ---------------------------------------------------------------------
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode"="ShadowCaster" }
            ZWrite On ZTest LEqual ColorMask 0 Cull [_Cull]

            HLSLPROGRAM
            #pragma vertex   shadowVert
            #pragma fragment shadowFrag
            #pragma shader_feature_local _ALPHATEST
            #pragma multi_compile_instancing
            #pragma multi_compile _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            float3 _LightDirection;
            float3 _LightPosition;

            struct AttributesS { float4 positionOS:POSITION; float3 normalOS:NORMAL; float2 uv:TEXCOORD0; STW_VERTEX_INPUT_INSTANCE_ID };
            struct VaryingsS   { float4 positionCS:SV_POSITION; float2 uv:TEXCOORD0; STW_VERTEX_OUTPUT_STEREO };

            VaryingsS shadowVert(AttributesS IN)
            {
                VaryingsS OUT = (VaryingsS)0;
                STW_SETUP_INSTANCE_VERT(IN, OUT);

                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                positionWS += GrassWind(positionWS, IN.uv.y);
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
            #if defined(_ALPHATEST)
                clip(SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv).a - _Cutoff);
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
            #pragma shader_feature_local _ALPHATEST
            #pragma multi_compile_instancing

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);

            struct AttributesDN { float4 positionOS:POSITION; float3 normalOS:NORMAL; float2 uv:TEXCOORD0; STW_VERTEX_INPUT_INSTANCE_ID };
            struct VaryingsDN   { float4 positionCS:SV_POSITION; half3 normalWS:TEXCOORD0; float2 uv:TEXCOORD1; STW_VERTEX_OUTPUT_STEREO };

            VaryingsDN dnVert(AttributesDN IN)
            {
                VaryingsDN OUT = (VaryingsDN)0;
                STW_SETUP_INSTANCE_VERT(IN, OUT);
                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                positionWS += GrassWind(positionWS, IN.uv.y);
                OUT.positionCS = TransformWorldToHClip(positionWS);
                OUT.normalWS   = TransformObjectToWorldNormal(IN.normalOS);
                OUT.uv         = TRANSFORM_TEX(IN.uv, _BaseMap);
                return OUT;
            }

            half4 dnFrag(VaryingsDN IN) : SV_Target
            {
                STW_SETUP_INSTANCE_FRAG(IN);
            #if defined(_ALPHATEST)
                clip(SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv).a - _Cutoff);
            #endif
                float3 n = NormalizeNormalPerPixel(IN.normalWS);
                return half4(n * 0.5 + 0.5, 0);
            }
            ENDHLSL
        }
    }

    FallBack Off
    CustomEditor "StylizedToonWorldKit.Editor.GrassGUI"
}
