// =============================================================================
//  AnimeEye.shader  —  Stylized Toon World Kit / P5 Anime NPR
// -----------------------------------------------------------------------------
//  Mắt anime nhiều lớp: sclera + iris PARALLAX (giả chiều sâu giác mạc) + pupil
//  giãn + limbal ring + corneal highlight phát sáng (không dính bóng).
//    • Parallax iris trỏ P0 (STW_ParallaxOffset) theo view trong tangent-space →
//      iris "lõm" như mắt thật khi đổi góc nhìn.
//    • Pupil/limbal/iris dựng theo bán kính UV quanh tâm (0.5,0.5).
//    • Highlight = đốm sáng procedural (vị trí + cỡ chỉnh được), cộng qua emission.
//    • Toon shading nhẹ (main ramp + GI) trỏ P0 (STW_ToonLighting).
//  Lưu ý: cần mesh CÓ tangent + UV mắt căn tâm (0.5,0.5). Target URP 17 / Unity 6.
// =============================================================================
Shader "StylizedToonWorldKit/Anime/Eye"
{
    Properties
    {
        [MainTexture] _BaseMap   ("Sclera Map", 2D) = "white" {}
        [MainColor]   _BaseColor ("Sclera Color", Color) = (0.95,0.95,0.96,1)

        _IrisMap   ("Iris Map", 2D) = "white" {}
        [HDR] _IrisColor ("Iris Color", Color) = (0.3,0.55,0.8,1)
        _IrisRadius ("Iris Radius", Range(0.05,0.5)) = 0.32
        _IrisDepth  ("Iris Parallax Depth", Range(0,0.3)) = 0.08
        _ParallaxScale ("Parallax Scale", Range(0,2)) = 1.0

        _PupilColor ("Pupil Color", Color) = (0.03,0.03,0.05,1)
        _PupilSize  ("Pupil Size", Range(0.02,0.4)) = 0.12

        _LimbalColor ("Limbal Ring Color", Color) = (0.05,0.06,0.1,1)
        _LimbalWidth ("Limbal Ring Width", Range(0,0.2)) = 0.05

        [HDR] _HighlightColor ("Highlight Color", Color) = (1,1,1,1)
        _HighlightPos  ("Highlight Pos (xy)", Vector) = (0.38,0.62,0,0)
        _HighlightSize ("Highlight Size", Range(0.01,0.25)) = 0.08

        _ShadowTint ("Shadow Tint", Color) = (0.6,0.62,0.7,1)
        _RampSteps  ("Cel Steps", Range(1,4)) = 2
        _RampSmooth ("Ramp Softness", Range(0,1)) = 0.2
        _GIStrength ("GI Strength", Range(0,2)) = 1.2

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
            float4 _IrisMap_ST;
            half4  _BaseColor;
            half4  _IrisColor;
            half   _IrisRadius;
            half   _IrisDepth;
            half   _ParallaxScale;
            half4  _PupilColor;
            half   _PupilSize;
            half4  _LimbalColor;
            half   _LimbalWidth;
            half4  _HighlightColor;
            float4 _HighlightPos;
            half   _HighlightSize;
            half4  _ShadowTint;
            half   _RampSteps;
            half   _RampSmooth;
            half   _GIStrength;
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

            #include "../Core/StylizedSurface.hlsl"
            #include "../Core/StylizedLighting.hlsl"

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            TEXTURE2D(_IrisMap); SAMPLER(sampler_IrisMap);

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
                half3 n=STW_SafeNormalize(IN.normalWS);
                half3 v=STW_SafeNormalize(GetWorldSpaceViewDir(IN.positionWS));

                // TBN → view trong tangent space cho parallax
                half3 T=STW_SafeNormalize(IN.tangentWS.xyz);
                half3 B=IN.tangentWS.w * cross(n, T);
                half3 viewTS = half3(dot(v, T), dot(v, B), dot(v, n));

                // iris UV parallax quanh tâm
                float2 irisUV = STW_ParallaxOffset(IN.uv, _IrisDepth, _ParallaxScale, viewTS);
                half3 irisTex = SAMPLE_TEXTURE2D(_IrisMap, sampler_IrisMap, irisUV).rgb;

                // bán kính từ tâm (0.5,0.5)
                half r = length(IN.uv - 0.5h);

                half3 sclera = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv).rgb * _BaseColor.rgb;
                half3 iris   = irisTex * _IrisColor.rgb;

                // pupil → limbal ring → iris → sclera (mép mềm)
                half irisMask  = 1.0h - smoothstep(_IrisRadius - 0.02h, _IrisRadius + 0.02h, r);
                half pupilMask = 1.0h - smoothstep(_PupilSize - 0.02h, _PupilSize + 0.02h, r);
                half limbal    = smoothstep(_IrisRadius - _LimbalWidth, _IrisRadius, r)
                               * (1.0h - smoothstep(_IrisRadius, _IrisRadius + 0.02h, r));

                half3 eye = lerp(sclera, iris, irisMask);
                eye = lerp(eye, _PupilColor.rgb, pupilMask);
                eye = lerp(eye, _LimbalColor.rgb, limbal);

                // corneal highlight (procedural, phát sáng)
                half hd = length(IN.uv - _HighlightPos.xy);
                half hl = 1.0h - smoothstep(_HighlightSize * 0.6h, _HighlightSize, hd);

                STWToonSurface s;
                s.albedo=eye; s.normalWS=n; s.viewDirWS=v;
                s.positionWS=IN.positionWS; s.screenUV=GetNormalizedScreenSpaceUV(IN.positionCS);
                s.smoothness=0.2h; s.occlusion=1.0h;
                s.emission=hl * _HighlightColor.rgb;
                STWToonParams p;
                p.shadowTint=_ShadowTint.rgb; p.rampSteps=_RampSteps; p.rampSmoothness=_RampSmooth;
                p.shadowThreshold=0.5h; p.specularStrength=0.0h; p.specularSize=0.2h;
                p.rimColor=half3(0,0,0); p.rimPower=1.0h; p.rimStrength=0.0h; p.giStrength=_GIStrength;

                half4 shadowMask=half4(1,1,1,1);
                half3 color=STW_ToonLighting(s, p, IN.shadowCoord, shadowMask);

                color=STW_ApplyFog(color, IN.fogCoord);
                return half4(color, 1.0h);
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
    CustomEditor "StylizedToonWorldKit.Editor.AnimeEyeGUI"
}
