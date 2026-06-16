// =============================================================================
//  LiquidGUI.cs  —  Stylized Toon World Kit / P4 Surface
// -----------------------------------------------------------------------------
//  ShaderGUI cho StylizedLiquid.shader.
// =============================================================================
#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

namespace StylizedToonWorldKit.Editor
{
    public class LiquidGUI : StylizedShaderGUIBase
    {
        protected override void DrawProperties(MaterialEditor me, MaterialProperty[] ps, Material m)
        {
            BeginGroup("Body Color");
            DrawProp(me, ps, "_ShallowColor");
            DrawProp(me, ps, "_DeepColor");
            DrawProp(me, ps, "_DepthPower");
            EndGroup();

            BeginGroup("Fill Level");
            DrawProp(me, ps, "_FillLevel");
            DrawProp(me, ps, "_WaveAmp");
            DrawProp(me, ps, "_WaveFreq");
            DrawProp(me, ps, "_WaveSpeed");
            EditorGUILayout.HelpBox("Fill Level cắt theo trục Y object-space của mesh.", MessageType.Info);
            EndGroup();

            BeginGroup("Surface Band");
            DrawProp(me, ps, "_SurfaceColor");
            DrawProp(me, ps, "_SurfaceBand");
            DrawProp(me, ps, "_SurfaceStrength");
            EndGroup();

            BeginGroup("Bubbles");
            bool b = DrawKeywordToggle(me, ps, m, "_BUBBLE", "_BubbleToggle", "Enable Bubbles");
            if (b)
            {
                DrawProp(me, ps, "_BubbleColor");
                DrawProp(me, ps, "_BubbleScale");
                DrawProp(me, ps, "_BubbleSpeed");
                DrawProp(me, ps, "_BubbleStrength");
            }
            EndKeywordToggle(b);
            EndGroup();

            BeginGroup("Rim and Lighting");
            DrawProp(me, ps, "_RimColor");
            DrawProp(me, ps, "_RimPower");
            DrawProp(me, ps, "_RimStrength");
            DrawProp(me, ps, "_GIStrength");
            EndGroup();

            BeginGroup("Render State");
            DrawProp(me, ps, "_Alpha");
            DrawProp(me, ps, "_Cull");
            EndGroup();
        }
    }
}
#endif
