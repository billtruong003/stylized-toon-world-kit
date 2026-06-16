// =============================================================================
//  CrystalGUI.cs  —  Stylized Toon World Kit / P4 Surface
// -----------------------------------------------------------------------------
//  ShaderGUI cho StylizedCrystal.shader.
// =============================================================================
#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

namespace StylizedToonWorldKit.Editor
{
    public class CrystalGUI : StylizedShaderGUIBase
    {
        protected override void DrawProperties(MaterialEditor me, MaterialProperty[] ps, Material m)
        {
            BeginGroup("Body");
            DrawProp(me, ps, "_BaseColor");
            DrawProp(me, ps, "_Saturation");
            EditorGUILayout.HelpBox("Cần bật URP Opaque Texture + Depth Texture.", MessageType.Info);
            EndGroup();

            BeginGroup("Refraction");
            DrawProp(me, ps, "_RefractStrength");
            bool disp = DrawKeywordToggle(me, ps, m, "_DISPERSION", "_DispersionToggle", "Enable Dispersion");
            if (disp) DrawProp(me, ps, "_Dispersion");
            EndKeywordToggle(disp);
            EndGroup();

            BeginGroup("Inner Glow");
            DrawProp(me, ps, "_InnerColor");
            DrawProp(me, ps, "_InnerStrength");
            DrawProp(me, ps, "_FacetScale");
            DrawProp(me, ps, "_FacetStrength");
            EndGroup();

            BeginGroup("Fresnel and Specular");
            DrawProp(me, ps, "_FresnelColor");
            DrawProp(me, ps, "_FresnelPower");
            DrawProp(me, ps, "_FresnelStrength");
            DrawProp(me, ps, "_SpecColor2");
            DrawProp(me, ps, "_SpecStrength");
            DrawProp(me, ps, "_SpecSize");
            EndGroup();

            BeginGroup("Render State");
            DrawProp(me, ps, "_DepthFade");
            DrawProp(me, ps, "_Alpha");
            DrawProp(me, ps, "_Cull");
            EndGroup();
        }
    }
}
#endif
