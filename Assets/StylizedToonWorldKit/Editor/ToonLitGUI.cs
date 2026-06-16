// =============================================================================
//  ToonLitGUI.cs  —  Stylized Toon World Kit / P1
// -----------------------------------------------------------------------------
//  ShaderGUI cho StylizedToonLit.shader. Nhóm property rõ ràng, ẩn/hiện theo
//  keyword toggle (_NORMALMAP/_RAMP_TEXTURE/_RIM/_EMISSION) — nguyên tắc #3.
// =============================================================================
#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

namespace StylizedToonWorldKit.Editor
{
    public class ToonLitGUI : StylizedShaderGUIBase
    {
        protected override void DrawProperties(MaterialEditor me, MaterialProperty[] ps, Material m)
        {
            BeginGroup("Base");
            DrawProp(me, ps, "_BaseMap");
            DrawProp(me, ps, "_BaseColor");
            EndGroup();

            BeginGroup("Normal Map");
            bool nm = DrawKeywordToggle(me, ps, m, "_NORMALMAP", "_NormalMapToggle", "Enable Normal Map");
            if (nm) { DrawProp(me, ps, "_BumpMap"); DrawProp(me, ps, "_BumpScale"); }
            EndKeywordToggle(nm);
            EndGroup();

            BeginGroup("Cel Shading");
            DrawProp(me, ps, "_ShadowTint");
            bool ramp = DrawKeywordToggle(me, ps, m, "_RAMP_TEXTURE", "_RampTexToggle", "Use Ramp Texture (1D LUT)");
            if (ramp) { DrawProp(me, ps, "_RampMap"); }
            else      { DrawProp(me, ps, "_RampSteps"); DrawProp(me, ps, "_RampSmooth"); }
            EndKeywordToggle(ramp);
            DrawProp(me, ps, "_GIStrength");
            DrawProp(me, ps, "_Occlusion");
            EndGroup();

            BeginGroup("Specular");
            DrawProp(me, ps, "_SpecStrength");
            DrawProp(me, ps, "_SpecSize");
            EndGroup();

            BeginGroup("Rim Light");
            bool rim = DrawKeywordToggle(me, ps, m, "_RIM", "_RimToggle", "Enable Rim");
            if (rim) { DrawProp(me, ps, "_RimColor"); DrawProp(me, ps, "_RimPower"); DrawProp(me, ps, "_RimStrength"); }
            EndKeywordToggle(rim);
            EndGroup();

            BeginGroup("Emission");
            bool em = DrawKeywordToggle(me, ps, m, "_EMISSION", "_EmissionToggle", "Enable Emission");
            if (em) { DrawProp(me, ps, "_EmissionMap"); DrawProp(me, ps, "_Emission"); }
            EndKeywordToggle(em);
            EndGroup();
        }
    }
}
#endif
