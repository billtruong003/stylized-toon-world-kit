// =============================================================================
//  AnimeEyeGUI.cs  —  Stylized Toon World Kit / P5 Anime NPR
// -----------------------------------------------------------------------------
//  ShaderGUI cho AnimeEye.shader.
// =============================================================================
#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

namespace StylizedToonWorldKit.Editor
{
    public class AnimeEyeGUI : StylizedShaderGUIBase
    {
        protected override void DrawProperties(MaterialEditor me, MaterialProperty[] ps, Material m)
        {
            BeginGroup("Sclera");
            DrawProp(me, ps, "_BaseMap");
            DrawProp(me, ps, "_BaseColor");
            EndGroup();

            BeginGroup("Iris (Parallax)");
            DrawProp(me, ps, "_IrisMap");
            DrawProp(me, ps, "_IrisColor");
            DrawProp(me, ps, "_IrisRadius");
            DrawProp(me, ps, "_IrisDepth");
            DrawProp(me, ps, "_ParallaxScale");
            EditorGUILayout.HelpBox("Cần mesh có tangent + UV mắt căn tâm (0.5,0.5).", MessageType.Info);
            EndGroup();

            BeginGroup("Pupil & Limbal");
            DrawProp(me, ps, "_PupilColor");
            DrawProp(me, ps, "_PupilSize");
            DrawProp(me, ps, "_LimbalColor");
            DrawProp(me, ps, "_LimbalWidth");
            EndGroup();

            BeginGroup("Corneal Highlight");
            DrawProp(me, ps, "_HighlightColor");
            DrawProp(me, ps, "_HighlightPos");
            DrawProp(me, ps, "_HighlightSize");
            EndGroup();

            BeginGroup("Lighting");
            DrawProp(me, ps, "_ShadowTint");
            DrawProp(me, ps, "_RampSteps");
            DrawProp(me, ps, "_RampSmooth");
            DrawProp(me, ps, "_GIStrength");
            EndGroup();
        }
    }
}
#endif
