// =============================================================================
//  StylizedShaderGUIBase.cs  —  Stylized Toon World Kit / P0 Core
// -----------------------------------------------------------------------------
//  MỤC ĐÍCH: lớp ShaderGUI dùng lại cho MỌI shader trong kit (nguyên tắc #3:
//  custom GUI mỗi shader, nhưng share base để đỡ lặp). Cung cấp:
//    • Vẽ property theo NHÓM có header gập (foldout) — Inspector gọn, rõ.
//    • Toggle keyword (shader_feature) tiện: bật/tắt feature ẩn property thừa.
//    • Render queue / surface (Opaque/Transparent) + culling presets.
//    • Footer thương hiệu + version.
//
//  CÁCH DÙNG: shader con kế thừa, override DrawProperties():
//      public class ToonLitGUI : StylizedShaderGUIBase {
//          protected override void DrawProperties(MaterialEditor me, MaterialProperty[] ps, Material m) {
//              BeginGroup("Base");
//              DrawProp(me, ps, "_BaseMap"); DrawProp(me, ps, "_BaseColor");
//              EndGroup();
//              if (DrawKeywordToggle(me, ps, m, "_RIM", "_RimEnabled", "Rim Light")) {
//                  DrawProp(me, ps, "_RimColor"); DrawProp(me, ps, "_RimPower");
//              }
//          }
//      }
//  Trong .shader:  CustomEditor "StylizedToonWorldKit.Editor.ToonLitGUI"
// =============================================================================

#if UNITY_EDITOR
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

namespace StylizedToonWorldKit.Editor
{
    public abstract class StylizedShaderGUIBase : ShaderGUI
    {
        protected const string KitName = "Stylized Toon World Kit";
        protected const string KitVersion = "0.6.0";

        // Trạng thái foldout lưu theo tên group (giữ giữa các lần repaint).
        private static readonly Dictionary<string, bool> s_Foldouts = new Dictionary<string, bool>();
        private MaterialEditor _editor;
        private MaterialProperty[] _props;
        private Material _target;
        private bool _groupOpen;
        private string _currentGroup;

        // -- Entry point của ShaderGUI -------------------------------------------------
        public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
        {
            _editor = materialEditor;
            _props = properties;
            _target = materialEditor.target as Material;

            DrawHeaderBar();
            EditorGUILayout.Space();

            DrawProperties(materialEditor, properties, _target);

            EditorGUILayout.Space();
            DrawAdvanced(materialEditor);
            DrawFooter();
        }

        // Shader con override để khai báo bố cục property cụ thể.
        protected abstract void DrawProperties(MaterialEditor me, MaterialProperty[] ps, Material m);

        // -- GROUP (foldout) -----------------------------------------------------------
        protected void BeginGroup(string title)
        {
            _currentGroup = title;
            if (!s_Foldouts.ContainsKey(title)) s_Foldouts[title] = true;
            var style = new GUIStyle(EditorStyles.foldoutHeader) { fontStyle = FontStyle.Bold };
            _groupOpen = EditorGUILayout.BeginFoldoutHeaderGroup(s_Foldouts[title], title, style);
            s_Foldouts[title] = _groupOpen;
            if (_groupOpen) EditorGUI.indentLevel++;
        }

        protected void EndGroup()
        {
            if (_groupOpen) EditorGUI.indentLevel--;
            EditorGUILayout.EndFoldoutHeaderGroup();
            EditorGUILayout.Space(2);
        }

        // -- VẼ PROPERTY ---------------------------------------------------------------
        // Bỏ qua nếu group đang đóng hoặc không tìm thấy property (an toàn).
        protected void DrawProp(MaterialEditor me, MaterialProperty[] ps, string name, string label = null)
        {
            if (!_groupOpen && _currentGroup != null) return;
            var p = FindProperty(name, ps, false);
            if (p == null) return;
            me.ShaderProperty(p, label ?? p.displayName);
        }

        // Toggle 1 keyword (shader_feature) + trả trạng thái để ẩn/hiện property phụ.
        protected bool DrawKeywordToggle(MaterialEditor me, MaterialProperty[] ps, Material m,
                                         string keyword, string toggleProp, string label)
        {
            var p = FindProperty(toggleProp, ps, false);
            bool on;
            if (p != null)
            {
                me.ShaderProperty(p, label);
                on = p.floatValue > 0.5f;
            }
            else
            {
                on = m.IsKeywordEnabled(keyword);
                bool newOn = EditorGUILayout.Toggle(label, on);
                if (newOn != on) on = newOn;
            }
            SetKeyword(m, keyword, on);
            if (on) EditorGUI.indentLevel++;
            return on;
        }

        protected void EndKeywordToggle(bool on)
        {
            if (on) EditorGUI.indentLevel--;
        }

        // -- ADVANCED (render state) ---------------------------------------------------
        protected virtual void DrawAdvanced(MaterialEditor me)
        {
            BeginGroup("Advanced / Render State");
            if (_groupOpen)
            {
                me.RenderQueueField();
                me.EnableInstancingField();
                me.DoubleSidedGIField();
            }
            EndGroup();
        }

        // -- BLEND STATE (cho VFX trong suốt) ------------------------------------------
        //  Vẽ nhóm điều khiển blend/zwrite/cull. blend=false (shader opaque) chỉ vẽ Cull.
        protected void DrawBlendStateGroup(MaterialEditor me, MaterialProperty[] ps, bool blend)
        {
            BeginGroup("Render State");
            if (blend)
            {
                DrawProp(me, ps, "_SrcBlend");
                DrawProp(me, ps, "_DstBlend");
                DrawProp(me, ps, "_ZWrite");
            }
            DrawProp(me, ps, "_Cull");
            EndGroup();
        }

        // -- HEADER / FOOTER -----------------------------------------------------------
        private void DrawHeaderBar()
        {
            var rect = EditorGUILayout.GetControlRect(false, 22);
            EditorGUI.DrawRect(rect, new Color(0.10f, 0.12f, 0.16f, 1f));
            var style = new GUIStyle(EditorStyles.boldLabel) { normal = { textColor = new Color(1f, 0.82f, 0.35f) } };
            EditorGUI.LabelField(new Rect(rect.x + 6, rect.y + 2, rect.width, 18), KitName, style);
        }

        private void DrawFooter()
        {
            EditorGUILayout.Space();
            var style = new GUIStyle(EditorStyles.miniLabel) { alignment = TextAnchor.MiddleRight };
            EditorGUILayout.LabelField($"{KitName} · v{KitVersion}", style);
        }

        // -- Tiện ích keyword ----------------------------------------------------------
        protected static void SetKeyword(Material m, string keyword, bool state)
        {
            if (m == null || string.IsNullOrEmpty(keyword)) return;
            if (state) m.EnableKeyword(keyword);
            else m.DisableKeyword(keyword);
        }
    }
}
#endif
