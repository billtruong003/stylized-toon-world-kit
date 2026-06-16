// =============================================================================
//  AnimeSkinSSS.shader  —  Stylized Toon World Kit / P5 Anime NPR
// -----------------------------------------------------------------------------
//  Da stylized với subsurface GIẢ + blush ramp:
//    • Colored banded shadow = màu SSS (đỏ/cam ấm) thay vì xám → da "trong".
//    • Terminator scatter: dải ửng đỏ tại mép sáng/tối (saturate(1-|N·L|/width))
//      mô phỏng ánh sáng tán xạ dưới da — đặc trưng skin NPR.
//    • Blush map (keyword _BLUSH): tô má hồng theo mask, cường độ chỉnh được.
//    • Sheen specular nhẹ + normal map + rim. Toon base trỏ P0 (STW_ToonLighting).
//  PERF: 1 draw, SRP Batcher + instancing + VR SPI. Target URP 17 / Unity 6.
// =============================================================================
Shader "StylizedToonWorldKit/Anime/Skin SSS"
{
    Properties
    {
        [MainTexture] _BaseMap   ("Base Map", 2D) = "white" {}
        [MainColor]   _BaseColor ("Base Color", Color) = (1,0.85,0.78,1)

        [Toggle(_NORMALMAP)] _NormalMapToggle ("Enable Normal Map", Float) = 0
        [Normal] _BumpMap ("Normal Map", 2D) = "bump" {}
        _BumpScale ("Normal Scale", Range(0,2)) = 1

        _RampSteps  ("Cel Steps", Range(1,5)) = 2
        _RampSmooth ("Ramp Softness", Range(0,1)) = 0.25
        _GIStrength ("GI Strength", Range(0,2)) = 1.0
        _Occlusion  ("Occlusion", Range(0,1)) = 1.0

        // Subsurface
        [HDR] _SSSColor ("SSS / Shadow Color", Color) = (0.85,0.45,0.4,1)
        _SSSStrength ("Scatter Strength", Range(0,2)) = 0.6
        _ScatterWidth ("Scatter Terminator Width", Range(0.01,1)) = 0.35

        // Blush
        [Toggle(_BLUSH)] _BlushToggle ("Enable Blush", Float) = 0
        _BlushMap ("Blush Mask (R)", 2D) = "black" {}
        _BlushColor ("Blush Color", Color) = (0.95,0.4,0.45,1)
        _BlushStrength ("Blush Strength", Range(0,1)) = 0.5

        // Sheen
        [HDR] _SpecColor2 ("Sheen Color", Color) = (1,1,1,1)
        _SpecStrength ("Sheen Strength", Range(0,1)) = 0.0
        _SpecSize     ("Sheen Size", Range(0,1)) = 0.4

        // Rim
        [Toggle(_RIM)] _RimToggle ("Enable Rim", Float) = 0
        [HDR] _RimColor ("Rim Color", Color) = (1,1,1,1)
        _RimPower    ("Rim Power", Range(0.5,8)) = 4
        _RimStrength ("Rim Strength", Range(0,2)) = 0.5

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
            float4 _BumpMap_ST;
            float4 _BlushMap_ST;
            half4  _BaseColor;
            half   _BumpScale;
            half   _RampSteps;
            half   _RampSmooth;
            half   _GIStrength;
            half   _Occlusion;
            half4  _SSSColor;
            half   _SSSStrength;
            half   _ScatterWidth;
            half4  _BlushColor;
            half   _BlushStrength;
            half4  _SpecColor2;
            half   _SpecStrength;
            half   _SpecSize;
            half4  _RimColor;
            half   _RimPower;
            half   _RimStrength;
            half   _Cull;
            half   _Surface;
        CBUFFER_END
        ENDHLSL

        // -- PASS 1: ForwardLit ------------------------------------------------
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }
            Cull [_Cull]
            HLSLPROGRAM
            #pragma vertex   vert
            #pragma fragment frag
            #pragma target 3.0
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _BLUSH
            #pragma shader_feature_local _RIM
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

            TEXTURE2D(_BaseMap);  SAMPLER(sampler_BaseMap);
            TEXTURE2D(_BumpMap);  SAMPLER(sampler_BumpMap);
            TEXTURE2D(_BlushMap); SAMPLER(sampler_BlushMap);

            struct Attributes { float4 positionOS:POSITION; float3 normalOS:NORMAL; float4 tangentOS:TANGENT; float2 uv:TEXCOORD0; float2 lightmapUV:TEXCOORD1; STW_VERTEX_INPUT_INSTANCE_ID };
            struct Varyings { float4 positionCS:SV_POSITION; float2 uv:TEXCOORD0; float3 positionWS:TEXCOORD1; float3 normalWS:TEXCOORD2; float4 tangentWS:TEXCOORD3; float4 shadowCoord:TEXCOORD4; half fogCoord:TEXCOORD5; DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 6) STW_VERTEX_OUTPUT_STEREO };

            Varyings vert(Attributes IN)
            {
                Varyings OUT=(Varyings)0; STW_SETUP_INSTANCE_VERT(IN, OUT);
                VertexPositionInputs pos=GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs   nrm=GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
                OUT.positionCS=pos.positionCS; OUT.positionWS=pos.positionWS;
                OUT.normalWS=nrm.normalWS;
                OUT.tangentWS=float4(nrm.tangentWS, IN.tangentOS.w * GetOddNegativeScale());
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

                half3 normalWS=STW_SafeNormalize(IN.normalWS);
            #if defined(_NORMALMAP)
                half3 nTS=UnpackNormalScale(
                    SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, TRANSFORM_TEX(IN.uv,_BumpMap)), _BumpScale);
                half3 bitangent=IN.tangentWS.w * cross(normalWS, IN.tangentWS.xyz);
                half3x3 tbn=half3x3(IN.tangentWS.xyz, bitangent, normalWS);
                normalWS=STW_SafeNormalize(mul(nTS, tbn));
            #endif

                // Blush: tô má hồng theo mask
            #if defined(_BLUSH)
                half blush=SAMPLE_TEXTURE2D(_BlushMap, sampler_BlushMap, TRANSFORM_TEX(IN.uv,_BlushMap)).r;
                albedo=lerp(albedo, _BlushColor.rgb, blush * _BlushStrength);
            #endif

                half3 v=STW_SafeNormalize(GetWorldSpaceViewDir(IN.positionWS));

                STWToonSurface s;
                s.albedo=albedo; s.normalWS=normalWS; s.viewDirWS=v;
                s.positionWS=IN.positionWS; s.screenUV=GetNormalizedScreenSpaceUV(IN.positionCS);
                s.smoothness=_SpecSize; s.occlusion=_Occlusion; s.emission=half3(0,0,0);
                STWToonParams p;
                p.shadowTint=_SSSColor.rgb; p.rampSteps=_RampSteps; p.rampSmoothness=_RampSmooth;
                p.shadowThreshold=0.5h; p.specularStrength=0.0h; p.specularSize=_SpecSize;
            #if defined(_RIM)
                p.rimColor=_RimColor.rgb; p.rimPower=_RimPower; p.rimStrength=_RimStrength;
            #else
                p.rimColor=half3(0,0,0); p.rimPower=1.0h; p.rimStrength=0.0h;
            #endif
                p.giStrength=_GIStrength;

                half4 shadowMask=half4(1,1,1,1);
                half3 color=STW_ToonLighting(s, p, IN.shadowCoord, shadowMask);

                // --- Terminator scatter + sheen (main light) ---
                Light ml=STW_GetMainLight(IN.shadowCoord, IN.positionWS, shadowMask);
                half atten=ml.shadowAttenuation*ml.distanceAttenuation;
                half ndotl=dot(normalWS, ml.direction);
                half scatter=saturate(1.0h - abs(ndotl) / max(STW_EPSILON, _ScatterWidth));
                color += scatter * _SSSColor.rgb * _SSSStrength * albedo * ml.color * atten;

                if (_SpecStrength > 0.0h)
                {
                    half sheen=STW_ToonSpecular(normalWS, ml.direction, v, _SpecSize);
                    color += sheen * _SpecStrength * _SpecColor2.rgb * ml.color * atten;
                }

                color=STW_ApplyFog(color, IN.fogCoord);
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
            #pragma shader_feature_local _NORMALMAP
            TEXTURE2D(_BumpMap); SAMPLER(sampler_BumpMap);
            struct A{float4 positionOS:POSITION;float3 normalOS:NORMAL;float4 tangentOS:TANGENT;float2 uv:TEXCOORD0;STW_VERTEX_INPUT_INSTANCE_ID};
            struct V{float4 positionCS:SV_POSITION;float3 normalWS:TEXCOORD0;float2 uv:TEXCOORD1;STW_VERTEX_OUTPUT_STEREO};
            V dv(A IN){ V o=(V)0; STW_SETUP_INSTANCE_VERT(IN,o);
                VertexPositionInputs p=GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs nrm=GetVertexNormalInputs(IN.normalOS);
                o.positionCS=p.positionCS; o.normalWS=nrm.normalWS; o.uv=TRANSFORM_TEX(IN.uv,_BumpMap); return o; }
            half4 df(V IN):SV_Target { STW_SETUP_INSTANCE_FRAG(IN);
                float3 n=NormalizeNormalPerPixel(IN.normalWS); return half4(n*0.5+0.5,0); }
            ENDHLSL
        }
    }
    FallBack "Universal Render Pipeline/Lit"
    CustomEditor "StylizedToonWorldKit.Editor.AnimeSkinGUI"
}
