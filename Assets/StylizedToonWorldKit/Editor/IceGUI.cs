// =============================================================================
//  IceGUI.cs  —  Stylized Toon World Kit / P4 Surface
// -----------------------------------------------------------------------------
//  ShaderGUI cho StylizedIce.shader.
// =============================================================================
#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

namespace StylizedToonWorldKit.Editor
{
    public class IceGUI : StylizedShaderGUIBase
    {
        protected override void DrawProperties(MaterialEditor me, MaterialProperty[] ps, Material m)
        {
            BeginGroup("Base");
            DrawProp(me, ps, "_BaseMap");
            DrawProp(me, ps, "_BaseColor");
            EndGroup();

            BeginGroup("Toon Lighting");
            DrawProp(me, ps, "_ShadowTint");
            DrawProp(me, ps, "_RampSteps");
            DrawProp(me, ps, "_RampSmooth");
            DrawProp(me, ps, "_GIStrength");
            DrawProp(me, ps, "_SpecStrength");
            DrawProp(me, ps, "_SpecSize");
            EndGroup();

            BeginGroup("Depth Tint");
            DrawProp(me, ps, "_DepthColor");
            DrawProp(me, ps, "_DepthStrength");
            DrawProp(me, ps, "_DepthPower");
            EndGroup();

            BeginGroup("Sparkle");
            bool sp = DrawKeywordToggle(me, ps, m, "_SPARKLE", "_SparkleToggle", "Enable Sparkle");
            if (sp)
            {
                DrawProp(me, ps, "_SparkleColor");
                DrawProp(me, ps, "_SparkleScale");
                DrawProp(me, ps, "_SparkleAmount");
                DrawProp(me, ps, "_SparkleSpeed");
                DrawProp(me, ps, "_SparkleStrength");
            }
            EndKeywordToggle(sp);
            EndGroup();

            BeginGroup("Frost Edge");
            DrawProp(me, ps, "_FrostColor");
            DrawProp(me, ps, "_FrostPower");
            DrawProp(me, ps, "_FrostStrength");
            EndGroup();

            BeginGroup("Render State");
            DrawProp(me, ps, "_Cull");
            EndGroup();
        }
    }
}
#endif
