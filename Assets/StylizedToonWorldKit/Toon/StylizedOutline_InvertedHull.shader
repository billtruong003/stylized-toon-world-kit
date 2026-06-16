// =============================================================================
//  StylizedOutline_InvertedHull.shader  —  Stylized Toon World Kit / P1
// -----------------------------------------------------------------------------
//  BIẾN THỂ OUTLINE "feature-rich" (nguyên tắc #1): toon lit + outline per-material
//  bằng inverted-hull (phình mesh theo normal, vẽ mặt sau màu outline).
//    • Rẻ, chạy MỌI platform (mobile/PC/VR) — KHÔNG cần depth/normal prepass.
//    • ⚠️ Thêm 1 pass Outline (Cull Front) → +1 draw/material → có thể phá batch khi
//      nhiều material khác nhau. (Cùng mesh+material vẫn GPU-instancing được.)
//    • 2 width mode: World (xa nhỏ dần, chân thực) / Screen (đều theo pixel, game).
//    • Outline math trỏ P0 OutlineCommon.hlsl; toon trỏ StylizedLighting.hlsl.
//  Đối trọng: bản Screen-Space (renderer feature, 1 fullscreen pass, giữ batch scene).
//  Target: URP 17 / Unity 6.
// =============================================================================
Shader "StylizedToonWorldKit/Toon/Outline (Inverted Hull)"
{
    Properties
    {
        [MainTexture] _BaseMap    ("Base Map", 2D) = "white" {}
        [MainColor]   _BaseColor  ("Base Color", Color) = (1,1,1,1)
        _ShadowTint   ("Shadow Tint", Color) = (0.45,0.5,0.6,1)
        _RampSteps    ("Cel Steps", Range(1,6)) = 3
        _RampSmooth   ("Ramp Softness", Range(0,1)) = 0.05
        _GIStrength   ("GI Strength", Range(0,2)) = 1.0
        _SpecStrength ("Specular Strength", Range(0,2)) = 0.0
        _SpecSize     ("Specular Size", Range(0,1)) = 0.2

        // Outline
        [HDR] _OutlineColor ("Outline Color", Color) = (0,0,0,1)
        _OutlineWidth ("Outline Width", Range(0,10)) = 1.0
        [Toggle(_OUTLINE_SCREENSPACE)] _OutlineScreen ("Width = Screen-space (else World)", Float) = 1

        [HideInInspector] _Cull ("Cull", Float) = 2
        [HideInInspector] _Surface ("Surface", Float) = 0
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
            half   _SpecStrength;
            half   _SpecSize;
            half4  _OutlineColor;
            half   _OutlineWidth;
            half   _OutlineScreen;
            half   _Cull;
            half   _Surface;
        CBUFFER_END
        ENDHLSL

        // ---------------------------------------------------------------------
        //  PASS 1 — Outline (inverted hull). Vẽ TRƯỚC, Cull Front.
        // ---------------------------------------------------------------------
        Pass
        {
            Name "Outline"
            Tags { "LightMode"="SRPDefaultUnlit" }   // chạy như pass phụ, không phải ForwardLit
            Cull Front
            ZWrite On

            HLSLPROGRAM
            #pragma vertex   outlineVert
            #pragma fragment outlineFrag
            #pragma multi_compile_instancing
            #pragma shader_feature_local _OUTLINE_SCREENSPACE

            #include "../Core/OutlineCommon.hlsl"

            struct AttributesO { float4 positionOS:POSITION; float3 normalOS:NORMAL; STW_VERTEX_INPUT_INSTANCE_ID };
            struct VaryingsO   { float4 positionCS:SV_POSITION; half fogCoord:TEXCOORD0; STW_VERTEX_OUTPUT_STEREO };

            VaryingsO outlineVert(AttributesO IN)
            {
                VaryingsO OUT = (VaryingsO)0;
                STW_SETUP_INSTANCE_VERT(IN, OUT);
                // width: world dùng đơn vị nhỏ (×0.01), screen dùng tỉ lệ màn hình (×0.001)
            #if defined(_OUTLINE_SCREENSPACE)
                OUT.positionCS = STW_OutlineHull_Screen(IN.positionOS.xyz, IN.normalOS, _OutlineWidth * 0.001h);
            #else
                OUT.positionCS = STW_OutlineHull_World(IN.positionOS.xyz, IN.normalOS, _OutlineWidth * 0.01h);
            #endif
                OUT.fogCoord = ComputeFogFactor(OUT.positionCS.z);
                return OUT;
            }

            half4 outlineFrag(VaryingsO IN) : SV_Target
            {
                STW_SETUP_INSTANCE_FRAG(IN);
                half3 c = STW_ApplyFog(_OutlineColor.rgb, IN.fogCoord);
                return half4(c, 1);
            }
            ENDHLSL
        }

        // ---------------------------------------------------------------------
        //  PASS 2 — ForwardLit (toon)
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
            #pragma multi_compile_fog
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer

            #include "../Core/StylizedLighting.hlsl"
            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);

            struct Attributes { float4 positionOS:POSITION; float3 normalOS:NORMAL; float2 uv:TEXCOORD0; float2 lightmapUV:TEXCOORD1; STW_VERTEX_INPUT_INSTANCE_ID };
            struct Varyings
            {
                float4 positionCS:SV_POSITION; float2 uv:TEXCOORD0; float3 positionWS:TEXCOORD1;
                float3 normalWS:TEXCOORD2; float4 shadowCoord:TEXCOORD3; half fogCoord:TEXCOORD4;
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
                s.screenUV   = GetNormalizedScreenSpaceUV(IN.positionCS);
                s.smoothness = _SpecSize;
                s.occlusion  = 1.0h;
                s.emission   = half3(0,0,0);

                STWToonParams p;
                p.shadowTint=_ShadowTint.rgb; p.rampSteps=_RampSteps; p.rampSmoothness=_RampSmooth;
                p.shadowThreshold=0.5h; p.specularStrength=_SpecStrength; p.specularSize=_SpecSize;
                p.rimColor=half3(0,0,0); p.rimPower=1.0h; p.rimStrength=0.0h; p.giStrength=_GIStrength;

                half4 shadowMask = half4(1,1,1,1);
                half3 color = STW_ToonLighting(s, p, IN.shadowCoord, shadowMask);
                color = STW_ApplyFog(color, IN.fogCoord);
                return half4(color, baseTex.a * _BaseColor.a);
            }
            ENDHLSL
        }

        // ---------------------------------------------------------------------
        //  PASS 3 — ShadowCaster
        // ---------------------------------------------------------------------
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode"="ShadowCaster" }
            ZWrite On ZTest LEqual ColorMask 0 Cull [_Cull]
            HLSLPROGRAM
            #pragma vertex shadowVert
            #pragma fragment shadowFrag
            #pragma multi_compile_instancing
            #pragma multi_compile _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            float3 _LightDirection; float3 _LightPosition;
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
                VaryingsS OUT=(VaryingsS)0; STW_SETUP_INSTANCE_VERT(IN, OUT);
                VertexPositionInputs pos=GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs   nrm=GetVertexNormalInputs(IN.normalOS);
                OUT.positionCS=GetShadowPositionCS(pos.positionWS, nrm.normalWS); return OUT;
            }
            half4 shadowFrag(VaryingsS IN):SV_Target { return 0; }
            ENDHLSL
        }

        // ---------------------------------------------------------------------
        //  PASS 4 — DepthNormals
        // ---------------------------------------------------------------------
        Pass
        {
            Name "DepthNormals"
            Tags { "LightMode"="DepthNormals" }
            ZWrite On Cull [_Cull]
            HLSLPROGRAM
            #pragma vertex dnVert
            #pragma fragment dnFrag
            #pragma multi_compile_instancing
            struct AttributesDN { float4 positionOS:POSITION; float3 normalOS:NORMAL; STW_VERTEX_INPUT_INSTANCE_ID };
            struct VaryingsDN   { float4 positionCS:SV_POSITION; float3 normalWS:TEXCOORD0; STW_VERTEX_OUTPUT_STEREO };
            VaryingsDN dnVert(AttributesDN IN)
            {
                VaryingsDN OUT=(VaryingsDN)0; STW_SETUP_INSTANCE_VERT(IN, OUT);
                VertexPositionInputs pos=GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs   nrm=GetVertexNormalInputs(IN.normalOS);
                OUT.positionCS=pos.positionCS; OUT.normalWS=nrm.normalWS; return OUT;
            }
            half4 dnFrag(VaryingsDN IN):SV_Target
            {
                STW_SETUP_INSTANCE_FRAG(IN);
                float3 n=NormalizeNormalPerPixel(IN.normalWS);
                return half4(n*0.5+0.5, 0);
            }
            ENDHLSL
        }
    }

    FallBack "Universal Render Pipeline/Lit"
    CustomEditor "StylizedToonWorldKit.Editor.OutlineInvertedHullGUI"
}
