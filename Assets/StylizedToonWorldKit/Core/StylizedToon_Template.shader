// =============================================================================
//  StylizedToon_Template.shader  —  Stylized Toon World Kit / P0 reference
// -----------------------------------------------------------------------------
//  KHÔNG phải shader bán. Đây là MẪU CHUẨN ("skeleton") mọi shader pack copy:
//  thể hiện đầy đủ convention của kit để các sprint sau làm theo, không nghĩ lại:
//    • CBUFFER_START(UnityPerMaterial) gói TẤT property  → SRP Batcher OK.
//    • Macro TEXTURE2D/SAMPLER (không sampler2D).
//    • VR Single-Pass Instanced qua macro STW_* của URPCompat.
//    • Pragma keyword chuẩn (Forward+/shadow/lightmap/fog/instancing).
//    • 3 pass: ForwardLit + ShadowCaster + DepthNormals (cần cho SS outline/SSAO).
//    • Gọi STW_ToonLighting() từ Core → minh hoạ cách dùng P0.
//  Target: URP 17 / Unity 6. (Ghi chú down-version trong README.)
// =============================================================================
Shader "StylizedToonWorldKit/Core/Toon Template"
{
    Properties
    {
        [MainTexture] _BaseMap        ("Base Map", 2D) = "white" {}
        [MainColor]   _BaseColor      ("Base Color", Color) = (1,1,1,1)
        _ShadowTint   ("Shadow Tint", Color) = (0.45,0.5,0.6,1)
        _RampSteps    ("Cel Steps", Range(1,6)) = 3
        _RampSmooth   ("Ramp Softness", Range(0,1)) = 0.05
        _ShadowThresh ("Shadow Threshold", Range(0,1)) = 0.5
        _SpecStrength ("Specular Strength", Range(0,2)) = 0.0
        _SpecSize     ("Specular Size", Range(0,1)) = 0.2
        [HDR] _RimColor ("Rim Color", Color) = (1,1,1,1)
        _RimPower     ("Rim Power", Range(0.5,8)) = 3
        _RimStrength  ("Rim Strength", Range(0,2)) = 0.0
        _GIStrength   ("GI Strength", Range(0,2)) = 1.0
        [HDR] _Emission ("Emission", Color) = (0,0,0,0)

        // Render state (lộ ra ShaderGUI Advanced)
        [HideInInspector] _Cull ("Cull", Float) = 2          // Back
        [HideInInspector] _Surface ("Surface", Float) = 0     // Opaque
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" "Queue"="Geometry" }
        LOD 300

        // ---------------------------------------------------------------------
        //  PASS 1 — ForwardLit (toon shading)
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

            // -- Lighting / GI keywords (xem checklist URPCompat) --
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile _ _FORWARD_PLUS
            #pragma multi_compile _ LIGHTMAP_ON DYNAMICLIGHTMAP_ON
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fog
            // -- Instancing + VR SPI --
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer

            #include "URPCompat.hlsl"
            #include "StylizedLighting.hlsl"

            // SRP Batcher: TẤT property trong 1 CBUFFER.
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4  _BaseColor;
                half4  _ShadowTint;
                half   _RampSteps;
                half   _RampSmooth;
                half   _ShadowThresh;
                half   _SpecStrength;
                half   _SpecSize;
                half4  _RimColor;
                half   _RimPower;
                half   _RimStrength;
                half   _GIStrength;
                half4  _Emission;
                half   _Cull;
                half   _Surface;
            CBUFFER_END

            TEXTURE2D(_BaseMap);  SAMPLER(sampler_BaseMap);

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

                half4 baseTex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);

                STWToonSurface s;
                s.albedo     = baseTex.rgb * _BaseColor.rgb;
                s.normalWS   = STW_SafeNormalize(IN.normalWS);
                s.viewDirWS  = STW_SafeNormalize(GetWorldSpaceViewDir(IN.positionWS));
                s.positionWS = IN.positionWS;
                s.smoothness = _SpecSize;
                s.occlusion  = 1.0h;
                s.emission   = _Emission.rgb;

                STWToonParams p;
                p.shadowTint       = _ShadowTint.rgb;
                p.rampSteps        = _RampSteps;
                p.rampSmoothness   = _RampSmooth;
                p.shadowThreshold  = _ShadowThresh;
                p.specularStrength = _SpecStrength;
                p.specularSize     = _SpecSize;
                p.rimColor         = _RimColor.rgb;
                p.rimPower         = _RimPower;
                p.rimStrength      = _RimStrength;
                p.giStrength       = _GIStrength;

                half4 shadowMask = half4(1,1,1,1);
                half3 color = STW_ToonLighting(s, p, IN.shadowCoord, shadowMask);
                color = STW_ApplyFog(color, IN.fogCoord);

                return half4(color, baseTex.a * _BaseColor.a);
            }
            ENDHLSL
        }

        // ---------------------------------------------------------------------
        //  PASS 2 — ShadowCaster (đổ bóng)
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

            #include "URPCompat.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST; half4 _BaseColor; half4 _ShadowTint;
                half _RampSteps; half _RampSmooth; half _ShadowThresh;
                half _SpecStrength; half _SpecSize; half4 _RimColor;
                half _RimPower; half _RimStrength; half _GIStrength;
                half4 _Emission; half _Cull; half _Surface;
            CBUFFER_END

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
        //  PASS 3 — DepthNormals (cần cho SS outline + SSAO)
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

            #include "URPCompat.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST; half4 _BaseColor; half4 _ShadowTint;
                half _RampSteps; half _RampSmooth; half _ShadowThresh;
                half _SpecStrength; half _SpecSize; half4 _RimColor;
                half _RimPower; half _RimStrength; half _GIStrength;
                half4 _Emission; half _Cull; half _Surface;
            CBUFFER_END

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
    CustomEditor "StylizedToonWorldKit.Editor.StylizedToonTemplateGUI"
}
