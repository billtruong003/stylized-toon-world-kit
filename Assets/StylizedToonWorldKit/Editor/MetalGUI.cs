// =============================================================================
//  MetalGUI.cs  —  Stylized Toon World Kit / P4 Surface
// -----------------------------------------------------------------------------
//  ShaderGUI cho StylizedMetal.shader.
// =============================================================================
#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

namespace StylizedToonWorldKit.Editor
{
    public class MetalGUI : StylizedShaderGUIBase
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
            EndGroup();

            BeginGroup("Stylized Environment");
            DrawProp(me, ps, "_Metallic");
            DrawProp(me, ps, "_EnvColor");
            DrawProp(me, ps, "_EnvStrength");
            DrawProp(me, ps, "_EnvSteps");
            DrawProp(me, ps, "_EnvSmooth");
            EndGroup();

            BeginGroup("Anisotropic Highlight");
            bool an = DrawKeywordToggle(me, ps, m, "_ANISO", "_AnisoToggle", "Enable Aniso");
            if (an)
            {
                DrawProp(me, ps, "_AnisoColor");
                DrawProp(me, ps, "_AnisoShift");
                DrawProp(me, ps, "_AnisoExponent");
                DrawProp(me, ps, "_AnisoStrength");
            }
            EndKeywordToggle(an);
            EndGroup();

            BeginGroup("Rim");
            DrawProp(me, ps, "_RimColor");
            DrawProp(me, ps, "_RimPower");
            DrawProp(me, ps, "_RimStrength");
            EndGroup();

            BeginGroup("Render State");
            DrawProp(me, ps, "_Cull");
            EndGroup();
        }
    }
}
#endif
