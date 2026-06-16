// =============================================================================
//  TeleportGUI.cs  —  Stylized Toon World Kit / P3 VFX
// -----------------------------------------------------------------------------
//  ShaderGUI cho StylizedTeleport.shader.
// =============================================================================
#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

namespace StylizedToonWorldKit.Editor
{
    public class TeleportGUI : StylizedShaderGUIBase
    {
        protected override void DrawProperties(MaterialEditor me, MaterialProperty[] ps, Material m)
        {
            BeginGroup("Build");
            DrawProp(me, ps, "_BaseColor");
            DrawProp(me, ps, "_Progress");
            DrawProp(me, ps, "_Axis");
            DrawProp(me, ps, "_WorldMin");
            DrawProp(me, ps, "_WorldMax");
            EndGroup();

            BeginGroup("Front Glow");
            DrawProp(me, ps, "_EdgeColor");
            DrawProp(me, ps, "_EdgeWidth");
            EndGroup();

            BeginGroup("Scanline");
            DrawProp(me, ps, "_ScanDensity");
            DrawProp(me, ps, "_ScanSpeed");
            DrawProp(me, ps, "_ScanSharp");
            EndGroup();

            BeginGroup("Energy Noise");
            DrawProp(me, ps, "_NoiseScale");
            DrawProp(me, ps, "_NoiseSpeed");
            DrawProp(me, ps, "_Fresnel");
            DrawProp(me, ps, "_Alpha");
            EndGroup();

            DrawBlendStateGroup(me, ps, true);
        }
    }
}
#endif
