// =============================================================================
//  OceanGUI.cs  —  Stylized Toon World Kit / P2 Environment
// -----------------------------------------------------------------------------
//  ShaderGUI cho StylizedOcean.shader.
// =============================================================================
#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

namespace StylizedToonWorldKit.Editor
{
    public class OceanGUI : StylizedShaderGUIBase
    {
        protected override void DrawProperties(MaterialEditor me, MaterialProperty[] ps, Material m)
        {
            BeginGroup("Depth Color");
            DrawProp(me, ps, "_ShallowColor");
            DrawProp(me, ps, "_DeepColor");
            DrawProp(me, ps, "_DepthRamp");
            EndGroup();

            BeginGroup("Gerstner Waves");
            EditorGUILayout.HelpBox("Mỗi sóng: xy = hướng (auto-normalize), z = steepness (0..1), w = wavelength.", MessageType.Info);
            DrawProp(me, ps, "_WaveA");
            DrawProp(me, ps, "_WaveB");
            DrawProp(me, ps, "_WaveC");
            DrawProp(me, ps, "_WaveAmp");
            DrawProp(me, ps, "_WaveSpeed");
            EndGroup();

            BeginGroup("Foam");
            DrawProp(me, ps, "_FoamColor");
            DrawProp(me, ps, "_CrestFoam");
            DrawProp(me, ps, "_CrestSharp");
            DrawProp(me, ps, "_FoamDistance");
            EndGroup();

            BeginGroup("Lighting");
            DrawProp(me, ps, "_ShadowTint");
            DrawProp(me, ps, "_RampSteps");
            DrawProp(me, ps, "_RampSmooth");
            DrawProp(me, ps, "_GIStrength");
            DrawProp(me, ps, "_SpecColor2");
            DrawProp(me, ps, "_SpecStrength");
            DrawProp(me, ps, "_SpecSize");
            DrawProp(me, ps, "_FresnelColor");
            DrawProp(me, ps, "_FresnelPower");
            DrawProp(me, ps, "_FresnelStrength");
            EndGroup();
        }
    }
}
#endif
