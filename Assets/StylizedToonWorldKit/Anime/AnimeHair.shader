// =============================================================================
//  AnimeHair.shader  —  Stylized Toon World Kit / P5 Anime NPR
// -----------------------------------------------------------------------------
//  Tóc anime NPR (nâng cấp P1 HairAniso cho nhân vật): cel toon base + 2 dải
//  anisotropic (Kajiya-Kay) dịch theo shift map, highlight TÔ theo base color
//  (anime hay nhuộm highlight cùng tông tóc) + dải bóng view-dependent + rim.
//    • Toon base + GI + add-light Forward+ trỏ P0 (STW_ToonLighting).
//    • Aniso math trỏ P0 (STW_AnisoSpecular) — không lặp.
//    • _HighlightTintBlend: pha màu highlight về base (0 = màu thuần, 1 = base).
//    • Cần mesh CÓ tangent (UV chải dọc sợi) để highlight chạy đúng.
//  PERF: 1 draw, SRP Batcher + instancing + VR SPI. Target URP 17 / Unity 6.
// =============================================================================
Shader "StylizedToonWorldKit/Anime/Hair"
{
    Properties
    {
        [MainTexture] _BaseMap   ("Base Map", 2D) = "white" {}
        [MainColor]   _BaseColor ("Base Color", Color) = (0.45,0.3,0.5,1)
        _ShadowTint  ("Shadow Tint", Color) = (0.3,0.22,0.34,1)
        _RampSteps   ("Cel Steps", Range(1,6)) = 2
        _RampSmooth  ("Ramp Softness", Range(0,1)) = 0.08
        _GIStrength  ("GI Strength", Range(0,2)) = 1.0

        _ShiftMap ("Shift Map (R = noise)", 2D) = "gray" {}
        _ShiftStrength ("Shift Map Strength", Range(0,1)) = 0.3
        [HDR] _SpecColor1 ("Primary Highlight", Color) = (1,0.95,0.9,1)
        _SpecShift1 ("Primary Shift", Range(-1,1)) = 0.0
        _SpecExp1   ("Primary Sharpness", Range(1,256)) = 90
        [HDR] _SpecColor2 ("Secondary Highlight", Color) = (0.7,0.6,0.7,1)
        _SpecShift2 ("Secondary Shift", Range(-1,1)) = 0.35
        _SpecExp2   ("Secondary Sharpness", Range(1,256)) = 30
        _HighlightTintBlend ("Highlight Tint→Base", Range(0,1)) = 0.4

        [Toggle(_RIM)] _RimToggle ("Enable Rim", Float) = 1
        [HDR] _RimColor ("Rim Color", Color) = (1,1,1,1)
        _RimPower    ("Rim Power", Range(0.5,8)) = 5
        _RimStrength ("Rim Strength", Range(0,2)) = 0.6

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
            float4 _ShiftMap_ST;
            half4  _BaseColor;
            half4  _ShadowTint;
            half   _RampSteps;
            half   _RampSmooth;
            half   _GIStrength;
            half   _ShiftStrength;
            half4  _SpecColor1;
            half   _SpecShift1;
            half   _SpecExp1;
            half4  _SpecColor2;
            half   _SpecShift2;
            half   _SpecExp2;
            half   _HighlightTintBlend;
            half4  _RimColor;
            half   _RimPower;
            half   _RimStrength;
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
            #pragma shader_feature_local _RIM
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

            #include "../Core/StylizedLighting.hlsl"

            TEXTURE2D(_BaseMap);  SAMPLER(sampler_BaseMap);
            TEXTURE2D(_ShiftMap); SAMPLER(sampler_ShiftMap);

            struct Attributes { float4 positionOS:POSITION; float3 normalOS:NORMAL; float4 tangentOS:TANGENT; float2 uv:TEXCOORD0; float2 lightmapUV:TEXCOORD1; STW_VERTEX_INPUT_INSTANCE_ID };
            struct Varyings { float4 positionCS:SV_POSITION; float2 uv:TEXCOORD0; float3 positionWS:TEXCOORD1; float3 normalWS:TEXCOORD2; float3 tangentWS:TEXCOORD3; float4 shadowCoord:TEXCOORD4; half fogCoord:TEXCOORD5; DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 6); STW_VERTEX_OUTPUT_STEREO };

            // 1 dải aniso bậc-mềm (Kajiya-Kay) trỏ P0.
            half hairBand(half3 tangentWS, half3 lightDir, half3 viewDir, half shift, half exp)
            {
                half a = STW_AnisoSpecular(tangentWS, lightDir, viewDir, shift, exp);
                return smoothstep(0.35h, 0.5h, a);
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT=(Varyings)0; STW_SETUP_INSTANCE_VERT(IN, OUT);
                VertexPositionInputs pos=GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs   nrm=GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
                OUT.positionCS=pos.positionCS; OUT.positionWS=pos.positionWS;
                OUT.normalWS=nrm.normalWS; OUT.tangentWS=nrm.tangentWS;
                OUT.uv=TRANSFORM_TEX(IN.uv, _BaseMap);
                OUT.shadowCoord=STW_GetShadowCoord(pos.positionWS, pos.positionCS);
                OUT.fogCoord=ComputeFogFactor(pos.positionCS.z);
                OUTPUT_LIGHTMAP_UV(IN.lightmapUV, unity_LightmapST, OUT.lightmapUV);
                OUTPUT_SH(OUT.normalWS, OUT.vertexSH);
                return OUT;
            }

            half4 frag(Varyings IN):SV_Target
            {
                STW_SETUP_INSTANCE_FRAG(IN);
                half4 baseTex=SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);
                half3 albedo = baseTex.rgb * _BaseColor.rgb;
                half3 n=STW_SafeNormalize(IN.normalWS);
                half3 v=STW_SafeNormalize(GetWorldSpaceViewDir(IN.positionWS));

                STWToonSurface s;
                s.albedo=albedo; s.normalWS=n; s.viewDirWS=v;
                s.positionWS=IN.positionWS; s.screenUV=GetNormalizedScreenSpaceUV(IN.positionCS);
                s.smoothness=0.5h; s.occlusion=1.0h; s.emission=half3(0,0,0);
                STWToonParams p;
                p.shadowTint=_ShadowTint.rgb; p.rampSteps=_RampSteps; p.rampSmoothness=_RampSmooth;
                p.shadowThreshold=0.5h; p.specularStrength=0.0h; p.specularSize=0.2h;
            #if defined(_RIM)
                p.rimColor=_RimColor.rgb; p.rimPower=_RimPower; p.rimStrength=_RimStrength;
            #else
                p.rimColor=half3(0,0,0); p.rimPower=1.0h; p.rimStrength=0.0h;
            #endif
                p.giStrength=_GIStrength;

                half4 shadowMask=half4(1,1,1,1);
                half3 color=STW_ToonLighting(s, p, IN.shadowCoord, shadowMask);

                // --- Dual anisotropic highlight, tô về base color ---
                Light ml=STW_GetMainLight(IN.shadowCoord, IN.positionWS, shadowMask);
                half atten=ml.shadowAttenuation*ml.distanceAttenuation;
                half noise=(SAMPLE_TEXTURE2D(_ShiftMap, sampler_ShiftMap, TRANSFORM_TEX(IN.uv,_ShiftMap)).r - 0.5h) * _ShiftStrength;
                half3 t=STW_SafeNormalize(IN.tangentWS);
                half b1=hairBand(t, ml.direction, v, _SpecShift1 + noise, _SpecExp1);
                half b2=hairBand(t, ml.direction, v, _SpecShift2 + noise, _SpecExp2);
                half3 hi1=lerp(_SpecColor1.rgb, _SpecColor1.rgb * albedo, _HighlightTintBlend) * b1;
                half3 hi2=lerp(_SpecColor2.rgb, _SpecColor2.rgb * albedo, _HighlightTintBlend) * b2;
                color += (hi1 + hi2) * ml.color * atten;

                color=STW_ApplyFog(color, IN.fogCoord);
                return half4(color, baseTex.a*_BaseColor.a);
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
            struct A{float4 positionOS:POSITION;float3 normalOS:NORMAL;STW_VERTEX_INPUT_INSTANCE_ID};
            struct V{float4 positionCS:SV_POSITION;STW_VERTEX_OUTPUT_STEREO};
            float4 SP(float3 pWS,float3 nWS){
            #if _CASTING_PUNCTUAL_LIGHT_SHADOW
                float3 d=normalize(_LightPosition-pWS);
            #else
                float3 d=_LightDirection;
            #endif
                float4 cs=TransformWorldToHClip(ApplyShadowBias(pWS,nWS,d));
            #if UNITY_REVERSED_Z
                cs.z=min(cs.z,UNITY_NEAR_CLIP_VALUE);
            #else
                cs.z=max(cs.z,UNITY_NEAR_CLIP_VALUE);
            #endif
                return cs; }
            V sv(A IN){ V o=(V)0; STW_SETUP_INSTANCE_VERT(IN,o);
                VertexPositionInputs p=GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs nrm=GetVertexNormalInputs(IN.normalOS);
                o.positionCS=SP(p.positionWS,nrm.normalWS); return o; }
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
            struct A{float4 positionOS:POSITION;float3 normalOS:NORMAL;STW_VERTEX_INPUT_INSTANCE_ID};
            struct V{float4 positionCS:SV_POSITION;float3 normalWS:TEXCOORD0;STW_VERTEX_OUTPUT_STEREO};
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
    CustomEditor "StylizedToonWorldKit.Editor.AnimeHairGUI"
}
