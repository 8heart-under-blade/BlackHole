# Black Hole Demo Project

This repository contains a real-time WebGL black hole visualization inspired by `BlackHole.gif`.

The app is implemented as a standalone Vite + Three.js project in `blackhole-demo/`, using a fullscreen fragment shader for lensing, accretion disk emission, and photon-ring style highlights.

## Highlights

- Real-time black hole rendering with procedural accretion disk (no texture assets)
- Fragment-shader lensing approach with primary/secondary disk visibility
- Thin photon-ring style rim and subtle bloom post-processing
- Interactive camera controls:
  - Left mouse drag: orbit
  - Mouse wheel: zoom

## Repository Layout

```text
.
|- blackhole-demo/
|  |- src/
|  |  |- controls/
|  |  |- shaders/
|  |  |- main.js
|  |- index.html
|  |- package.json
|  |- vite.config.js
|- BlackHole.gif
|- README.md
```

## Reference

- Local reference image: `BlackHole.gif`
- Source: https://www.space.com/black-holes-event-horizon-explained.html

## Getting Started

From the repository root:

```bash
cd blackhole-demo
npm install
npm run dev
```

Open the local URL printed by Vite (served under `/blackhole-demo/`).

## Build and Preview

```bash
cd blackhole-demo
npm run build
npm run preview
```

## Scripts

Inside `blackhole-demo/`:

- `npm run dev` - start development server
- `npm run build` - create production build
- `npm run preview` - preview production build locally

## Notes

- All visuals are generated procedurally in shader code.
- No external network assets are required for rendering.
- The scene is designed for desktop GPU real-time performance.
