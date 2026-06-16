// =============================================================================
//  AnimeBodyGUI.cs  —  Stylized Toon World Kit / P5 Anime NPR
// -----------------------------------------------------------------------------
//  ShaderGUI cho AnimeCharacterBody.shader.
// =============================================================================
#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

namespace StylizedToonWorldKit.Editor
{
    public class AnimeBodyGUI : StylizedShaderGUIBase
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
            DrawProp(me, ps, "_ShadowTint");
            DrawProp(me, ps, "_RampSteps");
            DrawProp(me, ps, "_RampSmooth");
            DrawProp(me, ps, "_GIStrength");
            DrawProp(me, ps, "_Occlusion");
            EndGroup();

            bool ilm = DrawKeywordToggle(me, ps, m, "_ILM", "_ILMToggle", "ILM Mask (R spec / G AO)");
            if (ilm) DrawProp(me, ps, "_ILMMap");
            EndKeywordToggle(ilm);

            BeginGroup("Specular");
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
