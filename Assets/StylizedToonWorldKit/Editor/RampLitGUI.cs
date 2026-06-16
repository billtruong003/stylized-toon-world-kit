// =============================================================================
//  RampLitGUI.cs  —  Stylized Toon World Kit / P1
// -----------------------------------------------------------------------------
//  ShaderGUI cho StylizedRampLit.shader.
// =============================================================================
#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

namespace StylizedToonWorldKit.Editor
{
    public class RampLitGUI : StylizedShaderGUIBase
    {
        protected override void DrawProperties(MaterialEditor me, MaterialProperty[] ps, Material m)
        {
            BeginGroup("Base");
            DrawProp(me, ps, "_BaseMap");
            DrawProp(me, ps, "_BaseColor");
            DrawProp(me, ps, "_Emission");
            EndGroup();

            BeginGroup("Ramp (1D LUT)");
            DrawProp(me, ps, "_RampMap");
            DrawProp(me, ps, "_GIStrength");
            EditorGUILayout.HelpBox("Ramp đọc theo trục U = half-lambert (trái = tối, phải = sáng). Vẽ gradient màu shadow theo ý.", MessageType.Info);
            EndGroup();

            BeginGroup("Occlusion (stylized)");
            DrawProp(me, ps, "_AOMap");
            DrawProp(me, ps, "_AOStrength");
            DrawProp(me, ps, "_AOBands");
            EndGroup();
        }
    }
}
#endif
