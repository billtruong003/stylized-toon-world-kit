// =============================================================================
//  DissolveGUI.cs  —  Stylized Toon World Kit / P3 VFX
// -----------------------------------------------------------------------------
//  ShaderGUI cho StylizedDissolve.shader.
// =============================================================================
#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

namespace StylizedToonWorldKit.Editor
{
    public class DissolveGUI : StylizedShaderGUIBase
    {
        protected override void DrawProperties(MaterialEditor me, MaterialProperty[] ps, Material m)
        {
            BeginGroup("Base");
            DrawProp(me, ps, "_BaseMap");
            DrawProp(me, ps, "_BaseColor");
            EndGroup();

            BeginGroup("Cel Shading");
            DrawProp(me, ps, "_ShadowTint");
            DrawProp(me, ps, "_RampSteps");
            DrawProp(me, ps, "_RampSmooth");
            DrawProp(me, ps, "_GIStrength");
            EndGroup();

            BeginGroup("Dissolve");
            DrawProp(me, ps, "_Dissolve");
            bool useTex = DrawKeywordToggle(me, ps, m, "_NOISEMAP", "_UseNoiseMap", "Use Noise Texture");
            if (useTex) DrawProp(me, ps, "_NoiseMap");
            else { DrawProp(me, ps, "_NoiseScale"); DrawProp(me, ps, "_NoiseOctaves"); }
            EndKeywordToggle(useTex);
            bool world = DrawKeywordToggle(me, ps, m, "_DISSOLVE_WORLD", "_DissolveWorld", "World-space Noise");
            EndKeywordToggle(world);
            EndGroup();

            BeginGroup("Edge Glow");
            DrawProp(me, ps, "_EdgeWidth");
            DrawProp(me, ps, "_EdgeColor");
            DrawProp(me, ps, "_EdgeStrength");
            DrawProp(me, ps, "_Emission");
            EndGroup();

            DrawBlendStateGroup(me, ps, false);
        }
    }
}
#endif
