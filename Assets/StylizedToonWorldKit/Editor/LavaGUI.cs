// =============================================================================
//  LavaGUI.cs  —  Stylized Toon World Kit / P4 Surface
// -----------------------------------------------------------------------------
//  ShaderGUI cho StylizedLava.shader.
// =============================================================================
#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

namespace StylizedToonWorldKit.Editor
{
    public class LavaGUI : StylizedShaderGUIBase
    {
        protected override void DrawProperties(MaterialEditor me, MaterialProperty[] ps, Material m)
        {
            BeginGroup("Crust");
            DrawProp(me, ps, "_CrustColor");
            DrawProp(me, ps, "_CrustColor2");
            DrawProp(me, ps, "_ShadowTint");
            DrawProp(me, ps, "_RampSteps");
            DrawProp(me, ps, "_RampSmooth");
            DrawProp(me, ps, "_GIStrength");
            EndGroup();

            BeginGroup("Lava");
            DrawProp(me, ps, "_LavaLow");
            DrawProp(me, ps, "_LavaHigh");
            DrawProp(me, ps, "_CrustCoverage");
            DrawProp(me, ps, "_CrustSharpness");
            DrawProp(me, ps, "_EmissionStrength");
            DrawProp(me, ps, "_PulseSpeed");
            EndGroup();

            BeginGroup("Flow");
            DrawProp(me, ps, "_NoiseScale");
            DrawProp(me, ps, "_FlowDir");
            DrawProp(me, ps, "_FlowSpeed");
            EndGroup();

            BeginGroup("Render State");
            DrawProp(me, ps, "_Cull");
            EndGroup();
        }
    }
}
#endif
