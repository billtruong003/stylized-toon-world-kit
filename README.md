# Stylized Toon World Kit

Hand-written **HLSL** stylized / toon shader kit for **URP 17 · Unity 6 (6000.x)**.
No Shader Graph — clean, modular, performance-first code targeting **Mobile → PC → VR**.

> Status: **Sprint 1 — P1 Toon Lighting & Outline ✅** (6 shaders + SS-outline Renderer Feature, on the Sprint 0 Core base). Packs P3/P2/P4/P5 follow.

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
└── Runtime/
    └── ScreenSpaceOutlineFeature.cs # P1 — RenderGraph Renderer Feature driving the SS-outline shader
```

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
| 2 | P3 VFX / Effects (7) | planned |
| 3 | P2 Environment / Nature (7) | planned |
| 4 | P4 Surface / Material (6) | planned |
| 5 | P5 Anime Character NPR (5) | planned |

**Total target:** 31 shaders + 5 core includes + Renderer Feature(s).

---

## License

Proprietary — © Bill Truong (billtruong003). For sale on Unity Asset Store / Gumroad / itch.
Not for redistribution.
