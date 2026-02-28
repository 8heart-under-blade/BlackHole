# Black Hole Demo

Real-time Three.js + GLSL recreation of the NASA-style black hole look, including a lensed accretion disk, photon-ring-like rim, and bloom glow.

## Run locally

```bash
cd blackhole-demo
npm install
npm run dev
```

Open the local URL from Vite. The page is served at `/blackhole-demo/`.

## Build

```bash
cd blackhole-demo
npm run build
npm run preview
```

## Controls

- Hold **Left Mouse Button** and drag to rotate camera
- Use **Mouse Wheel** to zoom in/out

## Notes

- The accretion disk is fully procedural (no textures or network assets)
- Lens bending, primary/secondary disk visibility, and photon ring are shader-driven
