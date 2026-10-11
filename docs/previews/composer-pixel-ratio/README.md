# Composer pixel-ratio baseline

Branch: fix/composer-pixel-ratio
Baseline commit: 4abdb55dfa86b5c28a2a6414f1a5d4a491b10b56

Open index.html for a before/after slider, DPR selector, and amplified pixel difference.

The focused change synchronizes renderer/composer pixel ratios on resize and removes the CSS-pixel bloom resize override. OutputPass and shader tuning are separate follow-ups.

Captures: 800×500 CSS viewport; device scale factors 1 and 2; default camera (0,5.2,22); uTime frozen at 0. Browser response interception froze shader animation and stopped scheduling further frames for capture only. Production animation code was not changed. Chromium/SwiftShader supplied software WebGL because T3 preview could not start with the host's missing libraries. This is not a GPU benchmark.

before.json and after.json record actual drawing-buffer, composer, and bloom mip sizes at startup, after resizing to 640×400, and after overriding devicePixelRatio and dispatching the same resize path (simulated live DPR change). Native browser-context DPR 1 and 2 were used for the startup captures.

Results:
- DPR 1 before/after PNG files are byte-identical; zero pixel differences.
- DPR 2 first bloom mip at 800×500 CSS: 400×250 before, 800×500 after. Maximum RGB channel difference 9/255, average absolute channel difference 0.0782/255. The visual change is subtle.
- After the fix, all six startup/resize/DPR-change cases had composer dimensions equal to the drawing buffer and every bloom mip recursively half-sized (rounded).
- No browser page/console errors in capture runs.
- npm run build passed before and after; existing >500 kB bundle advisory remains.
- git diff --check passed.

image-metrics.json contains exact image statistics. diff images amplify absolute channel differences by 12, saturating at 255.

