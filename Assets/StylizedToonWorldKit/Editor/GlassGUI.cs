// =============================================================================
//  GlassGUI.cs  —  Stylized Toon World Kit / P4 Surface
// -----------------------------------------------------------------------------
//  ShaderGUI cho StylizedGlass.shader.
// =============================================================================
#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

namespace StylizedToonWorldKit.Editor
{
    public class GlassGUI : StylizedShaderGUIBase
    {
        protected override void DrawProperties(MaterialEditor me, MaterialProperty[] ps, Material m)
        {
            BeginGroup("Body");
            DrawProp(me, ps, "_TintColor");
            EditorGUILayout.HelpBox("Cần bật URP Opaque Texture cho refraction/frost.", MessageType.Info);
            EndGroup();

            BeginGroup("Refraction");
            DrawProp(me, ps, "_RefractStrength");
            bool nm = DrawKeywordToggle(me, ps, m, "_NORMALMAP", "_NormalMapToggle", "Use Normal Map");
            if (nm)
            {
                DrawProp(me, ps, "_BumpMap");
                DrawProp(me, ps, "_BumpScale");
            }
            EndKeywordToggle(nm);
            EndGroup();

            BeginGroup("Frosted");
            bool fr = DrawKeywordToggle(me, ps, m, "_FROSTED", "_FrostedToggle", "Enable Frosted");
            if (fr)
            {
                DrawProp(me, ps, "_FrostAmount");
                DrawProp(me, ps, "_FrostJitter");
                DrawProp(me, ps, "_FrostNoiseScale");
            }
            EndKeywordToggle(fr);
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
            DrawProp(me, ps, "_Alpha");
            DrawProp(me, ps, "_Cull");
            EndGroup();
        }
    }
}
#endif
