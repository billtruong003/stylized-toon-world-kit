// =============================================================================
//  HairAnisoGUI.cs  —  Stylized Toon World Kit / P1
// -----------------------------------------------------------------------------
//  ShaderGUI cho StylizedHairAniso.shader.
// =============================================================================
#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

namespace StylizedToonWorldKit.Editor
{
    public class HairAnisoGUI : StylizedShaderGUIBase
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

            BeginGroup("Anisotropic Highlight");
            DrawProp(me, ps, "_ShiftMap");
            DrawProp(me, ps, "_ShiftStrength");
            DrawProp(me, ps, "_SpecColor1");
            DrawProp(me, ps, "_SpecShift1");
            DrawProp(me, ps, "_SpecExp1");
            DrawProp(me, ps, "_SpecColor2");
            DrawProp(me, ps, "_SpecShift2");
            DrawProp(me, ps, "_SpecExp2");
            EditorGUILayout.HelpBox("Cần mesh có tangent (UV liên tục) để highlight chạy đúng theo sợi tóc.", MessageType.Info);
            EndGroup();
        }
    }
}
#endif
