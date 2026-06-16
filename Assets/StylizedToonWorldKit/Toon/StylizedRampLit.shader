// =============================================================================
//  StylizedRampLit.shader  —  Stylized Toon World Kit / P1
// -----------------------------------------------------------------------------
//  Biến thể "Ramp Lit": tô bóng bằng TEXTURE RAMP 1D (artist vẽ gradient màu sáng
//  → tối tuỳ ý) thay vì step cứng — kiểm soát màu shadow theo nghệ thuật. Kèm:
//    • Banded colored shadow theo LUT (mặt tối ấm/lạnh tuỳ ramp).
//    • AO map + AO stylized (posterize) → bóng tiếp xúc kiểu vẽ tay.
//  Ramp math trỏ P0 (STW_RampTexture). Hợp prop/diorama/scene màu mạnh.
//  PERF: 1 draw, SRP Batcher + instancing + VR SPI. Target URP 17 / Unity 6.
// =============================================================================
Shader "StylizedToonWorldKit/Toon/Ramp Lit"
{
    Properties
    {
        [MainTexture] _BaseMap   ("Base Map", 2D) = "white" {}
        [MainColor]   _BaseColor ("Base Color", Color) = (1,1,1,1)
        _RampMap     ("Ramp (1D LUT, dark→light)", 2D) = "white" {}
        _GIStrength  ("GI Strength", Range(0,2)) = 1.0

        _AOMap       ("Occlusion Map (R)", 2D) = "white" {}
        _AOStrength  ("Occlusion Strength", Range(0,1)) = 1.0
        _AOBands     ("Occlusion Bands (0=smooth)", Range(0,6)) = 0

        [HDR] _Emission ("Emission", Color) = (0,0,0,0)

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
            float4 _BaseMap_ST; float4 _AOMap_ST; half4 _BaseColor;
            half _GIStrength; half _AOStrength; half _AOBands; half4 _Emission;
            half _Cull; half _Surface;
        CBUFFER_END
        ENDHLSL

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }
            Cull [_Cull]
            HLSLPROGRAM
            #pragma vertex vert
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
            TEXTURE2D(_RampMap); SAMPLER(sampler_RampMap);
            TEXTURE2D(_AOMap);   SAMPLER(sampler_AOMap);

            struct Attributes { float4 positionOS:POSITION; float3 normalOS:NORMAL; float2 uv:TEXCOORD0; float2 lightmapUV:TEXCOORD1; STW_VERTEX_INPUT_INSTANCE_ID };
            struct Varyings { float4 positionCS:SV_POSITION; float2 uv:TEXCOORD0; float3 positionWS:TEXCOORD1; float3 normalWS:TEXCOORD2; float4 shadowCoord:TEXCOORD3; half fogCoord:TEXCOORD4; DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 5) STW_VERTEX_OUTPUT_STEREO };

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
                half3 albedo=baseTex.rgb*_BaseColor.rgb;
                half3 n=STW_SafeNormalize(IN.normalWS);

                half4 shadowMask=half4(1,1,1,1);

                // --- AO stylized (posterize tuỳ chọn) ---
                half ao=SAMPLE_TEXTURE2D(_AOMap, sampler_AOMap, TRANSFORM_TEX(IN.uv,_AOMap)).r;
                if (_AOBands >= 1.0h) ao = floor(ao * _AOBands + 0.5h) / _AOBands;
                ao = lerp(1.0h, ao, _AOStrength);

                // --- Main light qua RAMP LUT ---
                Light ml=STW_GetMainLight(IN.shadowCoord, IN.positionWS, shadowMask);
                half atten=ml.shadowAttenuation*ml.distanceAttenuation;
                half nl=dot(n, ml.direction) * atten;
                half3 ramp=STW_RampTexture(TEXTURE2D_ARGS(_RampMap, sampler_RampMap), nl);
                half3 color = albedo * ramp * ml.color;

                // --- Additional lights (cũng qua ramp, đồng bộ tông) ---
                uint cnt=STW_GetAdditionalLightsCount();
            #if USE_FORWARD_PLUS
                // Forward+ cluster: macro cần biến tên 'inputData' (screenUV + posWS).
                InputData inputData = (InputData)0;
                inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(IN.positionCS);
                inputData.positionWS = IN.positionWS;
                LIGHT_LOOP_BEGIN(cnt)
                    Light l=GetAdditionalLight(lightIndex, IN.positionWS, shadowMask);
                    half a=l.shadowAttenuation*l.distanceAttenuation;
                    half3 r=STW_RampTexture(TEXTURE2D_ARGS(_RampMap, sampler_RampMap), dot(n,l.direction)*a);
                    color += albedo * r * l.color * a;
                LIGHT_LOOP_END
            #else
                for (uint li=0u; li<cnt; li++){
                    Light l=GetAdditionalLight(li, IN.positionWS, shadowMask);
                    half a=l.shadowAttenuation*l.distanceAttenuation;
                    color += albedo * l.color * saturate(dot(n,l.direction)) * a;
                }
            #endif

                // --- GI + AO + emission ---
                color += SampleSH(n) * albedo * _GIStrength;
                color *= ao;
                color += _Emission.rgb;

                color=STW_ApplyFog(color, IN.fogCoord);
                return half4(color, baseTex.a*_BaseColor.a);
            }
            ENDHLSL
        }

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
    CustomEditor "StylizedToonWorldKit.Editor.RampLitGUI"
}
