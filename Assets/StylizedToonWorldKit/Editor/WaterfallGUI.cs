// =============================================================================
//  WaterfallGUI.cs  —  Stylized Toon World Kit / P2 Environment
// -----------------------------------------------------------------------------
//  ShaderGUI cho StylizedWaterfall.shader.
// =============================================================================
#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

namespace StylizedToonWorldKit.Editor
{
    public class WaterfallGUI : StylizedShaderGUIBase
    {
        protected override void DrawProperties(MaterialEditor me, MaterialProperty[] ps, Material m)
        {
            EditorGUILayout.HelpBox("Mesh dọc, uv.y: đỉnh = 1, đáy = 0. Bật URP Depth Texture cho mist/soft fade chân thác.", MessageType.Info);

            BeginGroup("Water Color");
            DrawProp(me, ps, "_TopColor");
            DrawProp(me, ps, "_BottomColor");
            DrawProp(me, ps, "_LightTint");
            EndGroup();

            BeginGroup("Flow");
            DrawProp(me, ps, "_FlowSpeed");
            DrawProp(me, ps, "_FlowScale");
            DrawProp(me, ps, "_Distortion");
            EndGroup();

            BeginGroup("Foam");
            DrawProp(me, ps, "_FoamColor");
            DrawProp(me, ps, "_FoamScale");
            DrawProp(me, ps, "_FoamCutoff");
            DrawProp(me, ps, "_FoamSharp");
            DrawProp(me, ps, "_TopFoam");
            DrawProp(me, ps, "_BottomFoam");
            EndGroup();

            BeginGroup("Edges and Mist");
            DrawProp(me, ps, "_FresnelColor");
            DrawProp(me, ps, "_FresnelPower");
            DrawProp(me, ps, "_SoftFade");
            DrawProp(me, ps, "_Alpha");
            EndGroup();

            BeginGroup("Render State");
            DrawProp(me, ps, "_Cull");
            EndGroup();
        }
    }
}
#endif
