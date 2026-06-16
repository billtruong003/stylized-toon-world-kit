// =============================================================================
//  OutlineInvertedHullGUI.cs  —  Stylized Toon World Kit / P1
// -----------------------------------------------------------------------------
//  ShaderGUI cho StylizedOutline_InvertedHull.shader.
// =============================================================================
#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

namespace StylizedToonWorldKit.Editor
{
    public class OutlineInvertedHullGUI : StylizedShaderGUIBase
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

            BeginGroup("Specular");
            DrawProp(me, ps, "_SpecStrength");
            DrawProp(me, ps, "_SpecSize");
            EndGroup();

            BeginGroup("Outline (inverted hull)");
            DrawProp(me, ps, "_OutlineColor");
            DrawProp(me, ps, "_OutlineWidth");
            // _OUTLINE_SCREENSPACE keyword: bật = dày đều theo pixel, tắt = theo world
            bool ss = DrawKeywordToggle(me, ps, m, "_OUTLINE_SCREENSPACE", "_OutlineScreen", "Width = Screen-space");
            EndKeywordToggle(ss);
            EditorGUILayout.HelpBox(
                "Inverted-hull thêm 1 draw/material (có thể phá batch). Mobile/VR/cảnh nhiều object cùng material vẫn instancing tốt. Muốn giữ batch toàn cảnh → dùng Screen-Space Outline (Renderer Feature).",
                MessageType.Info);
            EndGroup();
        }
    }
}
#endif
