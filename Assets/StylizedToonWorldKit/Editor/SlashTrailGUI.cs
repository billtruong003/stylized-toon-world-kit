// =============================================================================
//  SlashTrailGUI.cs  —  Stylized Toon World Kit / P3 VFX
// -----------------------------------------------------------------------------
//  ShaderGUI cho StylizedSlashTrail.shader.
// =============================================================================
#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

namespace StylizedToonWorldKit.Editor
{
    public class SlashTrailGUI : StylizedShaderGUIBase
    {
        protected override void DrawProperties(MaterialEditor me, MaterialProperty[] ps, Material m)
        {
            BeginGroup("Color");
            DrawProp(me, ps, "_BaseMap");
            DrawProp(me, ps, "_ColorHead");
            DrawProp(me, ps, "_ColorTail");
            DrawProp(me, ps, "_GradientPow");
            EndGroup();

            BeginGroup("Shape");
            DrawProp(me, ps, "_SoftEdge");
            DrawProp(me, ps, "_Trim");
            DrawProp(me, ps, "_HeadTrim");
            EndGroup();

            BeginGroup("Distortion");
            DrawProp(me, ps, "_Distortion");
            DrawProp(me, ps, "_DistScale");
            DrawProp(me, ps, "_DistSpeed");
            EndGroup();

            BeginGroup("Overall");
            DrawProp(me, ps, "_Alpha");
            EndGroup();

            DrawBlendStateGroup(me, ps, true);
        }
    }
}
#endif
