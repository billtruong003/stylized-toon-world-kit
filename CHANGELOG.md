# Changelog — Stylized Toon World Kit

All notable changes to this kit are documented here.

## [0.3.0] — 2026-06-16 — Sprint 2: P3 VFX / Effects Pack
### Added
- **`Core/StylizedVFX.hlsl`** (P0 extension) — shared base for the unlit-transparent VFX pack:
  common `VFXAttributes`/`VFXVaryings` (with particle vertex `COLOR`), a single reusable vertex stage
  `STW_VFXVert` (world pos, view dir, screen pos, fog, VR Single-Pass-Instanced), plus helpers
  `STW_FresnelVFX`, `STW_Scanline`, `STW_HexEdge`, `STW_PolarUV`, `STW_SoftParticle`.
- **7 P3 shaders** (hand-written HLSL, point at P0 Core; SRP-Batcher CBUFFER, GPU instancing, VR SPI;
  exposed `_SrcBlend/_DstBlend/_ZWrite/_Cull` render-state; particle vertex-color multiply):
  - `StylizedDissolve.shader` — **lit cutout** toon dissolve (spawn/death): procedural fBm **or** noise
    texture (`_NOISEMAP`), UV or world-space (`_DISSOLVE_WORLD`), HDR edge glow; clip carried into
    ShadowCaster + DepthNormals so shadow & SS-outline dissolve in sync.
  - `StylizedTeleport.shader` — additive build-up shell: vertical reveal by UV/World-Y, front glow band,
    scanline, energy fBm flicker, fresnel.
  - `StylizedForceField.shader` — additive shield: fresnel rim + scrolling hex grid (`STW_HexEdge`) +
    depth-intersection glow (`STW_SoftParticle`) + expanding world-space impact ripple.
  - `StylizedFlame.shader` — procedural fBm flame (scroll + distortion + 3-stop ramp) **or** flipbook
    sprite-sheet (`_FLIPBOOK`, `_Cols×_Rows×_FPS`); additive.
  - `StylizedMagicFlow.shader` — Valve 2-phase flow-map energy + detail noise; optional polar UV
    (`_POLAR`) for spinning magic circles; HDR low→high ramp + optional fresnel.
  - `StylizedHologram.shader` — alpha-blend sci-fi hologram: scanlines, per-band UV glitch, global
    flicker, fresnel rim, optional content texture.
  - `StylizedSlashTrail.shader` — additive weapon-trail: head→tail HDR gradient, soft cross-edge,
    head/tail trim, noise distortion (for `TrailRenderer`/ribbon meshes, `uv.x` = length).
- **Per-shader ShaderGUI** (`DissolveGUI`, `TeleportGUI`, `ForceFieldGUI`, `FlameGUI`, `MagicFlowGUI`,
  `HologramGUI`, `SlashTrailGUI`) — grouped foldouts + keyword toggles on `StylizedShaderGUIBase`;
  added reusable `DrawBlendStateGroup()` to the base; bumped GUI footer version to 0.3.0.
- README: P3 VFX file map + usage notes (Depth Texture for intersection/soft-particle; additive vs alpha).

### Notes
- Targets URP 17 / Unity 6; intersection glow & soft-particle fade need URP **Depth Texture** enabled.
- Shaders compiled "blind" (no Unity on the build host) with full static cross-checks (P0/VFX symbol
  resolution, CBUFFER layout, CustomEditor class match); Unity/GameCI compile verification before ship.

## [0.2.0] — 2026-06-16 — Sprint 1: P1 Toon Lighting & Outline Pack
### Added
- **6 P1 shaders** (all hand-written HLSL, point at the P0 Core; SRP-Batcher CBUFFER,
  GPU instancing, VR single-pass-instanced, ShadowCaster + DepthNormals passes):
  - `StylizedToonLit.shader` — flagship cel/toon lit: ramp steps **or** 1D texture-ramp
    (`_RAMP_TEXTURE`), custom colored shadow, real main + additional (Forward+) lights, shadow, GI/SH,
    normal-map / toon-spec / rim / emission keywords.
  - `StylizedOutline_InvertedHull.shader` — toon lit + per-material inverted-hull outline (world/screen
    width mode); cheap, every platform, no prepass, +1 Outline pass.
  - `StylizedOutline_ScreenSpace.shader` (Hidden) — fullscreen blit for the SS-outline feature; Roberts
    cross on depth + normals; one pass, keeps scene batching.
  - `StylizedToonRim.shader` — toon lit + 2-colour fresnel rim, optional light-aligned rim, additive glow.
  - `StylizedHairAniso.shader` — toon lit + Kajiya-Kay dual anisotropic highlight (shift map) for anime hair.
  - `StylizedRampLit.shader` — 1D LUT ramp lit + banded colored shadow + posterized AO.
- **Renderer Feature** `ScreenSpaceOutlineFeature.cs` — RenderGraph (`RecordRenderGraph` +
  `RenderGraphUtils.AddBlitPass`), `ConfigureInput(Depth|Normal)`, XR-safe; drives the Hidden SS shader.
- **Per-shader ShaderGUI** (`ToonLitGUI`, `OutlineInvertedHullGUI`, `ToonRimGUI`, `HairAnisoGUI`,
  `RampLitGUI`) — grouped foldouts + keyword toggles on the `StylizedShaderGUIBase`.
- README: P1 file map + "Outline: which variant?" guidance (hull vs screen-space trade-offs).

### Notes
- Targets URP 17 / Unity 6; SS-outline requires RenderGraph (U6) + Depth Texture enabled.
- Shaders compiled "blind" (no Unity on the build host) with full static cross-checks (P0 symbol
  resolution, CBUFFER layout, CustomEditor class match); Unity/GameCI compile verification before ship.

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
