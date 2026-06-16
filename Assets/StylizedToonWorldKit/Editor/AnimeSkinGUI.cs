// =============================================================================
//  AnimeSkinGUI.cs  —  Stylized Toon World Kit / P5 Anime NPR
// -----------------------------------------------------------------------------
//  ShaderGUI cho AnimeSkinSSS.shader.
// =============================================================================
#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

namespace StylizedToonWorldKit.Editor
{
    public class AnimeSkinGUI : StylizedShaderGUIBase
    {
        protected override void DrawProperties(MaterialEditor me, MaterialProperty[] ps, Material m)
        {
            BeginGroup("Base");
            DrawProp(me, ps, "_BaseMap");
            DrawProp(me, ps, "_BaseColor");
            EndGroup();

            bool nrm = DrawKeywordToggle(me, ps, m, "_NORMALMAP", "_NormalMapToggle", "Normal Map");
            if (nrm)
            {
                DrawProp(me, ps, "_BumpMap");
                DrawProp(me, ps, "_BumpScale");
            }
            EndKeywordToggle(nrm);

            BeginGroup("Cel Shading");
            DrawProp(me, ps, "_RampSteps");
            DrawProp(me, ps, "_RampSmooth");
            DrawProp(me, ps, "_GIStrength");
            DrawProp(me, ps, "_Occlusion");
            EndGroup();

            BeginGroup("Subsurface (fake)");
            DrawProp(me, ps, "_SSSColor");
            DrawProp(me, ps, "_SSSStrength");
            DrawProp(me, ps, "_ScatterWidth");
            EndGroup();

            bool blush = DrawKeywordToggle(me, ps, m, "_BLUSH", "_BlushToggle", "Blush");
            if (blush)
            {
                DrawProp(me, ps, "_BlushMap");
                DrawProp(me, ps, "_BlushColor");
                DrawProp(me, ps, "_BlushStrength");
            }
            EndKeywordToggle(blush);

            BeginGroup("Sheen");
            DrawProp(me, ps, "_SpecColor2");
            DrawProp(me, ps, "_SpecStrength");
            DrawProp(me, ps, "_SpecSize");
            EndGroup();

            bool rim = DrawKeywordToggle(me, ps, m, "_RIM", "_RimToggle", "Rim Light");
            if (rim)
            {
                DrawProp(me, ps, "_RimColor");
                DrawProp(me, ps, "_RimPower");
                DrawProp(me, ps, "_RimStrength");
            }
            EndKeywordToggle(rim);
        }
    }
}
#endif
