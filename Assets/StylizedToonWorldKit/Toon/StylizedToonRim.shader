// =============================================================================
//  StylizedToonRim.shader  —  Stylized Toon World Kit / P1
// -----------------------------------------------------------------------------
//  Toon lit + RIM/FRESNEL nâng cao (viền phát sáng): gradient 2 màu theo fresnel,
//  tuỳ chọn "align" rim về phía nguồn sáng (rim mặt sáng đậm hơn — kiểu anime),
//  cộng additive để loé. Fresnel math trỏ P0 (STW_Fresnel). Hợp nhân vật/sci-fi.
//  PERF: 1 draw, SRP Batcher + instancing + VR SPI. Target URP 17 / Unity 6.
// =============================================================================
Shader "StylizedToonWorldKit/Toon/Toon Rim"
{
    Properties
    {
        [MainTexture] _BaseMap   ("Base Map", 2D) = "white" {}
        [MainColor]   _BaseColor ("Base Color", Color) = (1,1,1,1)
        _ShadowTint  ("Shadow Tint", Color) = (0.45,0.5,0.6,1)
        _RampSteps   ("Cel Steps", Range(1,6)) = 3
        _RampSmooth  ("Ramp Softness", Range(0,1)) = 0.05
        _GIStrength  ("GI Strength", Range(0,2)) = 1.0

        [HDR] _RimColor    ("Rim Color (inner)", Color) = (1,1,1,1)
        [HDR] _RimColorOut ("Rim Color (outer)", Color) = (0.4,0.7,1,1)
        _RimPower    ("Rim Power", Range(0.5,8)) = 3
        _RimStrength ("Rim Strength", Range(0,4)) = 1.5
        [Toggle(_RIM_ALIGN)] _RimAlign ("Align Rim to Light", Float) = 1
        _RimAlignBias ("Light Align Bias", Range(0,1)) = 0.5

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
            float4 _BaseMap_ST; half4 _BaseColor; half4 _ShadowTint;
            half _RampSteps; half _RampSmooth; half _GIStrength;
            half4 _RimColor; half4 _RimColorOut; half _RimPower; half _RimStrength;
            half _RimAlign; half _RimAlignBias; half _Cull; half _Surface; half _ZTest; half _ZWrite;
        CBUFFER_END
        ENDHLSL

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }
            Cull   [_Cull]
            ZTest  [_ZTest]
            ZWrite [_ZWrite]
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0
            #pragma shader_feature_local _RIM_ALIGN
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
            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);

            struct Attributes { float4 positionOS:POSITION; float3 normalOS:NORMAL; float2 uv:TEXCOORD0; float2 lightmapUV:TEXCOORD1; STW_VERTEX_INPUT_INSTANCE_ID };
            struct Varyings { float4 positionCS:SV_POSITION; float2 uv:TEXCOORD0; float3 positionWS:TEXCOORD1; float3 normalWS:TEXCOORD2; float4 shadowCoord:TEXCOORD3; half fogCoord:TEXCOORD4; DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 5); STW_VERTEX_OUTPUT_STEREO };

            Varyings vert(Attributes IN)
            {
                Varyings OUT=(Varyings)0; STW_SETUP_INSTANCE_VERT(IN, OUT);
                VertexPositionInputs pos=GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs   nrm=GetVertexNormalInputs(IN.normalOS);
                OUT.positionCS=pos.positionCS; OUT.positionWS=pos.positionWS; OUT.normalWS=nrm.normalWS;
                OUT.uv=TRANSFORM_TEX(IN.uv,_BaseMap);
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
                half3 n=STW_SafeNormalize(IN.normalWS);
                half3 v=STW_SafeNormalize(GetWorldSpaceViewDir(IN.positionWS));

                STWToonSurface s;
                s.albedo=baseTex.rgb*_BaseColor.rgb; s.normalWS=n; s.viewDirWS=v;
                s.positionWS=IN.positionWS; s.screenUV=GetNormalizedScreenSpaceUV(IN.positionCS);
                s.smoothness=0.2h; s.occlusion=1.0h; s.emission=half3(0,0,0);
                STWToonParams p;
                p.shadowTint=_ShadowTint.rgb; p.rampSteps=_RampSteps; p.rampSmoothness=_RampSmooth;
                p.shadowThreshold=0.5h; p.specularStrength=0.0h; p.specularSize=0.2h;
                p.rimColor=half3(0,0,0); p.rimPower=1.0h; p.rimStrength=0.0h; p.giStrength=_GIStrength;

                half4 shadowMask=half4(1,1,1,1);
                half3 color=STW_ToonLighting(s, p, IN.shadowCoord, shadowMask);

                // --- RIM nâng cao ---
                half fres=STW_Fresnel(n, v, _RimPower);
                half3 rimCol=lerp(_RimColorOut.rgb, _RimColor.rgb, fres); // outer→inner theo fresnel
            #if defined(_RIM_ALIGN)
                Light ml=STW_GetMainLight(IN.shadowCoord, IN.positionWS, shadowMask);
                half align=saturate(dot(n, ml.direction) * 0.5h + 0.5h);   // mặt hướng sáng = 1
                fres *= lerp(1.0h, align, _RimAlignBias);
            #endif
                color += rimCol * fres * _RimStrength;

                color=STW_ApplyFog(color, IN.fogCoord);
                return half4(color, baseTex.a*_BaseColor.a);
            }
            ENDHLSL
        }

        // ShadowCaster + DepthNormals (chuẩn kit)
        Pass
        {
            Name "ShadowCaster" Tags { "LightMode"="ShadowCaster" }
            ZWrite On ZTest LEqual ColorMask 0 Cull [_Cull]
            HLSLPROGRAM
            #pragma vertex sv
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
        Pass
        {
            Name "DepthNormals" Tags { "LightMode"="DepthNormals" }
            ZWrite On Cull [_Cull]
            HLSLPROGRAM
            #pragma vertex dv
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
    CustomEditor "StylizedToonWorldKit.Editor.ToonRimGUI"
}
