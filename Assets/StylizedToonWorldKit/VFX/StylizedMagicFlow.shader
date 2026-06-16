// =============================================================================
//  StylizedMagicFlow.shader  —  Stylized Toon World Kit / P3 VFX
// -----------------------------------------------------------------------------
//  MA THUẬT / ENERGY FLOW: dòng năng-lượng chảy xoáy UNLIT trong suốt, hợp vòng
//  phép thuật (magic circle), aura, energy beam:
//    • Flow-map 2 phase (kỹ thuật Valve) distort texture/noise → chảy mượt vô hạn.
//    • Polar UV (keyword _POLAR) → xoáy tròn quanh tâm cho magic circle.
//    • Gradient màu theo cường độ + fresnel rim phụ.
//  Additive. URP 17 / Unity 6 · SRP Batcher · Instancing · VR SPI.
// =============================================================================
Shader "StylizedToonWorldKit/VFX/MagicFlow"
{
    Properties
    {
        [HDR] _ColorLow  ("Low Color", Color) = (0.3,0.1,1.2,1)
        [HDR] _ColorHigh ("High Color", Color) = (1.6,0.6,3.0,1)
        _MainMap   ("Energy Map", 2D) = "white" {}
        _FlowMap   ("Flow Map (RG)", 2D) = "grey" {}

        [Header(Flow)][Space(4)]
        _FlowSpeed   ("Flow Speed", Range(0,4)) = 0.6
        _FlowStrength("Flow Strength", Range(0,1)) = 0.3
        _NoiseScale  ("Detail Noise Scale", Range(0.5,20)) = 4
        _Intensity   ("Intensity", Range(0,4)) = 1.4

        [Header(Polar (magic circle))][Space(4)]
        [Toggle(_POLAR)] _UsePolar ("Polar UV", Float) = 0
        _Spin ("Spin Speed", Range(-4,4)) = 0.5

        _Fresnel ("Fresnel Power", Range(0,8)) = 0
        _Alpha   ("Overall Alpha", Range(0,1)) = 1

        [Header(Render State)][Space(4)]
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("Src Blend", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("Dst Blend", Float) = 1
        [Enum(Off,0,On,1)] _ZWrite ("ZWrite", Float) = 0
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull", Float) = 0
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Transparent" "Queue"="Transparent" "IgnoreProjector"="True" }
        LOD 100

        Pass
        {
            Name "ForwardUnlit"
            Tags { "LightMode"="UniversalForward" }
            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]
            Cull [_Cull]

            HLSLPROGRAM
            #pragma vertex   STW_VFXVert
            #pragma fragment frag
            #pragma target 3.0
            #pragma multi_compile_fog
            #pragma multi_compile_instancing
            #pragma shader_feature_local _POLAR

            #include "URPCompat.hlsl"
            #include "StylizedNoise.hlsl"
            #include "StylizedVFX.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _MainMap_ST;
                float4 _FlowMap_ST;
                half4  _ColorLow;
                half4  _ColorHigh;
                half   _FlowSpeed;
                half   _FlowStrength;
                half   _NoiseScale;
                half   _Intensity;
                half   _Spin;
                half   _Fresnel;
                half   _Alpha;
                half   _SrcBlend; half _DstBlend; half _ZWrite; half _Cull;
            CBUFFER_END

            TEXTURE2D(_MainMap); SAMPLER(sampler_MainMap);
            TEXTURE2D(_FlowMap); SAMPLER(sampler_FlowMap);

            half4 frag(VFXVaryings IN) : SV_Target
            {
                STW_SETUP_INSTANCE_FRAG(IN);

                float2 uv = IN.uv;
            #if defined(_POLAR)
                float2 p = STW_PolarUV(IN.uv, float2(0.5, 0.5));
                p.x += _Time.y * _Spin;
                uv = p;
            #endif

                // flow map .rg (-1..1) điều hướng dòng chảy.
                float2 flowSample = TRANSFORM_TEX(uv, _FlowMap);
                float2 flowDir = SAMPLE_TEXTURE2D(_FlowMap, sampler_FlowMap, flowSample).rg * 2.0 - 1.0;
                flowDir *= _FlowStrength;

                float2 muv = TRANSFORM_TEX(uv, _MainMap);
                float2 uv0, uv1; float w;
                STW_Flow(muv, flowDir, _Time.y, _FlowSpeed, uv0, uv1, w);

                half e0 = SAMPLE_TEXTURE2D(_MainMap, sampler_MainMap, uv0).r;
                half e1 = SAMPLE_TEXTURE2D(_MainMap, sampler_MainMap, uv1).r;
                half energy = lerp(e0, e1, w);

                // detail noise cộng thêm độ "sôi".
                half detail = STW_FBM(muv * _NoiseScale + _Time.y * 0.3 * _FlowSpeed, 2, 2.0, 0.5);
                energy = saturate(energy * (0.6h + detail * 0.6h)) * _Intensity;

                half3 color = lerp(_ColorLow.rgb, _ColorHigh.rgb, saturate(energy));
                half  alpha = saturate(energy);

                if (_Fresnel > 0.001h)
                {
                    half fres = STW_FresnelVFX(IN.normalWS, IN.viewDirWS, _Fresnel);
                    color += _ColorHigh.rgb * fres * 0.5h;
                    alpha = max(alpha, fres);
                }

                color *= IN.color.rgb;
                alpha *= IN.color.a * _Alpha * _ColorHigh.a;

                color = STW_ApplyFog(color, IN.fogCoord);
                return half4(color, saturate(alpha));
            }
            ENDHLSL
        }
    }

    FallBack Off
    CustomEditor "StylizedToonWorldKit.Editor.MagicFlowGUI"
}
