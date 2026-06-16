// =============================================================================
//  ToonRimGUI.cs  —  Stylized Toon World Kit / P1
// -----------------------------------------------------------------------------
//  ShaderGUI cho StylizedToonRim.shader.
// =============================================================================
#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

namespace StylizedToonWorldKit.Editor
{
    public class ToonRimGUI : StylizedShaderGUIBase
    {
        protected override void DrawProperties(MaterialEditor me, MaterialProperty[] ps, Material m)
        {
            BeginGroup("Base");
            DrawProp(me, ps, "_BaseMap");
            DrawProp(me, ps, "_BaseColor");
            EndGroup();

            BeginGroup("Cel Shading");
            DrawProp(me, ps, "_ShadowTint");
            DrawProp(me, ps, "_RampSteps");
            DrawProp(me, ps, "_RampSmooth");
            DrawProp(me, ps, "_GIStrength");
            EndGroup();

            BeginGroup("Rim / Fresnel");
            DrawProp(me, ps, "_RimColor");
            DrawProp(me, ps, "_RimColorOut");
            DrawProp(me, ps, "_RimPower");
            DrawProp(me, ps, "_RimStrength");
            bool align = DrawKeywordToggle(me, ps, m, "_RIM_ALIGN", "_RimAlign", "Align Rim to Light");
            if (align) DrawProp(me, ps, "_RimAlignBias");
            EndKeywordToggle(align);
            EndGroup();
        }
    }
}
#endif
