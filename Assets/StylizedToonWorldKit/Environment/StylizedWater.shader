// =============================================================================
//  StylizedWater.shader  —  Stylized Toon World Kit / P2 Environment
// -----------------------------------------------------------------------------
//  NƯỚC TĨNH (hồ/sông): mặt nước trong suốt stylized.
//    • Gradient độ sâu: màu nông→sâu theo khoảng cách scene (cần Depth Texture).
//    • Foam viền: bọt trắng nơi mặt nước cắt geometry (depth) + noise cuộn.
//    • Flow normal 2 lớp (scroll ngược pha) cho gợn sóng — procedural hoặc normal map.
//    • Toon specular bậc + fresnel phản chiếu chân trời.
//    • Caustic toon (keyword _CAUSTIC) bằng voronoi ở vùng nông.
//  Trong suốt (alpha blend, ZWrite Off). URP 17 / Unity 6 · SRP Batcher · VR SPI.
//  ⚠️ Bật URP Depth Texture (gradient/foam/caustic cần SampleSceneDepth).
// =============================================================================
Shader "StylizedToonWorldKit/Environment/Water"
{
    Properties
    {
        [Header(Depth Color)][Space(4)]
        _ShallowColor ("Shallow Color", Color) = (0.25,0.7,0.85,0.55)
        _DeepColor    ("Deep Color", Color)    = (0.03,0.18,0.35,0.95)
        _DepthRamp    ("Depth Distance", Range(0.05,30)) = 4
        _DepthPower   ("Depth Sharpness", Range(0.2,4)) = 1

        [Header(Foam)][Space(4)]
        _FoamColor    ("Foam Color", Color) = (1,1,1,1)
        _FoamDistance ("Foam Edge Distance", Range(0,5)) = 0.5
        _FoamNoiseScale ("Foam Noise Scale", Range(0.1,40)) = 8
        _FoamSpeed    ("Foam Scroll Speed", Range(0,4)) = 0.4
        _FoamCutoff   ("Foam Cutoff", Range(0,1)) = 0.45

        [Header(Surface Waves)][Space(4)]
        [Toggle(_NORMALMAP)] _NormalMapToggle ("Use Normal Map", Float) = 0
        [Normal] _NormalMap ("Normal Map", 2D) = "bump" {}
        _NormalScale  ("Normal Scale", Range(0,2)) = 0.5
        _WaveScale    ("Wave Scale", Range(0.1,20)) = 3
        _FlowDir      ("Flow Direction (xy)", Vector) = (1,0.3,0,0)
        _FlowSpeed    ("Flow Speed", Range(0,2)) = 0.25

        [Header(Lighting)][Space(4)]
        _ShadowTint   ("Shadow Tint", Color) = (0.1,0.25,0.4,1)
        _RampSteps    ("Cel Steps", Range(1,6)) = 2
        _RampSmooth   ("Ramp Softness", Range(0,1)) = 0.2
        _GIStrength   ("GI Strength", Range(0,2)) = 0.8
        [HDR] _SpecColor2 ("Specular Color", Color) = (1,1,1,1)
        _SpecStrength ("Specular Strength", Range(0,4)) = 1.2
        _SpecSize     ("Specular Size", Range(0,1)) = 0.15
        [HDR] _FresnelColor ("Fresnel Color", Color) = (0.6,0.85,1,1)
        _FresnelPower ("Fresnel Power", Range(0.2,8)) = 3
        _FresnelStrength ("Fresnel Strength", Range(0,2)) = 0.6

        [Header(Caustics)][Space(4)]
        [Toggle(_CAUSTIC)] _CausticToggle ("Enable Caustics", Float) = 0
        [HDR] _CausticColor ("Caustic Color", Color) = (0.6,1,1,1)
        _CausticScale ("Caustic Scale", Range(0.5,30)) = 6
        _CausticSpeed ("Caustic Speed", Range(0,3)) = 0.5
        _CausticStrength ("Caustic Strength", Range(0,4)) = 1

        [Header(Render State)][Space(4)]
        _Alpha ("Overall Alpha", Range(0,1)) = 1
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull", Float) = 2
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Transparent" "Queue"="Transparent" "IgnoreProjector"="True" }
        LOD 200

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull [_Cull]

            HLSLPROGRAM
            #pragma vertex   vert
            #pragma fragment frag
            #pragma target 3.0

            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _CAUSTIC

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile _ _CLUSTER_LIGHT_LOOP
            #pragma multi_compile_fog
            #pragma multi_compile_instancing

            #include "../Core/StylizedLighting.hlsl"
            #include "../Core/StylizedSurface.hlsl"
            #include "../Core/StylizedNoise.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half4  _ShallowColor;
                half4  _DeepColor;
                half   _DepthRamp;
                half   _DepthPower;
                half4  _FoamColor;
                half   _FoamDistance;
                half   _FoamNoiseScale;
                half   _FoamSpeed;
                half   _FoamCutoff;
                float4 _NormalMap_ST;
                half   _NormalScale;
                half   _WaveScale;
                float4 _FlowDir;
                half   _FlowSpeed;
                half4  _ShadowTint;
                half   _RampSteps;
                half   _RampSmooth;
                half   _GIStrength;
                half4  _SpecColor2;
                half   _SpecStrength;
                half   _SpecSize;
                half4  _FresnelColor;
                half   _FresnelPower;
                half   _FresnelStrength;
                half4  _CausticColor;
                half   _CausticScale;
                half   _CausticSpeed;
                half   _CausticStrength;
                half   _Alpha;
                half   _Cull;
            CBUFFER_END

            TEXTURE2D(_NormalMap); SAMPLER(sampler_NormalMap);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float4 tangentOS  : TANGENT;
                float2 uv         : TEXCOORD0;
                STW_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                half3  normalWS   : TEXCOORD2;
                half4  tangentWS  : TEXCOORD3;
                float4 screenPos  : TEXCOORD4;
                half   fogCoord   : TEXCOORD5;
                STW_VERTEX_OUTPUT_STEREO
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT = (Varyings)0;
                STW_SETUP_INSTANCE_VERT(IN, OUT);

                VertexPositionInputs pos = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs   nrm = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);

                OUT.positionCS = pos.positionCS;
                OUT.positionWS = pos.positionWS;
                OUT.normalWS   = nrm.normalWS;
                OUT.tangentWS  = half4(nrm.tangentWS, IN.tangentOS.w * GetOddNegativeScale());
                OUT.uv         = IN.uv;
                OUT.screenPos  = ComputeScreenPos(pos.positionCS);
                OUT.fogCoord   = ComputeFogFactor(pos.positionCS.z);
                return OUT;
            }

            // Normal gợn nước: 2 lớp normal map scroll ngược pha, hoặc phẳng.
            half3 WaterNormal(float3 positionWS, half3 geomNormal, half4 tangentWS)
            {
            #if defined(_NORMALMAP)
                float2 baseUV = positionWS.xz * (_WaveScale * 0.05);
                float2 dir = normalize(_FlowDir.xy + half2(0.001,0));
                float t = _Time.y * _FlowSpeed;
                float2 uv0 = baseUV + dir * t;
                float2 uv1 = baseUV * 1.37 - dir * t * 0.73;
                half3 n0 = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, uv0), _NormalScale);
                half3 n1 = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, uv1), _NormalScale);
                half3 nTS = STW_SafeNormalize(half3(n0.xy + n1.xy, n0.z * n1.z));
                half3 bitangent = tangentWS.w * cross(geomNormal, tangentWS.xyz);
                half3x3 tbn = half3x3(tangentWS.xyz, bitangent, geomNormal);
                return STW_SafeNormalize(mul(nTS, tbn));
            #else
                return STW_SafeNormalize(geomNormal);
            #endif
            }

            half4 frag(Varyings IN) : SV_Target
            {
                STW_SETUP_INSTANCE_FRAG(IN);

                // --- depth: khoảng cách mặt nước tới scene phía dưới ---
                float2 suv = STW_ScreenUV(IN.screenPos);
                float sceneEye = LinearEyeDepth(SampleSceneDepth(suv), _ZBufferParams);
                float waterDepth = max(0.0, sceneEye - IN.screenPos.w);

                half depthGrad = pow(saturate(waterDepth / max(STW_EPSILON, _DepthRamp)), _DepthPower);
                half4 waterCol = lerp(_ShallowColor, _DeepColor, depthGrad);

                // --- normal sóng ---
                half3 normalWS = WaterNormal(IN.positionWS, IN.normalWS, IN.tangentWS);

                // --- toon lighting (main light, ramp bậc) ---
                float4 shadowCoord = TransformWorldToShadowCoord(IN.positionWS);
                half4 shadowMask = half4(1,1,1,1);
                Light ml = STW_GetMainLight(shadowCoord, IN.positionWS, shadowMask);
                half atten = ml.shadowAttenuation * ml.distanceAttenuation;
                half ndotl = dot(normalWS, ml.direction);
                half ramp = STW_RampStep(ndotl, _RampSteps, _RampSmooth) * atten;
                half3 lit = lerp(_ShadowTint.rgb, half3(1,1,1), ramp) * ml.color;
                half3 color = waterCol.rgb * lit;

                // GI nhẹ
                color += SampleSH(normalWS) * waterCol.rgb * _GIStrength;

                half3 viewDirWS = STW_SafeNormalize(GetWorldSpaceViewDir(IN.positionWS));

                // --- caustic ở vùng nông ---
            #if defined(_CAUSTIC)
                float2 cuv = IN.positionWS.xz * (_CausticScale * 0.1);
                half caus = STW_Voronoi(cuv, _Time.y * _CausticSpeed);
                caus = pow(1.0h - saturate(caus), 4.0h);
                half shallowMask = 1.0h - depthGrad;
                color += _CausticColor.rgb * caus * _CausticStrength * shallowMask * ramp;
            #endif

                // --- specular toon + fresnel ---
                half spec = STW_ToonSpecular(normalWS, ml.direction, viewDirWS, _SpecSize);
                color += spec * _SpecStrength * _SpecColor2.rgb * ml.color * atten;

                half fres = STW_Fresnel(normalWS, viewDirWS, _FresnelPower);
                color += fres * _FresnelStrength * _FresnelColor.rgb;

                // --- foam viền ---
                half edge = saturate(waterDepth / max(STW_EPSILON, _FoamDistance));
                float2 fuv = IN.positionWS.xz * (_FoamNoiseScale * 0.1) + normalize(_FlowDir.xy) * (_Time.y * _FoamSpeed);
                half fnoise = STW_GradientNoise(fuv);
                half foam = step(edge * (0.6h + fnoise * 0.8h), _FoamCutoff);
                color = lerp(color, _FoamColor.rgb, foam);

                // --- alpha: nông trong, sâu đục; foam đặc ---
                half alpha = lerp(_ShallowColor.a, _DeepColor.a, depthGrad);
                alpha = saturate(max(alpha, foam * _FoamColor.a)) * _Alpha;

                color = STW_ApplyFog(color, IN.fogCoord);
                return half4(color, alpha);
            }
            ENDHLSL
        }
    }

    FallBack Off
    CustomEditor "StylizedToonWorldKit.Editor.WaterGUI"
}
