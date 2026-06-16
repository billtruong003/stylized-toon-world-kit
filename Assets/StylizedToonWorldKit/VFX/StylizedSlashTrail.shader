// =============================================================================
//  StylizedSlashTrail.shader  —  Stylized Toon World Kit / P3 VFX
// -----------------------------------------------------------------------------
//  SLASH / WEAPON TRAIL: vệt chém UNLIT trong suốt cho TrailRenderer hoặc mesh
//  vệt (uv.x = dọc chiều dài head→tail, uv.y = ngang bề rộng):
//    • Gradient màu head→tail + fade đuôi (alpha giảm về tail).
//    • Soft edge ngang (mỏng dần ở mép trên/dưới).
//    • Distortion noise tuỳ chọn (rung mép như năng lượng).
//    • Dissolve đuôi theo _Trim (cắt bớt đuôi cho trail co lại).
//  Additive mặc định. URP 17 / Unity 6 · SRP Batcher · Instancing · VR SPI.
// =============================================================================
Shader "StylizedToonWorldKit/VFX/SlashTrail"
{
    Properties
    {
        [MainTexture] _BaseMap ("Mask Map (optional)", 2D) = "white" {}
        [HDR] _ColorHead ("Head Color", Color) = (5,5,5,1)
        [HDR] _ColorTail ("Tail Color", Color) = (2,0.4,0.1,1)
        _GradientPow ("Gradient Power", Range(0.2,6)) = 1.5

        [Header(Shape)][Space(4)]
        _SoftEdge ("Edge Softness", Range(0.001,1)) = 0.35
        _Trim     ("Tail Trim", Range(0,1)) = 0
        _HeadTrim ("Head Trim", Range(0,1)) = 0

        [Header(Distortion)][Space(4)]
        _Distortion ("Distortion", Range(0,0.5)) = 0.05
        _DistScale  ("Distortion Scale", Range(0.5,20)) = 6
        _DistSpeed  ("Distortion Speed", Range(0,10)) = 3

        _Alpha ("Overall Alpha", Range(0,1)) = 1

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

            #include "URPCompat.hlsl"
            #include "StylizedNoise.hlsl"
            #include "StylizedVFX.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4  _ColorHead;
                half4  _ColorTail;
                half   _GradientPow;
                half   _SoftEdge;
                half   _Trim;
                half   _HeadTrim;
                half   _Distortion;
                half   _DistScale;
                half   _DistSpeed;
                half   _Alpha;
                half   _SrcBlend; half _DstBlend; half _ZWrite; half _Cull;
            CBUFFER_END

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);

            half4 frag(VFXVaryings IN) : SV_Target
            {
                STW_SETUP_INSTANCE_FRAG(IN);

                // distort UV bằng noise.
                float2 duv = IN.uv;
                if (_Distortion > 0.0001h)
                {
                    half d = STW_GradientNoise(IN.uv * _DistScale + float2(_Time.y * _DistSpeed, 0)) - 0.5h;
                    duv += float2(0, d * _Distortion);
                }

                half4 tex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, TRANSFORM_TEX(duv, _BaseMap));

                // gradient dọc head(uv.x=1)→tail(uv.x=0).
                half g = pow(saturate(IN.uv.x), _GradientPow);
                half3 color = lerp(_ColorTail.rgb, _ColorHead.rgb, g);

                // fade ngang (mép trên/dưới mỏng dần).
                half edge = smoothstep(0.0h, _SoftEdge, IN.uv.y) * smoothstep(0.0h, _SoftEdge, 1.0h - IN.uv.y);

                // trim đuôi + đầu.
                half trimMask = smoothstep(_Trim, _Trim + 0.05h, IN.uv.x)
                              * smoothstep(_HeadTrim, _HeadTrim + 0.05h, 1.0h - IN.uv.x);

                half alpha = tex.a * edge * trimMask * g;
                color *= tex.rgb;

                color *= IN.color.rgb;
                alpha *= IN.color.a * _Alpha * _ColorHead.a;

                color = STW_ApplyFog(color, IN.fogCoord);
                return half4(color, saturate(alpha));
            }
            ENDHLSL
        }
    }

    FallBack Off
    CustomEditor "StylizedToonWorldKit.Editor.SlashTrailGUI"
}
