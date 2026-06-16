// =============================================================================
//  StylizedCrystal.shader  —  Stylized Toon World Kit / P4 Surface
// -----------------------------------------------------------------------------
//  PHA LÊ / ĐÁ QUÝ trong suốt stylized:
//    • Fake refraction: lệch UV scene-color theo normal view-space (cần URP
//      Opaque Texture) — không cần render target phụ.
//    • Dispersion: tách R/G/B theo offset khác nhau → viền cầu vồng ở mép.
//    • Inner glow: lõi sáng theo nghịch-fresnel (dày = sáng) + facet noise.
//    • Fresnel viền HDR + toon specular bậc cho lấp lánh.
//    • Depth fade mềm mép giao geometry (cần Depth Texture).
//  Trong suốt (alpha blend, ZWrite Off). URP 17 / Unity 6 · SRP Batcher · VR SPI.
//  ⚠️ Bật URP Opaque Texture + Depth Texture (refraction/dispersion/depth-fade).
// =============================================================================
Shader "StylizedToonWorldKit/Surface/Crystal"
{
    Properties
    {
        [Header(Body)][Space(4)]
        [HDR] _BaseColor   ("Tint Color", Color) = (0.55,0.8,1,0.6)
        _Saturation        ("Refraction Saturation", Range(0,2)) = 1

        [Header(Refraction)][Space(4)]
        _RefractStrength   ("Refraction Strength", Range(0,1)) = 0.25
        [Toggle(_DISPERSION)] _DispersionToggle ("Enable Dispersion", Float) = 1
        _Dispersion        ("Dispersion Amount", Range(0,1)) = 0.3

        [Header(Inner Glow)][Space(4)]
        [HDR] _InnerColor  ("Inner Glow Color", Color) = (0.4,0.6,1,1)
        _InnerStrength     ("Inner Glow Strength", Range(0,4)) = 1.2
        _FacetScale        ("Facet Noise Scale", Range(0,40)) = 8
        _FacetStrength     ("Facet Strength", Range(0,2)) = 0.5

        [Header(Fresnel and Specular)][Space(4)]
        [HDR] _FresnelColor ("Fresnel Color", Color) = (0.7,0.9,1,1)
        _FresnelPower      ("Fresnel Power", Range(0.2,8)) = 2.5
        _FresnelStrength   ("Fresnel Strength", Range(0,3)) = 1
        [HDR] _SpecColor2  ("Specular Color", Color) = (1,1,1,1)
        _SpecStrength      ("Specular Strength", Range(0,4)) = 1.5
        _SpecSize          ("Specular Size", Range(0,1)) = 0.1

        [Header(Render State)][Space(4)]
        _DepthFade         ("Edge Soft Fade", Range(0,4)) = 0.2
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

            #pragma shader_feature_local _DISPERSION

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fog
            #pragma multi_compile_instancing

            #include "../Core/StylizedLighting.hlsl"
            #include "../Core/StylizedSurface.hlsl"
            #include "../Core/StylizedNoise.hlsl"
            // Scene color (Opaque Texture) cho fake refraction.
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half4  _BaseColor;
                half   _Saturation;
                half   _RefractStrength;
                half   _Dispersion;
                half4  _InnerColor;
                half   _InnerStrength;
                half   _FacetScale;
                half   _FacetStrength;
                half4  _FresnelColor;
                half   _FresnelPower;
                half   _FresnelStrength;
                half4  _SpecColor2;
                half   _SpecStrength;
                half   _SpecSize;
                half   _DepthFade;
                half   _Alpha;
                half   _Cull;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
                STW_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                half3  normalWS   : TEXCOORD2;
                float4 screenPos  : TEXCOORD3;
                half   fogCoord   : TEXCOORD4;
                STW_VERTEX_OUTPUT_STEREO
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT = (Varyings)0;
                STW_SETUP_INSTANCE_VERT(IN, OUT);

                VertexPositionInputs pos = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs   nrm = GetVertexNormalInputs(IN.normalOS);

                OUT.positionCS = pos.positionCS;
                OUT.positionWS = pos.positionWS;
                OUT.normalWS   = nrm.normalWS;
                OUT.uv         = IN.uv;
                OUT.screenPos  = ComputeScreenPos(pos.positionCS);
                OUT.fogCoord   = ComputeFogFactor(pos.positionCS.z);
                return OUT;
            }

            // Khử bão hoà màu scene-color đã refraction về phía xám (đỡ "kính nhuộm" gắt).
            half3 ApplySaturation(half3 c, half sat)
            {
                half luma = dot(c, half3(0.299h, 0.587h, 0.114h));
                return lerp(half3(luma, luma, luma), c, sat);
            }

            half4 frag(Varyings IN) : SV_Target
            {
                STW_SETUP_INSTANCE_FRAG(IN);

                half3 normalWS  = STW_SafeNormalize(IN.normalWS);
                half3 viewDirWS = STW_SafeNormalize(GetWorldSpaceViewDir(IN.positionWS));

                // --- refraction: lệch UV scene theo normal view-space ---
                half3 normalVS = STW_SafeNormalize(TransformWorldToViewDir(normalWS, true));
                float2 baseUV  = STW_ScreenUV(IN.screenPos);
                float2 offset  = normalVS.xy * _RefractStrength * 0.1;

            #if defined(_DISPERSION)
                // tách kênh: R lệch nhiều hơn, B ít hơn → viền tán sắc
                half disp = _Dispersion * 0.04h;
                half r = SampleSceneColor(baseUV + offset * (1.0 + disp)).r;
                half g = SampleSceneColor(baseUV + offset).g;
                half b = SampleSceneColor(baseUV + offset * (1.0 - disp)).b;
                half3 refr = half3(r, g, b);
            #else
                half3 refr = SampleSceneColor(baseUV + offset);
            #endif
                refr = ApplySaturation(refr, _Saturation);

                // tô màu pha lê: scene color đã refraction nhân tint
                half3 color = refr * _BaseColor.rgb;

                // --- inner glow: dày (nghịch fresnel) + facet noise ---
                half facing = saturate(dot(normalWS, viewDirWS));
                half facet  = STW_GradientNoise(IN.uv * _FacetScale) * _FacetStrength;
                half inner  = facing * (1.0h + facet) * _InnerStrength;
                color += _InnerColor.rgb * inner;

                // --- toon specular (lấp lánh) ---
                float4 shadowCoord = TransformWorldToShadowCoord(IN.positionWS);
                half4 sm = half4(1,1,1,1);
                Light ml = STW_GetMainLight(shadowCoord, IN.positionWS, sm);
                half spec = STW_ToonSpecular(normalWS, ml.direction, viewDirWS, _SpecSize);
                color += spec * _SpecStrength * _SpecColor2.rgb * ml.color;

                // --- fresnel viền ---
                half fres = STW_Fresnel(normalWS, viewDirWS, _FresnelPower);
                color += fres * _FresnelStrength * _FresnelColor.rgb;

                // --- alpha: mép mỏng trong, lõi đặc; fresnel làm viền rõ ---
                half alpha = saturate(_BaseColor.a + fres * _FresnelStrength) * _Alpha;
                alpha *= STW_DepthFade(IN.screenPos, IN.positionWS, _DepthFade);

                color = STW_ApplyFog(color, IN.fogCoord);
                return half4(color, alpha);
            }
            ENDHLSL
        }
    }

    FallBack Off
    CustomEditor "StylizedToonWorldKit.Editor.CrystalGUI"
}
