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
        private bool _renderStateDrawn;   // tránh vẽ "Render State" 2 lần (VFX gọi DrawBlendStateGroup trong DrawProperties)

        // -- Entry point của ShaderGUI -------------------------------------------------
        public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
        {
            _editor = materialEditor;
            _props = properties;
            _target = materialEditor.target as Material;
            _renderStateDrawn = false;

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

        // -- ADVANCED (queue / instancing / GI) ----------------------------------------
        protected virtual void DrawAdvanced(MaterialEditor me)
        {
            // Nếu shader chưa tự vẽ Render State (qua DrawBlendStateGroup) → vẽ ở đây,
            // để MỌI shader đều có khối Render Face / ZTest / ZWrite một cách nhất quán.
            if (!_renderStateDrawn)
                DrawRenderStateSection(me, _props, _target, blend: false);

            BeginGroup("Advanced");
            if (_groupOpen)
            {
                me.RenderQueueField();
                me.EnableInstancingField();
                me.DoubleSidedGIField();
            }
            EndGroup();
        }

        // -- RENDER STATE (Render Face / ZTest / ZWrite / Blend / Two-Sided) ------------
        //  Vẽ TUẦN TỰ; chỉ hiện property nào shader thực sự khai báo (an toàn cho mọi shader).
        protected void DrawRenderStateSection(MaterialEditor me, MaterialProperty[] ps, Material m, bool blend)
        {
            _renderStateDrawn = true;
            BeginGroup("Render State");
            if (!_groupOpen) { EndGroup(); return; }

            // Render Face: điều khiển _Cull. Vẽ TAY (popup) nên không bị [HideInInspector] chặn.
            var cull = FindProperty("_Cull", ps, false);
            if (cull != null)
            {
                string[] faceLabels = { "Both", "Front", "Back" };
                int[]    faceCull   = { 0, 2, 1 };   // Both=Off(0) · Front=CullBack(2) · Back=CullFront(1)
                int cur = Mathf.RoundToInt(cull.floatValue);
                int idx = System.Array.IndexOf(faceCull, cur); if (idx < 0) idx = 0;
                EditorGUI.showMixedValue = cull.hasMixedValue;
                EditorGUI.BeginChangeCheck();
                int sel = EditorGUILayout.Popup("Render Face", idx, faceLabels);
                if (EditorGUI.EndChangeCheck())
                {
                    me.RegisterPropertyChangeUndo("Render Face");
                    cull.floatValue = faceCull[sel];
                }
                EditorGUI.showMixedValue = false;
            }

            if (blend)
            {
                DrawOptionalProp(me, ps, "_SrcBlend", "Src Blend");
                DrawOptionalProp(me, ps, "_DstBlend", "Dst Blend");
            }
            DrawOptionalProp(me, ps, "_ZTest",  "ZTest");
            DrawOptionalProp(me, ps, "_ZWrite", "ZWrite");

            // Two-Sided back-face layer — chỉ hiện khi shader có pass tương ứng (_TwoSidedToggle).
            var ts = FindProperty("_TwoSidedToggle", ps, false);
            if (ts != null)
            {
                me.ShaderProperty(ts, "Two-Sided Layers (back-face pass)");
                bool on = ts.floatValue > 0.5f;
                SetKeyword(m, "_TWO_SIDED_LAYERS", on);
                if (on)
                {
                    EditorGUI.indentLevel++;
                    DrawOptionalProp(me, ps, "_ZTestBack", "ZTest (back layer)");
                    EditorGUI.indentLevel--;
                }
            }

            EndGroup();
        }

        // Vẽ 1 property nếu tồn tại (enum popup tự đến từ [Enum(...)] qua ShaderProperty).
        private void DrawOptionalProp(MaterialEditor me, MaterialProperty[] ps, string name, string label)
        {
            var p = FindProperty(name, ps, false);
            if (p != null) me.ShaderProperty(p, label);
        }

        // -- BLEND STATE (giữ API cũ cho các GUI VFX) ----------------------------------
        //  Giờ ủy quyền cho DrawRenderStateSection để gồm cả Render Face / ZTest / Two-Sided.
        protected void DrawBlendStateGroup(MaterialEditor me, MaterialProperty[] ps, bool blend)
        {
            DrawRenderStateSection(me, ps, _target, blend);
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
