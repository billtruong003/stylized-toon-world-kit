// =============================================================================
//  MagicFlowGUI.cs  —  Stylized Toon World Kit / P3 VFX
// -----------------------------------------------------------------------------
//  ShaderGUI cho StylizedMagicFlow.shader.
// =============================================================================
#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

namespace StylizedToonWorldKit.Editor
{
    public class MagicFlowGUI : StylizedShaderGUIBase
    {
        protected override void DrawProperties(MaterialEditor me, MaterialProperty[] ps, Material m)
        {
            BeginGroup("Color");
            DrawProp(me, ps, "_ColorLow");
            DrawProp(me, ps, "_ColorHigh");
            DrawProp(me, ps, "_MainMap");
            DrawProp(me, ps, "_FlowMap");
            EndGroup();

            BeginGroup("Flow");
            DrawProp(me, ps, "_FlowSpeed");
            DrawProp(me, ps, "_FlowStrength");
            DrawProp(me, ps, "_NoiseScale");
            DrawProp(me, ps, "_Intensity");
            EndGroup();

            bool polar = DrawKeywordToggle(me, ps, m, "_POLAR", "_UsePolar", "Polar UV (magic circle)");
            if (polar) DrawProp(me, ps, "_Spin");
            EndKeywordToggle(polar);

            BeginGroup("Overall");
            DrawProp(me, ps, "_Fresnel");
            DrawProp(me, ps, "_Alpha");
            EndGroup();

            DrawBlendStateGroup(me, ps, true);
        }
    }
}
#endif
