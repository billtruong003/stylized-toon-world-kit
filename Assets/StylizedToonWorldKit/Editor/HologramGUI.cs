// =============================================================================
//  HologramGUI.cs  —  Stylized Toon World Kit / P3 VFX
// -----------------------------------------------------------------------------
//  ShaderGUI cho StylizedHologram.shader.
// =============================================================================
#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

namespace StylizedToonWorldKit.Editor
{
    public class HologramGUI : StylizedShaderGUIBase
    {
        protected override void DrawProperties(MaterialEditor me, MaterialProperty[] ps, Material m)
        {
            BeginGroup("Base");
            DrawProp(me, ps, "_BaseMap");
            DrawProp(me, ps, "_Color");
            DrawProp(me, ps, "_FresnelColor");
            DrawProp(me, ps, "_FresnelPower");
            EndGroup();

            BeginGroup("Scanlines");
            DrawProp(me, ps, "_ScanDensity");
            DrawProp(me, ps, "_ScanSpeed");
            DrawProp(me, ps, "_ScanSharp");
            DrawProp(me, ps, "_ScanStrength");
            EndGroup();

            BeginGroup("Glitch");
            DrawProp(me, ps, "_GlitchAmount");
            DrawProp(me, ps, "_GlitchSpeed");
            DrawProp(me, ps, "_GlitchBands");
            EndGroup();

            BeginGroup("Flicker");
            DrawProp(me, ps, "_Flicker");
            DrawProp(me, ps, "_FlickerSpeed");
            DrawProp(me, ps, "_Alpha");
            EndGroup();

            DrawBlendStateGroup(me, ps, true);
        }
    }
}
#endif
