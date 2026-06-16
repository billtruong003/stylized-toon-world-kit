// =============================================================================
//  AnimeFaceSDF.shader  —  Stylized Toon World Kit / P5 Anime NPR
// -----------------------------------------------------------------------------
//  Bóng mặt MƯỢT theo hướng sáng bằng SDF shadow map (kỹ thuật đặc trưng anime
//  Genshin/Honkai). Normal mặt rất nhiễu → KHÔNG dùng N·L cho bóng; thay vào đó
//  dùng 1 SDF grayscale (vẽ cho ánh sáng từ 1 bên) so với ngưỡng tính từ góc
//  giữa hướng-mặt-trước và hướng sáng → bóng mũi/tóc/cằm trôi mượt khi xoay đèn.
//    • Trục mặt suy ra TỰ ĐỘNG từ transform object: forward=+Z, right=+X.
//      (yêu cầu: mesh mặt quay +Z, không scale lệch.) Mirror UV theo dấu R·L.
//    • Vẫn nhận shadow main-light (attenuation) + GI/SH + rim + emission.
//    • Additional light bỏ qua chủ đích (mặt thường chỉ theo key light) — xem README.
//  PERF: 1 draw, SRP Batcher + instancing + VR SPI. Target URP 17 / Unity 6.
// =============================================================================
Shader "StylizedToonWorldKit/Anime/Face SDF Shadow"
{
    Properties
    {
        [MainTexture] _BaseMap   ("Base Map", 2D) = "white" {}
        [MainColor]   _BaseColor ("Base Color", Color) = (1,1,1,1)

        _SDFShadowMap ("SDF Shadow Map (R, vẽ cho đèn từ trái)", 2D) = "white" {}
        _FaceShadowTint ("Face Shadow Tint", Color) = (0.7,0.6,0.66,1)
        _SDFSoftness ("SDF Edge Softness", Range(0.001,0.3)) = 0.05
        [Toggle(_SDF_FLIP)] _SDFFlip ("Flip SDF Left/Right", Float) = 0

        _GIStrength ("GI Strength", Range(0,2)) = 1.0

        [Toggle(_RIM)] _RimToggle ("Enable Rim", Float) = 0
        [HDR] _RimColor ("Rim Color", Color) = (1,1,1,1)
        _RimPower    ("Rim Power", Range(0.5,8)) = 4
        _RimStrength ("Rim Strength", Range(0,2)) = 1.0

        [Toggle(_EMISSION)] _EmissionToggle ("Enable Emission", Float) = 0
        _EmissionMap ("Emission Map", 2D) = "white" {}
        [HDR] _Emission ("Emission Color", Color) = (0,0,0,0)

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
            float4 _SDFShadowMap_ST;
            float4 _EmissionMap_ST;
            half4  _BaseColor;
            half4  _FaceShadowTint;
            half   _SDFSoftness;
            half   _GIStrength;
            half4  _RimColor;
            half   _RimPower;
            half   _RimStrength;
            half4  _Emission;
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
            #pragma shader_feature_local _SDF_FLIP
            #pragma shader_feature_local _RIM
            #pragma shader_feature_local _EMISSION
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile _ LIGHTMAP_ON DYNAMICLIGHTMAP_ON
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile_fog
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer

            #include "../Core/StylizedLighting.hlsl"

            TEXTURE2D(_BaseMap);      SAMPLER(sampler_BaseMap);
            TEXTURE2D(_SDFShadowMap); SAMPLER(sampler_SDFShadowMap);
            TEXTURE2D(_EmissionMap);  SAMPLER(sampler_EmissionMap);

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
                half3 albedo  = baseTex.rgb * _BaseColor.rgb;
                half3 normalWS = STW_SafeNormalize(IN.normalWS);
                half3 viewDirWS = STW_SafeNormalize(GetWorldSpaceViewDir(IN.positionWS));

                half4 shadowMask = half4(1,1,1,1);
                Light ml = STW_GetMainLight(IN.shadowCoord, IN.positionWS, shadowMask);
                half atten = ml.shadowAttenuation * ml.distanceAttenuation;

                // --- Trục mặt từ transform (forward +Z, right +X), chiếu xuống XZ ---
                float3 headForward = TransformObjectToWorldDir(float3(0,0,1));
                float3 headRight   = TransformObjectToWorldDir(float3(1,0,0));
                float2 fwd = normalize(headForward.xz + float2(STW_EPSILON, 0));
                float2 rgt = normalize(headRight.xz   + float2(STW_EPSILON, 0));
                float2 l2  = normalize(ml.direction.xz + float2(STW_EPSILON, 0));

                half FdotL = dot(fwd, l2);   // 1 đèn trước mặt, -1 sau gáy
                half RdotL = dot(rgt, l2);   // dấu = đèn bên trái/phải

                // SDF vẽ cho đèn từ TRÁI → mirror khi đèn sang phải
                float2 sdfUV = IN.uv;
                bool mirror = RdotL < 0.0h;
            #if defined(_SDF_FLIP)
                mirror = !mirror;
            #endif
                if (mirror) sdfUV.x = 1.0 - sdfUV.x;
                half sdf = SAMPLE_TEXTURE2D(_SDFShadowMap, sampler_SDFShadowMap,
                              TRANSFORM_TEX(sdfUV, _SDFShadowMap)).r;

                // ngưỡng: 0 khi đèn trước (không bóng) → 1 khi đèn sau (bóng kín)
                half threshold = 1.0h - (FdotL * 0.5h + 0.5h);
                half lit = smoothstep(threshold - _SDFSoftness, threshold + _SDFSoftness, sdf);
                lit *= atten;

                half3 color = albedo * lerp(_FaceShadowTint.rgb, ml.color, lit);

                // GI / ambient
                color += SampleSH(normalWS) * albedo * _GIStrength;

                // Rim
            #if defined(_RIM)
                half rim = STW_Fresnel(normalWS, viewDirWS, _RimPower);
                color += rim * _RimColor.rgb * _RimStrength * saturate(lit + 0.25h);
            #endif

                // Emission
            #if defined(_EMISSION)
                color += SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap,
                            TRANSFORM_TEX(IN.uv, _EmissionMap)).rgb * _Emission.rgb;
            #endif

                color = STW_ApplyFog(color, IN.fogCoord);
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
            struct A { float4 positionOS:POSITION; float3 normalOS:NORMAL; STW_VERTEX_INPUT_INSTANCE_ID };
            struct V { float4 positionCS:SV_POSITION; STW_VERTEX_OUTPUT_STEREO };
            float4 SP(float3 pWS, float3 nWS)
            {
            #if _CASTING_PUNCTUAL_LIGHT_SHADOW
                float3 d = normalize(_LightPosition - pWS);
            #else
                float3 d = _LightDirection;
            #endif
                float4 cs = TransformWorldToHClip(ApplyShadowBias(pWS, nWS, d));
            #if UNITY_REVERSED_Z
                cs.z = min(cs.z, UNITY_NEAR_CLIP_VALUE);
            #else
                cs.z = max(cs.z, UNITY_NEAR_CLIP_VALUE);
            #endif
                return cs;
            }
            V sv(A IN){ V o=(V)0; STW_SETUP_INSTANCE_VERT(IN,o);
                VertexPositionInputs p=GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs nrm=GetVertexNormalInputs(IN.normalOS);
                o.positionCS=SP(p.positionWS, nrm.normalWS); return o; }
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
            struct A { float4 positionOS:POSITION; float3 normalOS:NORMAL; STW_VERTEX_INPUT_INSTANCE_ID };
            struct V { float4 positionCS:SV_POSITION; float3 normalWS:TEXCOORD0; STW_VERTEX_OUTPUT_STEREO };
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
    CustomEditor "StylizedToonWorldKit.Editor.FaceSDFGUI"
}
