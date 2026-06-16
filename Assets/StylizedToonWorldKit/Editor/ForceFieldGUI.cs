// =============================================================================
//  ForceFieldGUI.cs  —  Stylized Toon World Kit / P3 VFX
// -----------------------------------------------------------------------------
//  ShaderGUI cho StylizedForceField.shader.
// =============================================================================
#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

namespace StylizedToonWorldKit.Editor
{
    public class ForceFieldGUI : StylizedShaderGUIBase
    {
        protected override void DrawProperties(MaterialEditor me, MaterialProperty[] ps, Material m)
        {
            BeginGroup("Fresnel Rim");
            DrawProp(me, ps, "_FresnelColor");
            DrawProp(me, ps, "_FresnelPower");
            DrawProp(me, ps, "_FresnelGlow");
            EndGroup();

            BeginGroup("Hex Grid");
            DrawProp(me, ps, "_HexColor");
            DrawProp(me, ps, "_HexScale");
            DrawProp(me, ps, "_HexLine");
            DrawProp(me, ps, "_HexScroll");
            EndGroup();

            BeginGroup("Intersection Glow");
            DrawProp(me, ps, "_IntersectColor");
            DrawProp(me, ps, "_IntersectFade");
            EndGroup();

            BeginGroup("Impact Ripple");
            DrawProp(me, ps, "_ImpactPos");
            DrawProp(me, ps, "_ImpactT");
            DrawProp(me, ps, "_ImpactRadius");
            DrawProp(me, ps, "_ImpactWidth");
            DrawProp(me, ps, "_ImpactColor");
            EndGroup();

            BeginGroup("Overall");
            DrawProp(me, ps, "_Alpha");
            EndGroup();

            DrawBlendStateGroup(me, ps, true);
        }
    }
}
#endif
