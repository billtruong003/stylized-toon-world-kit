// =============================================================================
//  StylizedToonTemplateGUI.cs  —  Stylized Toon World Kit / P0 reference
// -----------------------------------------------------------------------------
//  ShaderGUI mẫu cho StylizedToon_Template.shader. Minh hoạ cách kế thừa
//  StylizedShaderGUIBase: chia nhóm property + ẩn/hiện theo strength.
//  Mọi shader pack về sau làm theo khuôn này (1 GUI / shader — nguyên tắc #3).
// =============================================================================

#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

namespace StylizedToonWorldKit.Editor
{
    public class StylizedToonTemplateGUI : StylizedShaderGUIBase
    {
        protected override void DrawProperties(MaterialEditor me, MaterialProperty[] ps, Material m)
        {
            BeginGroup("Base");
            DrawProp(me, ps, "_BaseMap");
            DrawProp(me, ps, "_BaseColor");
            DrawProp(me, ps, "_Emission");
            EndGroup();

            BeginGroup("Cel Shading");
            DrawProp(me, ps, "_ShadowTint");
            DrawProp(me, ps, "_RampSteps");
            DrawProp(me, ps, "_RampSmooth");
            DrawProp(me, ps, "_ShadowThresh");
            DrawProp(me, ps, "_GIStrength");
            EndGroup();

            BeginGroup("Specular");
            DrawProp(me, ps, "_SpecStrength");
            DrawProp(me, ps, "_SpecSize");
            EndGroup();

            BeginGroup("Rim Light");
            DrawProp(me, ps, "_RimColor");
            DrawProp(me, ps, "_RimPower");
            DrawProp(me, ps, "_RimStrength");
            EndGroup();
        }
    }
}
#endif
