# Changelog — Stylized Toon World Kit

All notable changes to this kit are documented here.

## [0.1.0] — 2026-06-16 — Sprint 0: Foundation (P0 Core Library)
### Added
- **P0 Core Library** (5 shared HLSL includes):
  - `URPCompat.hlsl` — URP ShaderLibrary includes; version macros; Forward+/GPU-instancing/VR
    Single-Pass-Instanced macros (`STW_*`); fog/shadow/main-light wrappers; pragma checklist.
  - `StylizedLighting.hlsl` — cel ramp (step/smooth/texture), half-lambert, toon + anisotropic
    specular, rim/fresnel, and `STW_ToonLighting()` (main + additional Forward+ lights + GI + shadow + rim).
  - `StylizedNoise.hlsl` — hash (1D/2D/3D), value/gradient/voronoi noise, fBm, panner, flow-map.
  - `StylizedSurface.hlsl` — triplanar, height/slope gradient, depth-fade, screen-space UV, parallax.
  - `OutlineCommon.hlsl` — inverted-hull (world & screen space) + screen-space Roberts edge helpers.
- **ShaderGUI base** (`StylizedShaderGUIBase.cs`) — reusable grouped foldouts, keyword toggles,
  render-state section, kit header/footer; `StylizedToonTemplateGUI.cs` as the worked example.
- **Reference shader** `StylizedToon_Template.shader` — canonical skeleton (ForwardLit + ShadowCaster +
  DepthNormals passes, CBUFFER/SRP-Batcher layout, VR macros, full pragma set) every pack copies.
- Repo scaffolding: UPM `package.json`, `.gitignore`, `README.md`, asmdefs (Runtime + Editor).

### Notes
- Targets URP 17 / Unity 6 first; down-version (URP 12/14) differences documented in README.
- Core compiled "blind" (no Unity on the build host); full compile verification happens in Unity/GameCI
  before each pack ships.
