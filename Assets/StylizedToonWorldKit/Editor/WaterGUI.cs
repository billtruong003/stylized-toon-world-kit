// =============================================================================
//  WaterGUI.cs  —  Stylized Toon World Kit / P2 Environment
// -----------------------------------------------------------------------------
//  ShaderGUI cho StylizedWater.shader.
// =============================================================================
#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

namespace StylizedToonWorldKit.Editor
{
    public class WaterGUI : StylizedShaderGUIBase
    {
        protected override void DrawProperties(MaterialEditor me, MaterialProperty[] ps, Material m)
        {
            BeginGroup("Depth Color");
            DrawProp(me, ps, "_ShallowColor");
            DrawProp(me, ps, "_DeepColor");
            DrawProp(me, ps, "_DepthRamp");
            DrawProp(me, ps, "_DepthPower");
            EditorGUILayout.HelpBox("Cần bật URP Depth Texture cho gradient/foam/caustic.", MessageType.Info);
            EndGroup();

            BeginGroup("Foam");
            DrawProp(me, ps, "_FoamColor");
            DrawProp(me, ps, "_FoamDistance");
            DrawProp(me, ps, "_FoamNoiseScale");
            DrawProp(me, ps, "_FoamSpeed");
            DrawProp(me, ps, "_FoamCutoff");
            EndGroup();

            BeginGroup("Surface Waves");
            bool nm = DrawKeywordToggle(me, ps, m, "_NORMALMAP", "_NormalMapToggle", "Use Normal Map");
            if (nm)
            {
                DrawProp(me, ps, "_NormalMap");
                DrawProp(me, ps, "_NormalScale");
            }
            EndKeywordToggle(nm);
            DrawProp(me, ps, "_WaveScale");
            DrawProp(me, ps, "_FlowDir");
            DrawProp(me, ps, "_FlowSpeed");
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

            BeginGroup("Caustics");
            bool ca = DrawKeywordToggle(me, ps, m, "_CAUSTIC", "_CausticToggle", "Enable Caustics");
            if (ca)
            {
                DrawProp(me, ps, "_CausticColor");
                DrawProp(me, ps, "_CausticScale");
                DrawProp(me, ps, "_CausticSpeed");
                DrawProp(me, ps, "_CausticStrength");
            }
            EndKeywordToggle(ca);
            EndGroup();

            BeginGroup("Render State");
            DrawProp(me, ps, "_Alpha");
            DrawProp(me, ps, "_Cull");
            EndGroup();
        }
    }
}
#endif
