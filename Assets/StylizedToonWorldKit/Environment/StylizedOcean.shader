// =============================================================================
//  StylizedOcean.shader  —  Stylized Toon World Kit / P2 Environment
// -----------------------------------------------------------------------------
//  ĐẠI DƯƠNG: biến thể nâng cao của Water — sóng động hình học.
//    • 3 sóng Gerstner cộng dồn (vertex displacement) → đỉnh nhọn, đáy phẳng.
//    • Normal tính giải tích từ đạo hàm Gerstner (không cần normal map).
//    • Foam đỉnh sóng theo Jacobian/độ cao + foam viền theo depth (Depth Texture).
//    • Toon ramp + specular bậc + fresnel chân trời + gradient nông/sâu.
//  Opaque lit (có ShadowCaster dùng chung hàm displacement). URP 17 / U6 · SRP Batcher · VR SPI.
//  Hàm Gerstner đặt ở HLSLINCLUDE để ForwardLit & ShadowCaster dùng CHUNG (đồng bộ sóng).
// =============================================================================
Shader "StylizedToonWorldKit/Environment/Ocean"
{
    Properties
    {
        [Header(Depth Color)][Space(4)]
        _ShallowColor ("Shallow Color", Color) = (0.1,0.5,0.6,1)
        _DeepColor    ("Deep Color", Color)    = (0.0,0.12,0.3,1)
        _DepthRamp    ("Depth Distance", Range(0.1,60)) = 12

        [Header(Gerstner Waves)][Space(4)]
        // mỗi sóng: xy = hướng (sẽ normalize), z = steepness(0..1), w = wavelength
        _WaveA ("Wave A (dirX,dirY,steep,len)", Vector) = (1,0,0.5,8)
        _WaveB ("Wave B (dirX,dirY,steep,len)", Vector) = (0.6,0.8,0.35,5)
        _WaveC ("Wave C (dirX,dirY,steep,len)", Vector) = (-0.8,0.4,0.25,3)
        _WaveAmp   ("Amplitude Scale", Range(0,3)) = 1
        _WaveSpeed ("Wave Speed", Range(0,3)) = 1

        [Header(Foam)][Space(4)]
        _FoamColor    ("Foam Color", Color) = (1,1,1,1)
        _CrestFoam    ("Crest Foam Amount", Range(0,3)) = 1
        _CrestSharp   ("Crest Foam Sharpness", Range(0.2,8)) = 3
        _FoamDistance ("Shore Foam Distance", Range(0,8)) = 1

        [Header(Lighting)][Space(4)]
        _ShadowTint   ("Shadow Tint", Color) = (0.05,0.15,0.3,1)
        _RampSteps    ("Cel Steps", Range(1,6)) = 2
        _RampSmooth   ("Ramp Softness", Range(0,1)) = 0.15
        _GIStrength   ("GI Strength", Range(0,2)) = 0.7
        [HDR] _SpecColor2 ("Specular Color", Color) = (1,1,1,1)
        _SpecStrength ("Specular Strength", Range(0,4)) = 1.5
        _SpecSize     ("Specular Size", Range(0,1)) = 0.1
        [HDR] _FresnelColor ("Fresnel Color", Color) = (0.5,0.8,1,1)
        _FresnelPower ("Fresnel Power", Range(0.2,8)) = 4
        _FresnelStrength ("Fresnel Strength", Range(0,2)) = 0.7

        [HideInInspector] _Cull ("Cull", Float) = 2
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest  ("ZTest", Float) = 4
        [Enum(Off,0,On,1)]                            _ZWrite ("ZWrite", Float) = 1
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" "Queue"="Geometry+10" }
        LOD 300

        HLSLINCLUDE
        #include "../Core/StylizedLighting.hlsl"
        #include "../Core/StylizedSurface.hlsl"

        CBUFFER_START(UnityPerMaterial)
            half4  _ShallowColor;
            half4  _DeepColor;
            half   _DepthRamp;
            float4 _WaveA;
            float4 _WaveB;
            float4 _WaveC;
            half   _WaveAmp;
            half   _WaveSpeed;
            half4  _FoamColor;
            half   _CrestFoam;
            half   _CrestSharp;
            half   _FoamDistance;
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
            half   _Cull; half _ZTest; half _ZWrite;
        CBUFFER_END

        // Một sóng Gerstner: dịch vị trí + cộng dồn tangent/binormal để ra normal.
        // wave = (dir.x, dir.y, steepness, wavelength). Trả offset, cập nhật T/B.
        float3 GerstnerWave(float4 wave, float3 p, float time, inout float3 tangent, inout float3 binormal)
        {
            float2 dir = normalize(wave.xy + float2(1e-4, 0));
            float  steep = wave.z;
            float  wlen = max(0.1, wave.w);
            float  k = 6.2831853 / wlen;
            float  c = sqrt(9.8 / k);                 // tốc độ pha sóng nước sâu
            float  f = k * (dot(dir, p.xz) - c * time);
            float  a = steep / k;                      // biên độ từ steepness

            float sinF = sin(f);
            float cosF = cos(f);

            tangent  += float3(-dir.x * dir.x * (steep * sinF), dir.x * (steep * cosF), -dir.x * dir.y * (steep * sinF));
            binormal += float3(-dir.x * dir.y * (steep * sinF), dir.y * (steep * cosF), -dir.y * dir.y * (steep * sinF));

            return float3(dir.x * (a * cosF), a * sinF, dir.y * (a * cosF));
        }

        // Cộng 3 sóng → trả offset WS + normal WS (analytic). amp scale toàn cục.
        float3 OceanDisplace(float3 positionWS, out float3 normalWS, out float crest)
        {
            float time = _Time.y * _WaveSpeed;
            float3 tangent = float3(1, 0, 0);
            float3 binormal = float3(0, 0, 1);
            float3 offset = 0;
            offset += GerstnerWave(_WaveA, positionWS, time, tangent, binormal);
            offset += GerstnerWave(_WaveB, positionWS, time, tangent, binormal);
            offset += GerstnerWave(_WaveC, positionWS, time, tangent, binormal);
            offset *= _WaveAmp;
            normalWS = normalize(cross(binormal, tangent));
            crest = saturate(offset.y * _WaveAmp); // đỉnh dương = mào sóng
            return offset;
        }
        ENDHLSL

        // ---------------------------------------------------------------------
        //  PASS 1 — ForwardLit
        // ---------------------------------------------------------------------
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }
            Cull   [_Cull]
            ZTest  [_ZTest]
            ZWrite [_ZWrite]
            HLSLPROGRAM
            #pragma vertex   vert
            #pragma fragment frag
            #pragma target 3.0

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile _ _CLUSTER_LIGHT_LOOP
            #pragma multi_compile_fog
            #pragma multi_compile_instancing

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                STW_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                half3  normalWS   : TEXCOORD1;
                float4 screenPos  : TEXCOORD2;
                half   crest      : TEXCOORD3;
                half   fogCoord   : TEXCOORD4;
                STW_VERTEX_OUTPUT_STEREO
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT = (Varyings)0;
                STW_SETUP_INSTANCE_VERT(IN, OUT);

                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                float3 normalWS;
                float crest;
                positionWS += OceanDisplace(positionWS, normalWS, crest);

                OUT.positionWS = positionWS;
                OUT.normalWS   = normalWS;
                OUT.positionCS = TransformWorldToHClip(positionWS);
                OUT.screenPos  = ComputeScreenPos(OUT.positionCS);
                OUT.crest      = crest;
                OUT.fogCoord   = ComputeFogFactor(OUT.positionCS.z);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                STW_SETUP_INSTANCE_FRAG(IN);

                half3 normalWS = STW_SafeNormalize(IN.normalWS);

                // gradient nông/sâu theo depth scene (Depth Texture)
                float2 suv = STW_ScreenUV(IN.screenPos);
                float sceneEye = LinearEyeDepth(SampleSceneDepth(suv), _ZBufferParams);
                float waterDepth = max(0.0, sceneEye - IN.screenPos.w);
                half depthGrad = saturate(waterDepth / max(STW_EPSILON, _DepthRamp));
                half3 baseCol = lerp(_ShallowColor.rgb, _DeepColor.rgb, depthGrad);

                float4 shadowCoord = TransformWorldToShadowCoord(IN.positionWS);
                half4 shadowMask = half4(1,1,1,1);
                Light ml = STW_GetMainLight(shadowCoord, IN.positionWS, shadowMask);
                half atten = ml.shadowAttenuation * ml.distanceAttenuation;
                half ndotl = dot(normalWS, ml.direction);
                half ramp = STW_RampStep(ndotl, _RampSteps, _RampSmooth) * atten;
                half3 color = baseCol * lerp(_ShadowTint.rgb, half3(1,1,1), ramp) * ml.color;
                color += SampleSH(normalWS) * baseCol * _GIStrength;

                half3 viewDirWS = STW_SafeNormalize(GetWorldSpaceViewDir(IN.positionWS));
                half spec = STW_ToonSpecular(normalWS, ml.direction, viewDirWS, _SpecSize);
                color += spec * _SpecStrength * _SpecColor2.rgb * ml.color * atten;

                half fres = STW_Fresnel(normalWS, viewDirWS, _FresnelPower);
                color += fres * _FresnelStrength * _FresnelColor.rgb;

                // foam: đỉnh sóng (crest) + viền bờ (depth)
                half crestFoam = pow(saturate(IN.crest * _CrestFoam), _CrestSharp);
                half shoreFoam = 1.0h - saturate(waterDepth / max(STW_EPSILON, _FoamDistance));
                half foam = saturate(max(crestFoam, shoreFoam * shoreFoam));
                color = lerp(color, _FoamColor.rgb, foam);

                color = STW_ApplyFog(color, IN.fogCoord);
                return half4(color, 1);
            }
            ENDHLSL
        }

        // ---------------------------------------------------------------------
        //  PASS 2 — ShadowCaster (dùng cùng displacement để bóng khớp sóng)
        // ---------------------------------------------------------------------
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode"="ShadowCaster" }
            ZWrite On ZTest LEqual ColorMask 0 Cull [_Cull]

            HLSLPROGRAM
            #pragma vertex   shadowVert
            #pragma fragment shadowFrag
            #pragma multi_compile_instancing
            #pragma multi_compile _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            float3 _LightDirection;
            float3 _LightPosition;

            struct AttributesS { float4 positionOS:POSITION; float3 normalOS:NORMAL; STW_VERTEX_INPUT_INSTANCE_ID };
            struct VaryingsS   { float4 positionCS:SV_POSITION; STW_VERTEX_OUTPUT_STEREO };

            VaryingsS shadowVert(AttributesS IN)
            {
                VaryingsS OUT = (VaryingsS)0;
                STW_SETUP_INSTANCE_VERT(IN, OUT);

                float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                float3 normalWS; float crest;
                positionWS += OceanDisplace(positionWS, normalWS, crest);

            #if _CASTING_PUNCTUAL_LIGHT_SHADOW
                float3 dir = normalize(_LightPosition - positionWS);
            #else
                float3 dir = _LightDirection;
            #endif
                float4 cs = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, dir));
            #if UNITY_REVERSED_Z
                cs.z = min(cs.z, UNITY_NEAR_CLIP_VALUE);
            #else
                cs.z = max(cs.z, UNITY_NEAR_CLIP_VALUE);
            #endif
                OUT.positionCS = cs;
                return OUT;
            }
            half4 shadowFrag(VaryingsS IN) : SV_Target { return 0; }
            ENDHLSL
        }
    }

    FallBack Off
    CustomEditor "StylizedToonWorldKit.Editor.OceanGUI"
}
