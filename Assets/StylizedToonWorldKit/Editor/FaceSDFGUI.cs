// =============================================================================
//  FaceSDFGUI.cs  —  Stylized Toon World Kit / P5 Anime NPR
// -----------------------------------------------------------------------------
//  ShaderGUI cho AnimeFaceSDF.shader.
// =============================================================================
#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

namespace StylizedToonWorldKit.Editor
{
    public class FaceSDFGUI : StylizedShaderGUIBase
    {
        protected override void DrawProperties(MaterialEditor me, MaterialProperty[] ps, Material m)
        {
            BeginGroup("Base");
            DrawProp(me, ps, "_BaseMap");
            DrawProp(me, ps, "_BaseColor");
            EndGroup();

            BeginGroup("SDF Face Shadow");
            DrawProp(me, ps, "_SDFShadowMap");
            DrawProp(me, ps, "_FaceShadowTint");
            DrawProp(me, ps, "_SDFSoftness");
            DrawProp(me, ps, "_SDFFlip");
            DrawProp(me, ps, "_GIStrength");
            EditorGUILayout.HelpBox(
                "Mesh mặt phải quay +Z (forward), +X (right), không scale lệch. SDF map vẽ cho đèn từ TRÁI; shader tự mirror khi đèn sang phải. Additional light bỏ qua (mặt chỉ theo key light).",
                MessageType.Info);
            EndGroup();

            bool rim = DrawKeywordToggle(me, ps, m, "_RIM", "_RimToggle", "Rim Light");
            if (rim)
            {
                DrawProp(me, ps, "_RimColor");
                DrawProp(me, ps, "_RimPower");
                DrawProp(me, ps, "_RimStrength");
            }
            EndKeywordToggle(rim);

            bool em = DrawKeywordToggle(me, ps, m, "_EMISSION", "_EmissionToggle", "Emission");
            if (em)
            {
                DrawProp(me, ps, "_EmissionMap");
                DrawProp(me, ps, "_Emission");
            }
            EndKeywordToggle(em);
        }
    }
}
#endif
