// =============================================================================
//  SkyGUI.cs  —  Stylized Toon World Kit / P2 Environment
// -----------------------------------------------------------------------------
//  ShaderGUI cho StylizedSky.shader.
// =============================================================================
#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

namespace StylizedToonWorldKit.Editor
{
    public class SkyGUI : StylizedShaderGUIBase
    {
        protected override void DrawProperties(MaterialEditor me, MaterialProperty[] ps, Material m)
        {
            EditorGUILayout.HelpBox("Gắn vào DOME MESH (quả cầu lật mặt trong), KHÔNG phải slot Skybox. Mặt trời lấy theo Directional Light chính.", MessageType.Info);

            BeginGroup("Sky Gradient — Day");
            DrawProp(me, ps, "_HorizonDay");
            DrawProp(me, ps, "_MidDay");
            DrawProp(me, ps, "_ZenithDay");
            EndGroup();

            BeginGroup("Sky Gradient — Night");
            DrawProp(me, ps, "_HorizonNight");
            DrawProp(me, ps, "_MidNight");
            DrawProp(me, ps, "_ZenithNight");
            EndGroup();

            BeginGroup("Gradient Shape");
            DrawProp(me, ps, "_GradientPower");
            DrawProp(me, ps, "_HorizonSharp");
            EndGroup();

            BeginGroup("Sun");
            DrawProp(me, ps, "_SunColor");
            DrawProp(me, ps, "_SunSize");
            DrawProp(me, ps, "_SunHalo");
            DrawProp(me, ps, "_SunHaloStrength");
            EndGroup();

            BeginGroup("Clouds");
            bool clouds = DrawKeywordToggle(me, ps, m, "_CLOUDS", "_CloudsToggle", "Enable Clouds");
            if (clouds)
            {
                DrawProp(me, ps, "_CloudColor");
                DrawProp(me, ps, "_CloudShadow");
                DrawProp(me, ps, "_CloudScale");
                DrawProp(me, ps, "_CloudSpeed");
                DrawProp(me, ps, "_CloudCover");
                DrawProp(me, ps, "_CloudSharp");
                DrawProp(me, ps, "_CloudHeight");
            }
            EndKeywordToggle(clouds);
            EndGroup();
        }
    }
}
#endif
