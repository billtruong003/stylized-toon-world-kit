# Stylized Toon World Kit

Hand-written **HLSL** stylized / toon shader kit for **URP 17 · Unity 6 (6000.x)**.
No Shader Graph — clean, modular, performance-first code targeting **Mobile → PC → VR**.

> Status: **Sprint 5 — P5 Anime Character NPR ✅** (5 shaders: Character Body, Face SDF, Hair, Eye, Skin SSS) — **all packs complete (31 shaders + P0 Core)**. Builds on Sprint 4 (P4 Surface, 6), Sprint 3 (P2 Environment, 7), Sprint 2 (P3 VFX, 7), Sprint 1 (P1 Toon/Outline, 6 + SS-outline feature) and Sprint 0 (P0 Core).

---

## What's in here (Sprint 0)

```
Assets/StylizedToonWorldKit/
├── package.json                 # UPM package (install via Package Manager → add from git/disk)
├── Core/                        # P0 — shared HLSL include library (everything points here)
│   ├── URPCompat.hlsl           #   URP includes, version macros, Forward+/instancing/VR-SPI, fog/shadow wrappers
│   ├── StylizedLighting.hlsl    #   toon ramp (step/smooth/texture), half-lambert, toon+aniso specular, rim, STW_ToonLighting()
│   ├── StylizedNoise.hlsl       #   hash, value/gradient/voronoi noise, fBm, panner, flow-map
│   ├── StylizedSurface.hlsl     #   triplanar, height/slope gradient, depth-fade, screen UV, parallax
│   ├── OutlineCommon.hlsl       #   inverted-hull (world/screen) + screen-space Roberts edge helpers
│   ├── StylizedVFX.hlsl         #   P3 base: VFXAttributes/Varyings + STW_VFXVert + fresnel/scanline/hex/polar/soft-particle
│   └── StylizedToon_Template.shader  # reference shader showing all conventions (copy this pattern)
├── Editor/
│   ├── StylizedShaderGUIBase.cs # reusable ShaderGUI base (grouped foldouts, keyword toggles, render-state)
│   └── StylizedToonTemplateGUI.cs
├── Toon/                        # P1 — Toon Lighting & Outline pack (6 shaders)
│   ├── StylizedToonLit.shader            #   flagship cel/toon lit — ramp steps OR 1D texture-ramp, colored shadow, real lights/shadow/GI, normal/spec/rim/emission keywords
│   ├── StylizedOutline_InvertedHull.shader  #   toon lit + per-material outline (inverted hull, world/screen width) — cheap, every platform, +1 pass
│   ├── StylizedOutline_ScreenSpace.shader   #   Hidden fullscreen blit for the SS-outline Renderer Feature (Roberts depth+normal edge), keeps scene batch
│   ├── StylizedToonRim.shader             #   toon lit + 2-colour fresnel rim, optional light-aligned rim, additive glow
│   ├── StylizedHairAniso.shader           #   toon lit + Kajiya-Kay dual anisotropic highlight (shift map) for anime hair
│   └── StylizedRampLit.shader             #   1D LUT ramp lit + banded colored shadow + posterized AO (artist-driven gradients)
├── Runtime/
│   └── ScreenSpaceOutlineFeature.cs # P1 — RenderGraph Renderer Feature driving the SS-outline shader
├── VFX/                         # P3 — VFX / Effects pack (7 shaders, on StylizedVFX.hlsl)
│   ├── StylizedDissolve.shader      #   lit cutout dissolve (spawn/death) — fBm/noise-tex, UV/world, HDR edge glow, clip in shadow+depthnormals
│   ├── StylizedTeleport.shader      #   additive build-up shell — vertical reveal, front glow, scanline, fresnel
│   ├── StylizedForceField.shader    #   additive shield — fresnel + scrolling hex grid + depth-intersection glow + impact ripple
│   ├── StylizedFlame.shader         #   procedural fBm flame OR flipbook sprite-sheet — 3-stop color ramp, additive
│   ├── StylizedMagicFlow.shader     #   2-phase flow-map energy + optional polar UV (spinning magic circle)
│   ├── StylizedHologram.shader      #   alpha-blend hologram — scanlines, per-band glitch, flicker, fresnel
│   └── StylizedSlashTrail.shader    #   additive weapon trail — head→tail HDR gradient, soft edge, trim, distortion
├── Environment/                 # P2 — Environment / Nature pack (7 shaders)
│   ├── StylizedWater.shader         #   transparent lake/river — depth-gradient color, edge foam, 2-layer flow normals, toon spec/fresnel, optional caustics (Depth Texture)
│   ├── StylizedOcean.shader         #   opaque ocean — 3 Gerstner waves (vertex displace, analytic normal), crest+shore foam, ShadowCaster matches waves
│   ├── StylizedGrass.shader         #   cutout grass cards — vertex wind sway (height-masked) + gust, root→tip gradient, back-light translucency
│   ├── StylizedTree.shader          #   cutout foliage — 2-tier wind (trunk sway + leaf flutter), vertex-color/uv mask, dithered alpha edge, translucency
│   ├── StylizedSky.shader           #   unlit DOME — 3-band day/night gradient, toon fBm clouds, sun disk+halo from main light
│   ├── StylizedTerrain.shader       #   opaque terrain — auto 3-layer blend (ground / triplanar cliff by slope / snow-sand peak by height), macro variation
│   └── StylizedWaterfall.shader     #   transparent falls — 2-layer vertical flow + distortion, top/bottom foam, fresnel, base mist soft-fade (Depth Texture)
└── Surface/                     # P4 — Stylized Surface / Material pack (6 shaders)
    ├── StylizedCrystal.shader       #   transparent gem — fake refraction (Opaque Texture) + dispersion, inner glow, facet noise, HDR fresnel/spec, soft depth edges
    ├── StylizedIce.shader           #   opaque ice/snow — toon lit + view-dependent sparkle (voronoi twinkle), depth tint (fake SSS), frost edge; full shadow/depthnormals
    ├── StylizedLiquid.shader        #   transparent potion — object-Y fill level + wobble, surface band, depth gradient, rising bubbles, fresnel; two-sided
    ├── StylizedLava.shader          #   opaque magma — flow-map fBm heat, cooled crust + glowing molten cracks (HDR ramp + pulse); crust lit, lava emissive
    ├── StylizedGlass.shader         #   transparent glass — refraction (Opaque Texture) + optional frosted (5-tap blur + jitter), tint, normal map, fresnel/spec
    ├── StylizedMetal.shader         #   opaque toon metal/gold — toon lit tint + stylized SH env (toon-banded, version-safe) + stepped aniso sweep + fresnel rim
└── Anime/                      # P5 — Anime Character NPR pack (5 shaders)
    ├── AnimeCharacterBody.shader    #   body NPR — cel ramp + colored shadow, ILM mask (R spec / G AO), ILM-masked flat toon spec, normal/rim/emission; outline & SDF ready
    ├── AnimeFaceSDF.shader          #   SDF face shadow — smooth nose/chin shadow sliding with the key light; head axes from transform (+Z fwd), UV mirror by right·light; GI + rim
    ├── AnimeHair.shader             #   anime hair — cel base + dual anisotropic highlight (Kajiya-Kay) shifted by noise, highlight tinted toward base, rim; needs tangents
    ├── AnimeEye.shader              #   multi-layer eye — sclera + parallax iris (fake corneal depth) + dilating pupil + limbal ring + procedural emissive highlight
    └── AnimeSkinSSS.shader          #   stylized skin — fake subsurface (SSS-colored shadow + terminator scatter band) + blush mask + soft sheen + normal/rim
```

