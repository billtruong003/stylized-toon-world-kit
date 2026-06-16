// =============================================================================
//  StylizedForceField.shader  —  Stylized Toon World Kit / P3 VFX
// -----------------------------------------------------------------------------
//  KHIÊN / FORCE FIELD: vỏ cầu năng-lượng UNLIT trong suốt:
//    • Fresnel rim (sáng viền theo góc nhìn).
//    • Lưới tổ ong (hex grid) chạy nhẹ — kết cấu "tech shield".
//    • Intersection glow: sáng lên nơi khiên cắt geometry (cần Depth Texture).
//    • Impact ripple: gợn sóng lan từ điểm va chạm _ImpactPos theo _ImpactT.
//  Additive. URP 17 / Unity 6 · SRP Batcher · Instancing · VR SPI.
// =============================================================================
Shader "StylizedToonWorldKit/VFX/ForceField"
{
    Properties
    {
        [HDR] _FresnelColor ("Fresnel Color", Color) = (0.3,1.6,2.4,1)
        _FresnelPower ("Fresnel Power", Range(0.2,8)) = 2.5
        _FresnelGlow  ("Fresnel Strength", Range(0,4)) = 1.5

        [Header(Hex Grid)][Space(4)]
        [HDR] _HexColor ("Hex Color", Color) = (0.2,0.8,1.4,1)
        _HexScale     ("Hex Scale", Range(1,40)) = 10
        _HexLine      ("Hex Line Width", Range(0.001,0.4)) = 0.06
        _HexScroll    ("Hex Scroll Speed", Range(-4,4)) = 0.3

        [Header(Intersection Glow)][Space(4)]
        [HDR] _IntersectColor ("Intersect Color", Color) = (2,3,4,1)
        _IntersectFade ("Intersect Distance", Range(0.01,3)) = 0.4

        [Header(Impact Ripple)][Space(4)]
        _ImpactPos   ("Impact Pos (World)", Vector) = (0,0,0,0)
        _ImpactT     ("Impact Time 0..1", Range(0,1)) = 0
        _ImpactRadius("Impact Max Radius", Range(0.1,8)) = 3
        _ImpactWidth ("Impact Ring Width", Range(0.05,2)) = 0.6
        [HDR] _ImpactColor ("Impact Color", Color) = (3,2,0.6,1)

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

            #include "../Core/URPCompat.hlsl"
            #include "../Core/StylizedVFX.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half4  _FresnelColor;
                half   _FresnelPower;
                half   _FresnelGlow;
                half4  _HexColor;
                half   _HexScale;
                half   _HexLine;
                half   _HexScroll;
                half4  _IntersectColor;
                half   _IntersectFade;
                float4 _ImpactPos;
                half   _ImpactT;
                half   _ImpactRadius;
                half   _ImpactWidth;
                half4  _ImpactColor;
                half   _Alpha;
                half   _SrcBlend; half _DstBlend; half _ZWrite; half _Cull;
            CBUFFER_END

            half4 frag(VFXVaryings IN) : SV_Target
            {
                STW_SETUP_INSTANCE_FRAG(IN);

                // -- Fresnel rim --
                half fres = STW_FresnelVFX(IN.normalWS, IN.viewDirWS, _FresnelPower);
                half3 color = _FresnelColor.rgb * fres * _FresnelGlow;
                half  alpha = fres * _FresnelColor.a;

                // -- Hex grid (scroll theo thời gian) --
                float2 huv = IN.uv + float2(0, _Time.y * _HexScroll);
                half edge = STW_HexEdge(huv, _HexScale);       // ~0 ở cạnh
                half hexLine = 1.0h - smoothstep(0.0h, _HexLine, edge);
                color += _HexColor.rgb * hexLine;
                alpha = max(alpha, hexLine * _HexColor.a * 0.6h);

                // -- Intersection glow (sáng nơi khiên cắt geometry) --
                half through = STW_SoftParticle(IN.screenPos, _IntersectFade); // 1 xa, 0 sát mép
                half inter = 1.0h - through;
                color += _IntersectColor.rgb * inter;
                alpha = max(alpha, inter * _IntersectColor.a);

                // -- Impact ripple --
                float dist = distance(IN.positionWS, _ImpactPos.xyz);
                float ringR = _ImpactT * _ImpactRadius;
                half ring = 1.0h - saturate(abs(dist - ringR) / max(STW_EPSILON, _ImpactWidth));
                ring *= (1.0h - _ImpactT);                      // tắt dần khi lan rộng
                color += _ImpactColor.rgb * ring;
                alpha = max(alpha, ring * _ImpactColor.a);

                color *= IN.color.rgb;
                alpha *= IN.color.a * _Alpha;

                color = STW_ApplyFog(color, IN.fogCoord);
                return half4(color, saturate(alpha));
            }
            ENDHLSL
        }
    }

    FallBack Off
    CustomEditor "StylizedToonWorldKit.Editor.ForceFieldGUI"
}
