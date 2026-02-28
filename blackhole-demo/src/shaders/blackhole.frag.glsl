precision highp float;

uniform float uTime;

uniform vec3 uCameraPos;
uniform vec3 uCamForward;
uniform vec3 uCamRight;
uniform vec3 uCamUp;
uniform float uAspect;
uniform float uFov;

uniform float uShadowRadius;
uniform float uDiskInnerRadius;
uniform float uDiskOuterRadius;
uniform float uDiskThickness;
uniform float uDiskIntensity;
uniform float uLensingStrength;
uniform float uRingIntensity;
uniform float uRingRadius;
uniform float uRingWidth;
uniform float uStepScale;

varying vec2 vUv;

// Tuned knobs for quick visual matching without rewiring uniforms.
// Before: broad neon ribbons. After: thinner filaments and tighter critical rim.
const float STREAK_SHARPNESS = 10.5;
const float THETA_BLUR_SPREAD = 0.0075;
const float UPPER_ARC_BOOST = 1.32;
const float LOWER_IMAGE_COMPACTNESS = 1.12;
const float DISK_WIDTH_SCALE = 1.5;
const float SIDE_VIEW_BOOST = 0.42;

float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 345.45));
  p += dot(p, p + 34.345);
  return fract(p.x * p.y);
}

float noise2(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);

  float a = hash21(i);
  float b = hash21(i + vec2(1.0, 0.0));
  float c = hash21(i + vec2(0.0, 1.0));
  float d = hash21(i + vec2(1.0, 1.0));

  vec2 u = f * f * (3.0 - 2.0 * f);

  return mix(a, b, u.x) +
    (c - a) * u.y * (1.0 - u.x) +
    (d - b) * u.x * u.y;
}

float fbm(vec2 p) {
  float value = 0.0;
  float amplitude = 0.5;

  for (int i = 0; i < 4; i++) {
    value += amplitude * noise2(p);
    p *= 2.02;
    amplitude *= 0.5;
  }

  return value;
}

// Before: aggressive white-hot ramp clipped large portions of the disk.
// After: deeper red/orange ramp with small yellow highlights only in hot spots.
vec3 blackbodyRamp(float t) {
  vec3 deepRed = vec3(0.03, 0.004, 0.0008);
  vec3 red = vec3(0.34, 0.055, 0.010);
  vec3 orange = vec3(0.95, 0.24, 0.028);
  vec3 amber = vec3(1.70, 0.62, 0.065);
  vec3 hotYellow = vec3(2.05, 0.95, 0.11);

  t = clamp(t, 0.0, 1.25);

  vec3 base = mix(deepRed, red, smoothstep(0.0, 0.24, t));
  vec3 warm = mix(red, orange, smoothstep(0.18, 0.62, t));
  vec3 hot = mix(orange, amber, smoothstep(0.55, 1.0, t));
  vec3 spark = mix(amber, hotYellow, smoothstep(0.95, 1.25, t));

  return base * 0.35 + warm * 0.75 + hot * 0.9 + spark * 0.18;
}

float filamentField(float radial, float angle) {
  float shearAngle = angle + radial * 6.4 - uTime * 0.22;

  float coarse = fbm(vec2(shearAngle * 6.1, radial * 28.0));
  float fine = noise2(vec2(shearAngle * 18.0 + coarse * 3.0, radial * 67.0));

  float ridgeA = pow(max(0.0, 1.0 - abs(coarse * 2.0 - 1.0)), STREAK_SHARPNESS);
  float ridgeB = pow(max(0.0, 1.0 - abs(fine * 2.0 - 1.0)), STREAK_SHARPNESS + 2.0);

  return ridgeA * 0.66 + ridgeB * 0.34;
}

// Before: repeated sin stripes looked grid-like.
// After: layered ridge noise + theta taps gives thin striated flow lines.
float diskFlow(float radius, float angle) {
  float radial = (radius - uDiskInnerRadius) / (uDiskOuterRadius - uDiskInnerRadius);

  float blur = THETA_BLUR_SPREAD * (1.0 + radial * 0.8);
  float tap0 = filamentField(radial, angle);
  float tap1 = filamentField(radial, angle + blur);
  float tap2 = filamentField(radial, angle - blur);
  float tap3 = filamentField(radial, angle + 2.0 * blur);
  float tap4 = filamentField(radial, angle - 2.0 * blur);

  float streaks = tap0 * 0.34 + (tap1 + tap2) * 0.24 + (tap3 + tap4) * 0.09;

  float bandNoise = fbm(vec2(radial * 13.0, angle * 2.4 - uTime * 0.07));
  float ringA = 0.5 + 0.5 * sin(radial * 63.0 + bandNoise * 5.5 - uTime * 0.11);
  float ringB = 0.5 + 0.5 * sin(radial * 98.0 - angle * 3.1 + uTime * 0.08);
  float radialBands = smoothstep(0.2, 0.95, ringA * 0.62 + ringB * 0.38);

  float drift = fbm(vec2(angle * 4.7 - uTime * 0.17, radial * 10.2 + uTime * 0.06));

  return clamp(streaks * (0.7 + 0.52 * radialBands) * (0.88 + 0.2 * drift), 0.0, 1.8);
}