### Anime NPR pack notes (P5)
- **Character Body** uses an optional **ILM material mask** (`_ILM`): R drives per-region specular intensity, G is an AO/shadow term — one material can read armor/cloth/skin differently. The flat toon specular is masked by ILM.r. Full ShadowCaster + DepthNormals so it works with Inverted-Hull or Screen-Space outline.
- **Face SDF** does **not** use N·L for the main shadow (face normals are too noisy). Author one **SDF grayscale** (lit-duration field) for light coming **from the left**; the shader compares it to a threshold derived from `forward·light` and mirrors UV.x by the sign of `right·light` (`_SDF_FLIP` to invert). Head **forward = +Z, right = +X** are taken from the object transform, so the face mesh must face +Z with no skewed scale. Additional lights are intentionally skipped (faces follow the key light).
- **Anime Hair / Eye** need **tangents** (Eye also wants UVs centered at 0.5,0.5). Eye iris depth fakes the cornea via `STW_ParallaxOffset` in tangent space; the corneal highlight is emissive (ignores shadow).
- **Skin SSS** colors the banded shadow with the SSS tint and adds a **terminator scatter** band (`saturate(1-|N·L|/width)`) for the under-skin glow; `_BLUSH` tints cheeks by a mask. All P5 lighting reuses P0 — no math duplicated.

