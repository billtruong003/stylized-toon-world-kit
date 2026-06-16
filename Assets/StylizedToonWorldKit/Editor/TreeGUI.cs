// =============================================================================
//  TreeGUI.cs  —  Stylized Toon World Kit / P2 Environment
// -----------------------------------------------------------------------------
//  ShaderGUI cho StylizedTree.shader.
// =============================================================================
#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

namespace StylizedToonWorldKit.Editor
{
    public class TreeGUI : StylizedShaderGUIBase
    {
        protected override void DrawProperties(MaterialEditor me, MaterialProperty[] ps, Material m)
        {
            BeginGroup("Base");
            DrawProp(me, ps, "_BaseMap");
            DrawProp(me, ps, "_BaseColor");
            DrawProp(me, ps, "_TipColor");
            DrawProp(me, ps, "_TipBlend");
            EndGroup();

            BeginGroup("Alpha Edge");
            bool dither = DrawKeywordToggle(me, ps, m, "_ALPHADITHER", "_DitherToggle", "Dither Alpha Edge");
            EndKeywordToggle(dither);
            DrawProp(me, ps, "_Cutoff");
            EditorGUILayout.HelpBox("Dither = khử răng cưa mép lá bằng nhiễu màn hình (mịn hơn clip cứng).", MessageType.Info);
            EndGroup();

            BeginGroup("Wind");
            DrawProp(me, ps, "_WindDir");
            DrawProp(me, ps, "_TrunkSway");
            DrawProp(me, ps, "_LeafFlutter");
            DrawProp(me, ps, "_WindSpeed");
            DrawProp(me, ps, "_WindFreq");
            bool vc = DrawKeywordToggle(me, ps, m, "_VERTEXCOLOR_MASK", "_VCMaskToggle", "Use Vertex Color.a as Wind Mask");
            EndKeywordToggle(vc);
            EditorGUILayout.HelpBox("Bật nếu mesh cây vẽ wind weight ở vertex color.a; tắt thì dùng uv.y làm mask.", MessageType.Info);
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
