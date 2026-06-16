// =============================================================================
//  TerrainGUI.cs  —  Stylized Toon World Kit / P2 Environment
// -----------------------------------------------------------------------------
//  ShaderGUI cho StylizedTerrain.shader.
// =============================================================================
#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

namespace StylizedToonWorldKit.Editor
{
    public class TerrainGUI : StylizedShaderGUIBase
    {
        protected override void DrawProperties(MaterialEditor me, MaterialProperty[] ps, Material m)
        {
            BeginGroup("Ground Layer");
            DrawProp(me, ps, "_GroundMap");
            DrawProp(me, ps, "_GroundColor");
            DrawProp(me, ps, "_GroundScale");
            EndGroup();

            BeginGroup("Cliff Layer (Triplanar)");
            DrawProp(me, ps, "_CliffMap");
            DrawProp(me, ps, "_CliffColor");
            DrawProp(me, ps, "_CliffScale");
            DrawProp(me, ps, "_SlopeThreshold");
            DrawProp(me, ps, "_SlopeSharp");
            DrawProp(me, ps, "_TriplanarSharp");
            EndGroup();

            BeginGroup("Peak Layer");
            bool peak = DrawKeywordToggle(me, ps, m, "_PEAK_LAYER", "_PeakToggle", "Enable Peak Layer");
            if (peak)
            {
                DrawProp(me, ps, "_PeakMap");
                DrawProp(me, ps, "_PeakColor");
                DrawProp(me, ps, "_PeakScale");
                DrawProp(me, ps, "_PeakMinHeight");
                DrawProp(me, ps, "_PeakMaxHeight");
                DrawProp(me, ps, "_PeakSharp");
                DrawProp(me, ps, "_PeakSlopeBias");
            }
            EndKeywordToggle(peak);
            EndGroup();

            BeginGroup("Macro Variation");
            DrawProp(me, ps, "_MacroStrength");
            DrawProp(me, ps, "_MacroScale");
            EndGroup();

            BeginGroup("Lighting");
            DrawProp(me, ps, "_ShadowTint");
            DrawProp(me, ps, "_RampSteps");
            DrawProp(me, ps, "_RampSmooth");
            DrawProp(me, ps, "_GIStrength");
            DrawProp(me, ps, "_Occlusion");
            EndGroup();
        }
    }
}
#endif