### VFX pack notes (P3)
- All P3 shaders are **unlit transparent** except **Dissolve** (lit cutout, full ShadowCaster + DepthNormals).
  Each exposes `_SrcBlend/_DstBlend/_ZWrite/_Cull` (default **additive**; Hologram defaults to alpha-blend).
- They read the **particle vertex stream** `COLOR` — drive color & alpha per-particle from a Particle System.
- **ForceField** intersection glow and **soft-particle** fades need URP **Depth Texture** enabled on the Renderer.
- Procedural modes (Flame/Dissolve/Teleport) need **no textures**; Flame/MagicFlow can switch to texture/flipbook by keyword.

### Environment pack notes (P2)
- **Water / Waterfall** are transparent (alpha-blend, ZWrite Off); their depth gradient, edge foam, caustics and base mist read the scene **Depth Texture** — enable it on the URP Renderer.
- **Ocean** displaces vertices with 3 summed **Gerstner waves**; the `ShadowCaster` pass shares the exact displacement function (HLSLINCLUDE) so cast shadows track the waves. It is opaque and reads Depth Texture only for the shallow/deep tint.
- **Grass / Tree** are alpha-cutout lit with **vertex wind in every pass** (ForwardLit + ShadowCaster + DepthNormals share one wind function) so shadows and SS-outline stay in sync. Grass masks bend by `uv.y`; Tree masks by `uv.y` or vertex `COLOR.a` (keyword `_VERTEXCOLOR_MASK`) and can dither its alpha edge.
- **Sky** is **unlit** and meant for a **dome mesh** (sphere with inward-facing normals), not the Skybox material slot; it reads the scene's main Directional Light for the sun and day/night blend.
- **Terrain** blends 3 layers automatically — ground (planar), cliff (triplanar by slope), peak snow/sand (by world height) — no splat-control texture required; tune slope/height thresholds in the GUI.

### Surface pack notes (P4)
- **Crystal / Glass** fake refraction by offsetting the **scene-color (Opaque Texture)** along the view-space normal — enable URP **Opaque Texture** on the Renderer. Crystal's soft edges also read the **Depth Texture**. Crystal's `_DISPERSION` splits R/G/B for a rainbow rim; Glass's `_FROSTED` does a 5-tap scene blur + noise jitter for frosted glass.
- **Ice / Lava / Metal** are **opaque** and lit through `STW_ToonLighting` (P0), with full **ShadowCaster + DepthNormals** so they cast shadows and work with SS-outline/SSAO. Ice sparkle is view-dependent (voronoi glints + per-cell twinkle); Lava's crust is lit while the molten cracks are **emissive** (HDR, pulses).
- **Liquid** is a two-sided in-bottle volume: it **clips by object-space Y** (`_FillLevel`) with a sin wobble for a fill line, and flips back-face normals via the portable `IS_FRONT_VFACE` macro. Put it on the inner liquid mesh.
- **Metal** fakes a stylized environment with `SampleSH(reflectVector)` toon-banded — deliberately **not** `GlossyEnvironmentReflection`, so it compiles unchanged across URP 12/14/17; it stays cheap and reflection-probe-independent.

### Outline: which variant?
- **Inverted-Hull** (`StylizedOutline_InvertedHull`) — per-material, runs everywhere incl. mobile/VR, needs no prepass; costs **+1 draw per material** (can break batching across many materials). Best for hero objects / stylized thickness.
- **Screen-Space** (`ScreenSpaceOutlineFeature` + Hidden shader) — **one fullscreen pass**, keeps the scene's batching, edges from depth+normal Roberts cross. Add the feature to the URP Renderer asset (don't put the shader on a material) and enable **Depth Texture**. Best for whole-scene uniform outlines. Requires U6 RenderGraph.

The Core library is **not sold standalone** — it is the shared base every pack (P1 Toon/Outline,
P2 Environment, P3 VFX, P4 Surface, P5 Anime NPR) includes, so code isn't duplicated and quality/version
handling stays in one place.