vec3 traceBlackHole(vec3 ro, vec3 rd) {
  vec3 color = vec3(0.0);
  vec3 pos = ro;
  vec3 dir = rd;
  vec3 prevPos = pos;

  float minR = 1e8;
  float throughput = 1.0;
  int hitCount = 0;

  const int STEPS = 232;

  for (int i = 0; i < STEPS; i++) {
    float r = length(pos);
    minR = min(minR, r);

    if (r < uShadowRadius) {
      throughput = 0.0;
      break;
    }

    float gravity = uLensingStrength / (r * r + 0.08);
    dir = normalize(dir - normalize(pos) * gravity * uStepScale);

    float stepLen = uStepScale * (0.68 + 0.11 * r);
    prevPos = pos;
    pos += dir * stepLen;

    float y0 = prevPos.y;
    float y1 = pos.y;

    bool crossesMidplane = (y0 > 0.0 && y1 <= 0.0) || (y0 < 0.0 && y1 >= 0.0);
    bool insideSlab = abs(0.5 * (y0 + y1)) <= uDiskThickness;

    if (crossesMidplane || insideSlab) {
      float t = crossesMidplane ? clamp(y0 / (y0 - y1 + 1e-5), 0.0, 1.0) : 0.5;
      vec3 hit = mix(prevPos, pos, t);
      float yDist = abs(hit.y);
      float radius = length(hit.xz);

      if (radius > uDiskInnerRadius && radius < uDiskOuterRadius) {
        float radial = (radius - uDiskInnerRadius) / (uDiskOuterRadius - uDiskInnerRadius);
        float imageIndex = float(hitCount);

        float primaryW = 1.0 - smoothstep(0.5, 1.1, imageIndex);
        float secondaryW = smoothstep(0.0, 1.0, imageIndex) * (1.0 - smoothstep(1.5, 2.3, imageIndex));
        float higherW = smoothstep(1.4, 2.2, imageIndex);

        float innerGap = smoothstep(0.08, 0.2, radial);
        float outerFade = 1.0 - smoothstep(0.93, 1.0, radial);

        float primaryBand = exp(-pow((radial - 0.43) / (0.31 * DISK_WIDTH_SCALE), 2.0));
        float upperBandA = exp(-pow((radial - 0.23) / (0.16 * DISK_WIDTH_SCALE), 2.0));
        float upperBandB = exp(-pow((radial - 0.54) / (0.22 * DISK_WIDTH_SCALE), 2.0));
        float upperLayered = upperBandA + upperBandB * 0.72;
        float lowerCompact = exp(-pow((radial - 0.2) * LOWER_IMAGE_COMPACTNESS / (0.16 * DISK_WIDTH_SCALE), 2.0));

        float radialShape = primaryW * primaryBand + secondaryW * upperLayered + higherW * lowerCompact;
        radialShape *= innerGap * outerFade;

        float thicknessWeight = exp(-yDist / max(0.0001, uDiskThickness * 0.42));

        float angle = atan(hit.z, hit.x);
        float flow = diskFlow(radius, angle);

        vec3 velocity = normalize(vec3(-hit.z, 0.0, hit.x));
        vec3 toCam = normalize(ro - hit);
        float doppler = pow(clamp(1.0 + 0.56 * dot(velocity, toCam), 0.45, 1.55), 1.45);

        float sideView = 1.0 + SIDE_VIEW_BOOST * (1.0 - smoothstep(0.12, 0.78, abs(toCam.y)));
        float grazing = 0.7 + 0.7 * pow(clamp(1.0 - abs(dir.y), 0.0, 1.0), 0.55);
        float multiImageBoost = primaryW * 1.0 + secondaryW * UPPER_ARC_BOOST + higherW * 0.62;
        float sampleBlend = crossesMidplane ? 1.0 : 0.2;

        float emissive = (0.14 + flow * 1.04) * radialShape * grazing * thicknessWeight * sideView * sampleBlend;
        emissive *= doppler * uDiskIntensity * multiImageBoost;

        float hotSpots = pow(clamp(flow - 0.62, 0.0, 1.0), 3.4);
        vec3 diskColor = blackbodyRamp(0.16 + flow * 0.88 + hotSpots * 0.24);
        color += throughput * diskColor * emissive;

        if (crossesMidplane) {
          throughput *= 0.69;
          hitCount += 1;

          if (hitCount >= 4 || throughput < 0.03) {
            break;
          }
        }
      }
    }

    if (r > 42.0 && i > 24) {
      break;
    }
  }

  float shadowMask = smoothstep(uShadowRadius * 0.995, uShadowRadius * 1.015, minR);
  color *= shadowMask;

  float ring = exp(-pow((minR - uRingRadius) / max(0.0008, uRingWidth), 2.0));
  color += vec3(1.28, 0.46, 0.09) * ring * uRingIntensity;

  float halo = exp(-2.2 * max(0.0, minR - uShadowRadius));
  float haloMask = smoothstep(uShadowRadius + 0.04, uShadowRadius + 0.16, minR);
  color += vec3(0.004, 0.0012, 0.0003) * halo * haloMask;

  return max(color, vec3(0.0));
}

void main() {
  vec2 screen = vUv * 2.0 - 1.0;
  screen.x *= uAspect;

  float tanHalfFov = tan(radians(uFov) * 0.5);
  vec3 rd = normalize(
    uCamForward +
    screen.x * tanHalfFov * uCamRight +
    screen.y * tanHalfFov * uCamUp
  );

  vec3 color = traceBlackHole(uCameraPos, rd);

  float vignette = 1.0 - smoothstep(0.55, 1.5, length(screen));
  color *= mix(0.96, 1.0, vignette);

  gl_FragColor = vec4(color, 1.0);
}
