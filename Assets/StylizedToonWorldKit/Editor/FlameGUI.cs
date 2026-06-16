// =============================================================================
//  FlameGUI.cs  —  Stylized Toon World Kit / P3 VFX
// -----------------------------------------------------------------------------
//  ShaderGUI cho StylizedFlame.shader.
// =============================================================================
#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

namespace StylizedToonWorldKit.Editor
{
    public class FlameGUI : StylizedShaderGUIBase
    {
        protected override void DrawProperties(MaterialEditor me, MaterialProperty[] ps, Material m)
        {
            BeginGroup("Color Ramp");
            DrawProp(me, ps, "_ColorInner");
            DrawProp(me, ps, "_ColorMid");
            DrawProp(me, ps, "_ColorOuter");
            EndGroup();

            bool flip = DrawKeywordToggle(me, ps, m, "_FLIPBOOK", "_UseFlipbook", "Use Flipbook");
            if (flip)
            {
                BeginGroup("Flipbook");
                DrawProp(me, ps, "_FlameMap");
                DrawProp(me, ps, "_Cols");
                DrawProp(me, ps, "_Rows");
                DrawProp(me, ps, "_FPS");
                EndGroup();
            }
            else
            {
                BeginGroup("Procedural Flame");
                DrawProp(me, ps, "_NoiseScale");
                DrawProp(me, ps, "_ScrollSpeed");
                DrawProp(me, ps, "_Distortion");
                DrawProp(me, ps, "_FlameHeight");
                DrawProp(me, ps, "_FlameSharp");
                EndGroup();
            }
            EndKeywordToggle(flip);

            BeginGroup("Overall");
            DrawProp(me, ps, "_Alpha");
            EndGroup();

            DrawBlendStateGroup(me, ps, true);
        }
    }
}
#endif
