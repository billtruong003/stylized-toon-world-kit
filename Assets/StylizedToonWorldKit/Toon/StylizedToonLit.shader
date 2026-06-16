// =============================================================================
//  StylizedToonLit.shader  —  Stylized Toon World Kit / P1 Toon & Outline
// -----------------------------------------------------------------------------
//  SHADER NỀN TẢNG của pack: cel/toon lit đầy đủ, bán được ngay.
//    • Cel ramp nhiều bước (step) HOẶC texture-ramp 1D LUT (keyword _RAMP_TEXTURE).
//    • Màu shadow tuỳ chỉnh (banded colored shadow, không nhân đen).
//    • Nhận main + additional light THẬT (Forward & Forward+), shadow, GI/SH.
//    • Normal map (keyword _NORMALMAP), toon specular, rim/fresnel (keyword _RIM).
//    • Emission map (keyword _EMISSION).
//  Toàn bộ math toon trỏ về P0 (StylizedLighting.hlsl) — modular, không lặp.
//
//  PERF: 1 material = 1 draw (giữ SRP Batcher + GPU instancing + VR SPI). Outline
//  KHÔNG nằm ở đây → chọn biến thể: Inverted-Hull (per-material) hoặc Screen-Space
//  (renderer feature). Xem README "Outline: chọn biến thể nào".
//  Target: URP 17 / Unity 6. Down-version note ở README.
// =============================================================================
Shader "StylizedToonWorldKit/Toon/Toon Lit"
{
    Properties
    {
        [MainTexture] _BaseMap    ("Base Map", 2D) = "white" {}
        [MainColor]   _BaseColor  ("Base Color", Color) = (1,1,1,1)

        [Toggle(_NORMALMAP)] _NormalMapToggle ("Enable Normal Map", Float) = 0
        [Normal] _BumpMap   ("Normal Map", 2D) = "bump" {}
        _BumpScale ("Normal Scale", Range(0,2)) = 1

        // Cel shading
        _ShadowTint   ("Shadow Tint", Color) = (0.45,0.5,0.6,1)
        [Toggle(_RAMP_TEXTURE)] _RampTexToggle ("Use Ramp Texture (1D LUT)", Float) = 0
        _RampMap      ("Ramp (1D LUT)", 2D) = "white" {}
        _RampSteps    ("Cel Steps", Range(1,6)) = 3
        _RampSmooth   ("Ramp Softness", Range(0,1)) = 0.05
        _GIStrength   ("GI Strength", Range(0,2)) = 1.0
        _Occlusion    ("Occlusion", Range(0,1)) = 1.0

        // Specular
        _SpecStrength ("Specular Strength", Range(0,2)) = 0.0
        _SpecSize     ("Specular Size", Range(0,1)) = 0.2

        // Rim
        [Toggle(_RIM)] _RimToggle ("Enable Rim", Float) = 0
        [HDR] _RimColor ("Rim Color", Color) = (1,1,1,1)
        _RimPower     ("Rim Power", Range(0.5,8)) = 3
        _RimStrength  ("Rim Strength", Range(0,2)) = 1.0

        // Emission
        [Toggle(_EMISSION)] _EmissionToggle ("Enable Emission", Float) = 0
        _EmissionMap  ("Emission Map", 2D) = "white" {}
        [HDR] _Emission ("Emission Color", Color) = (0,0,0,0)

        // Render state (ShaderGUI Advanced)
        [HideInInspector] _Cull ("Cull", Float) = 2
        [HideInInspector] _Surface ("Surface", Float) = 0
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" "Queue"="Geometry" }
        LOD 300

        // -- shared CBUFFER (SRP Batcher) — copy y hệt vào mọi pass --
        HLSLINCLUDE
        #include "../Core/URPCompat.hlsl"
        CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            float4 _BumpMap_ST;
            half4  _BaseColor;
            half   _BumpScale;
            half4  _ShadowTint;
            half   _RampSteps;
            half   _RampSmooth;
            half   _GIStrength;
            half   _Occlusion;
            half   _SpecStrength;
            half   _SpecSize;
            half4  _RimColor;
            half   _RimPower;
            half   _RimStrength;
            float4 _EmissionMap_ST;
            half4  _Emission;
            half   _Cull;
            half   _Surface;
        CBUFFER_END
        ENDHLSL

        // ---------------------------------------------------------------------
        //  PASS 1 — ForwardLit (toon)
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

            // feature keywords
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _RAMP_TEXTURE
            #pragma shader_feature_local _RIM
            #pragma shader_feature_local _EMISSION

            // URP lighting/GI keywords (checklist URPCompat)
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

            #include "../Core/StylizedLighting.hlsl"

            TEXTURE2D(_BaseMap);      SAMPLER(sampler_BaseMap);
            TEXTURE2D(_BumpMap);      SAMPLER(sampler_BumpMap);
            TEXTURE2D(_RampMap);      SAMPLER(sampler_RampMap);
            TEXTURE2D(_EmissionMap);  SAMPLER(sampler_EmissionMap);

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
                float4 tangentWS  : TEXCOORD3;   // xyz tangent, w sign
                float4 shadowCoord: TEXCOORD4;
                half   fogCoord   : TEXCOORD5;
                DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 6)
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

                // --- normal (tangent-space map -> world) ---
                half3 normalWS = STW_SafeNormalize(IN.normalWS);
            #if defined(_NORMALMAP)
                half3 nTS = UnpackNormalScale(
                    SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, TRANSFORM_TEX(IN.uv, _BumpMap)), _BumpScale);
                half3 bitangent = IN.tangentWS.w * cross(normalWS, IN.tangentWS.xyz);
                half3x3 tbn = half3x3(IN.tangentWS.xyz, bitangent, normalWS);
                normalWS = STW_SafeNormalize(mul(nTS, tbn));
            #endif

                STWToonSurface s;
                s.albedo     = baseTex.rgb * _BaseColor.rgb;
                s.normalWS   = normalWS;
                s.viewDirWS  = STW_SafeNormalize(GetWorldSpaceViewDir(IN.positionWS));
                s.positionWS = IN.positionWS;
                s.screenUV   = GetNormalizedScreenSpaceUV(IN.positionCS);
                s.smoothness = _SpecSize;
                s.occlusion  = _Occlusion;
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
                p.specularStrength = _SpecStrength;
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

            #if defined(_RAMP_TEXTURE)
                // Texture-ramp path: lấy màu ramp theo half-lambert (main light) rồi
                // vẫn dùng STW_ToonLighting cho add-light/GI/rim. Ramp LUT thay tint.
                Light ml = STW_GetMainLight(IN.shadowCoord, IN.positionWS, shadowMask);
                half  nl = dot(s.normalWS, ml.direction) * (ml.shadowAttenuation * ml.distanceAttenuation);
                half3 rampCol = STW_RampTexture(TEXTURE2D_ARGS(_RampMap, sampler_RampMap), nl);
                // override shadowTint bằng màu tối nhất của LUT để add-light đồng bộ
                p.shadowTint = rampCol;
                half3 color = STW_ToonLighting(s, p, IN.shadowCoord, shadowMask);
            #else
                half3 color = STW_ToonLighting(s, p, IN.shadowCoord, shadowMask);
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
        //  PASS 3 — DepthNormals (SS outline + SSAO)
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
            #pragma shader_feature_local _NORMALMAP

            TEXTURE2D(_BumpMap); SAMPLER(sampler_BumpMap);

            struct AttributesDN { float4 positionOS:POSITION; float3 normalOS:NORMAL; float4 tangentOS:TANGENT; float2 uv:TEXCOORD0; STW_VERTEX_INPUT_INSTANCE_ID };
            struct VaryingsDN   { float4 positionCS:SV_POSITION; float3 normalWS:TEXCOORD0; float2 uv:TEXCOORD1; STW_VERTEX_OUTPUT_STEREO };

            VaryingsDN dnVert(AttributesDN IN)
            {
                VaryingsDN OUT = (VaryingsDN)0;
                STW_SETUP_INSTANCE_VERT(IN, OUT);
                VertexPositionInputs pos = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs   nrm = GetVertexNormalInputs(IN.normalOS);
                OUT.positionCS = pos.positionCS;
                OUT.normalWS   = nrm.normalWS;
                OUT.uv         = TRANSFORM_TEX(IN.uv, _BumpMap);
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
    CustomEditor "StylizedToonWorldKit.Editor.ToonLitGUI"
}