---

## Design rules (enforced across every shader)

1. **Optimize-first, all targets:** Mobile → PC → VR. Watch draw-call / batch / SRP Batcher / GPU instancing.
   Where perf ↔ visual conflicts, ship **two variants** (e.g. outline: *Screen-Space* keeps batch / 1 draw,
   *Inverted-Hull* looks better but adds a pass — each documents which breaks batching).
2. **VR = Single-Pass Instanced.** Every shader uses the `STW_*` stereo macros from `URPCompat.hlsl`
   (`STW_VERTEX_INPUT_INSTANCE_ID`, `STW_VERTEX_OUTPUT_STEREO`, `STW_SETUP_INSTANCE_VERT/FRAG`).
3. **Custom ShaderGUI per shader** — clear grouped properties, hide unused features by keyword.
4. **Clean code** — descriptive block comment + params at the top of each file; no scattered noise.
5. **Modular** — point at the P0 base as much as possible; the base grows, code never repeats.
6. **Reuse Unity** — use URP ShaderLibrary lighting/shadow/fog functions instead of re-writing them.
7. **Flow per shader:** research docs → understand → write URP17 → check U6 → down-version notes → ShaderGUI → demo + README.

---

## How to use the Core library in a shader

Inside a `Pass { HLSLPROGRAM ... }` (see `StylizedToon_Template.shader` for the full skeleton):

```hlsl
#include "URPCompat.hlsl"          // ALWAYS first — pulls URP core + macros
#include "StylizedLighting.hlsl"   // whatever Core modules you need

// SRP Batcher: ALL material properties in one CBUFFER
CBUFFER_START(UnityPerMaterial)
    float4 _BaseMap_ST; half4 _BaseColor; /* ... */
CBUFFER_END
TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);   // not sampler2D

struct Attributes { /* ... */ STW_VERTEX_INPUT_INSTANCE_ID };
struct Varyings   { /* ... */ STW_VERTEX_OUTPUT_STEREO };

Varyings vert(Attributes IN){ Varyings OUT=(Varyings)0; STW_SETUP_INSTANCE_VERT(IN,OUT); /* ... */ }
half4 frag(Varyings IN):SV_Target{ STW_SETUP_INSTANCE_FRAG(IN); /* call STW_ToonLighting(...) */ }
```

Required pragmas for a lit pass are listed as a copy-paste checklist at the top of `URPCompat.hlsl`.

---

## Requirements

- **Unity 6000.0+** with **Universal RP 17**.
- For Screen-Space outline / depth-fade / refraction: enable **Depth Texture** and **Opaque Texture**
  in the URP Renderer asset.
- Screen-Space outline (P1) ships as a **Renderer Feature** using the **RenderGraph API** (mandatory on U6).

### Down-version notes (URP 14 / Unity 2022, URP 12 / Unity 2021)
The Core is written URP-17-first. Known differences to handle when back-porting (tracked in detail in
Lucy's `unity-shader-version-gotchas` memo):

- **Forward+** is U6-only — on URP 12/14 the `_FORWARD_PLUS` keyword/`LIGHT_LOOP_*` macros are absent;
  the additional-lights `for` loop path in `StylizedLighting.hlsl` covers those versions.
- **Renderer Features** on URP ≤16 use the old `ScriptableRenderPass.Execute()` (compatibility) path,
  not RenderGraph.
- ShaderLibrary include paths are stable across 12→17, but a few function signatures shifted — wrap any
  new divergence inside `URPCompat.hlsl` so call sites stay clean.

---

## Roadmap

| Sprint | Pack | Status |
|---|---|---|
| 0 | P0 Core Library (5 includes + ShaderGUI base + template) | ✅ done |
| 1 | P1 Toon Lighting & Outline (6 shaders + SS-outline Renderer Feature) | ✅ done |
| 2 | P3 VFX / Effects (7) | ✅ done |
| 3 | P2 Environment / Nature (7) | ✅ done |
| 4 | P4 Surface / Material (6) | ✅ done |
| 5 | P5 Anime Character NPR (5) | ✅ done |

**Total:** 31 shaders + 5 core includes + Renderer Feature(s) — **all packs complete**.

---

## License

Proprietary — © Bill Truong (billtruong003). For sale on Unity Asset Store / Gumroad / itch.
Not for redistribution.
