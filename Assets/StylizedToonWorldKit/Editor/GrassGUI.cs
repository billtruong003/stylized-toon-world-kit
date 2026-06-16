// =============================================================================
//  GrassGUI.cs  —  Stylized Toon World Kit / P2 Environment
// -----------------------------------------------------------------------------
//  ShaderGUI cho StylizedGrass.shader.
// =============================================================================
#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

namespace StylizedToonWorldKit.Editor
{
    public class GrassGUI : StylizedShaderGUIBase
    {
        protected override void DrawProperties(MaterialEditor me, MaterialProperty[] ps, Material m)
        {
            BeginGroup("Base");
            DrawProp(me, ps, "_BaseMap");
            DrawProp(me, ps, "_RootColor");
            DrawProp(me, ps, "_TipColor");
            DrawProp(me, ps, "_GradientPower");
            EditorGUILayout.HelpBox("Gradient gốc→ngọn theo uv.y (gốc blade = 0, ngọn = 1).", MessageType.Info);
            EndGroup();

            BeginGroup("Alpha Clip");
            bool ac = DrawKeywordToggle(me, ps, m, "_ALPHATEST", "_AlphaClipToggle", "Enable Alpha Clip");
            if (ac) DrawProp(me, ps, "_Cutoff");
            EndKeywordToggle(ac);
            EndGroup();

            BeginGroup("Wind");
            DrawProp(me, ps, "_WindDir");
            DrawProp(me, ps, "_WindStrength");
            DrawProp(me, ps, "_WindSpeed");
            DrawProp(me, ps, "_WindFreq");
            DrawProp(me, ps, "_GustStrength");
            EndGroup();

            BeginGroup("Lighting");
            DrawProp(me, ps, "_ShadowTint");
            DrawProp(me, ps, "_RampSteps");
            DrawProp(me, ps, "_RampSmooth");
            DrawProp(me, ps, "_GIStrength");
            DrawProp(me, ps, "_Occlusion");
            EndGroup();

            BeginGroup("Translucency");
            DrawProp(me, ps, "_TransColor");
            DrawProp(me, ps, "_TransStrength");
            DrawProp(me, ps, "_TransPower");
            EndGroup();
        }
    }
}
#endif
