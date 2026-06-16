// =============================================================================
//  StylizedGlass.shader  —  Stylized Toon World Kit / P4 Surface
// -----------------------------------------------------------------------------
//  KÍNH stylized trong/mờ (transparent):
//    • Refraction: lệch UV scene-color theo normal view-space (cần Opaque Texture).
//    • Frosted: blur 5-tap scene + jitter noise → kính mờ; trộn theo _FrostAmount.
//    • Tint nhuộm màu + fresnel viền HDR + toon specular bậc.
//    • Tuỳ chọn normal map cho bề mặt gợn (keyword _NORMALMAP).
//  Transparent (alpha blend, ZWrite Off). URP 17 / Unity 6 · SRP Batcher · VR SPI.
//  ⚠️ Bật URP Opaque Texture (refraction/frost).
// =============================================================================
Shader "StylizedToonWorldKit/Surface/Glass"
{
    Properties
    {
        [Header(Body)][Space(4)]
        [HDR] _TintColor   ("Tint Color", Color) = (0.85,0.95,1,0.4)

        [Header(Refraction)][Space(4)]
        _RefractStrength   ("Refraction Strength", Range(0,1)) = 0.12
        [Toggle(_NORMALMAP)] _NormalMapToggle ("Use Normal Map", Float) = 0
        [Normal] _BumpMap  ("Normal Map", 2D) = "bump" {}
        _BumpScale         ("Normal Scale", Range(0,2)) = 1

        [Header(Frosted)][Space(4)]
        [Toggle(_FROSTED)] _FrostedToggle ("Enable Frosted", Float) = 0
        _FrostAmount   ("Frost Blur Amount", Range(0,0.05)) = 0.012
        _FrostJitter   ("Frost Jitter", Range(0,1)) = 0.3
        _FrostNoiseScale ("Frost Noise Scale", Range(1,80)) = 30

        [Header(Fresnel and Specular)][Space(4)]
        [HDR] _FresnelColor ("Fresnel Color", Color) = (1,1,1,1)
        _FresnelPower      ("Fresnel Power", Range(0.2,8)) = 3
        _FresnelStrength   ("Fresnel Strength", Range(0,3)) = 1
        [HDR] _SpecColor2  ("Specular Color", Color) = (1,1,1,1)
        _SpecStrength      ("Specular Strength", Range(0,4)) = 1
        _SpecSize          ("Specular Size", Range(0,1)) = 0.08

        [Header(Render State)][Space(4)]
        _Alpha             ("Overall Alpha", Range(0,1)) = 1
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
            #pragma shader_feature_local _FROSTED

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fog
            #pragma multi_compile_instancing

            #include "../Core/StylizedLighting.hlsl"
            #include "../Core/StylizedNoise.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half4  _TintColor;
                half   _RefractStrength;
                float4 _BumpMap_ST;
                half   _BumpScale;
                half   _FrostAmount;
                half   _FrostJitter;
                half   _FrostNoiseScale;
                half4  _FresnelColor;
                half   _FresnelPower;
                half   _FresnelStrength;
                half4  _SpecColor2;
                half   _SpecStrength;
                half   _SpecSize;
                half   _Alpha;
                half   _Cull;
            CBUFFER_END

            TEXTURE2D(_BumpMap); SAMPLER(sampler_BumpMap);

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

            // Blur 5-tap scene color cho hiệu ứng frosted.
            half3 SceneBlur(float2 uv, half radius)
            {
                half3 c = SampleSceneColor(uv);
                c += SampleSceneColor(uv + float2(radius, 0));
                c += SampleSceneColor(uv - float2(radius, 0));
                c += SampleSceneColor(uv + float2(0, radius));
                c += SampleSceneColor(uv - float2(0, radius));
                return c * 0.2h;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                STW_SETUP_INSTANCE_FRAG(IN);

                // --- normal (tuỳ chọn map) ---
                half3 normalWS = STW_SafeNormalize(IN.normalWS);
            #if defined(_NORMALMAP)
                half3 nTS = UnpackNormalScale(
                    SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, TRANSFORM_TEX(IN.uv, _BumpMap)), _BumpScale);
                half3 bitangent = IN.tangentWS.w * cross(normalWS, IN.tangentWS.xyz);
                half3x3 tbn = half3x3(IN.tangentWS.xyz, bitangent, normalWS);
                normalWS = STW_SafeNormalize(mul(nTS, tbn));
            #endif
                half3 viewDirWS = STW_SafeNormalize(GetWorldSpaceViewDir(IN.positionWS));

                // --- refraction ---
                half3 normalVS = STW_SafeNormalize(TransformWorldToViewDir(normalWS, true));
                float2 baseUV  = IN.screenPos.xy / max(STW_EPSILON, IN.screenPos.w);
                float2 refrUV  = baseUV + normalVS.xy * _RefractStrength * 0.1;

            #if defined(_FROSTED)
                // jitter UV bằng noise + blur → kính mờ
                half jit = (STW_GradientNoise(IN.uv * _FrostNoiseScale) - 0.5h) * _FrostJitter * 0.02h;
                half3 scene = SceneBlur(refrUV + jit, _FrostAmount);
            #else
                half3 scene = SampleSceneColor(refrUV);
            #endif

                half3 color = scene * _TintColor.rgb;

                // --- toon specular + fresnel ---
                float4 shadowCoord = TransformWorldToShadowCoord(IN.positionWS);
                half4 sm = half4(1,1,1,1);
                Light ml = STW_GetMainLight(shadowCoord, IN.positionWS, sm);
                half spec = STW_ToonSpecular(normalWS, ml.direction, viewDirWS, _SpecSize);
                color += spec * _SpecStrength * _SpecColor2.rgb * ml.color;

                half fres = STW_Fresnel(normalWS, viewDirWS, _FresnelPower);
                color += fres * _FresnelStrength * _FresnelColor.rgb;

                half alpha = saturate(_TintColor.a + fres * _FresnelStrength) * _Alpha;

                color = STW_ApplyFog(color, IN.fogCoord);
                return half4(color, alpha);
            }
            ENDHLSL
        }
    }

    FallBack Off
    CustomEditor "StylizedToonWorldKit.Editor.GlassGUI"
}
