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

  for (int i = 0; i < 5; i++) {
    value += amplitude * noise2(p);
    p *= 2.07;
    amplitude *= 0.5;
  }

  return value;
}

vec3 blackbodyRamp(float t) {
  vec3 c0 = vec3(0.12, 0.04, 0.01);
  vec3 c1 = vec3(0.92, 0.28, 0.03);
  vec3 c2 = vec3(2.45, 0.98, 0.16);
  vec3 c3 = vec3(3.0, 1.65, 0.55);

  t = clamp(t, 0.0, 1.4);
  vec3 warm = mix(c0, c1, smoothstep(0.0, 0.45, t));
  vec3 hot = mix(c1, c2, smoothstep(0.3, 0.95, t));
  vec3 whiteHot = mix(c2, c3, smoothstep(0.9, 1.4, t));

  return mix(warm, hot, 0.65) + whiteHot * 0.35;
}

float diskFlow(float radius, float angle) {
  float radial = (radius - uDiskInnerRadius) / (uDiskOuterRadius - uDiskInnerRadius);

  vec2 flowUv = vec2(angle * 12.0, radial * 15.0);
  float warp = fbm(flowUv + vec2(radial * 12.0, uTime * 0.06));

  float streamA = sin(angle * 170.0 + radial * 56.0 - uTime * 3.6 + warp * 6.0);
  float streamB = sin(angle * 104.0 - radial * 72.0 + uTime * 2.7 + warp * 7.4);
  float bandA = smoothstep(0.17, 1.0, 0.5 + 0.5 * streamA);
  float bandB = smoothstep(0.28, 1.0, 0.5 + 0.5 * streamB);

  float grain = fbm(vec2(angle * 26.0 - uTime * 0.2, radial * 48.0 + warp * 3.0));
  float shear = abs(sin(angle * 14.0 + radial * 24.0 + grain * 4.0));

  return (bandA * 0.75 + bandB * 0.6) * (0.7 + 0.3 * shear) + grain * 0.5;
}

vec3 traceBlackHole(vec3 ro, vec3 rd) {
  vec3 color = vec3(0.0);
  vec3 pos = ro;
  vec3 dir = rd;
  vec3 prevPos = pos;

  float minR = 1e8;
  float throughput = 1.0;
  int hitCount = 0;

  const int STEPS = 220;

  for (int i = 0; i < STEPS; i++) {
    float r = length(pos);
    minR = min(minR, r);

    if (r < uShadowRadius) {
      throughput = 0.0;
      break;
    }

    float gravity = uLensingStrength / (r * r + 0.08);
    dir = normalize(dir - normalize(pos) * gravity * uStepScale);

    float stepLen = uStepScale * (0.72 + 0.1 * r);
    prevPos = pos;
    pos += dir * stepLen;

    float y0 = prevPos.y;
    float y1 = pos.y;

    if ((y0 > 0.0 && y1 <= 0.0) || (y0 < 0.0 && y1 >= 0.0)) {
      float t = y0 / (y0 - y1 + 1e-5);
      vec3 hit = mix(prevPos, pos, clamp(t, 0.0, 1.0));
      float radius = length(hit.xz);

      if (radius > uDiskInnerRadius && radius < uDiskOuterRadius) {
        float radial = (radius - uDiskInnerRadius) / (uDiskOuterRadius - uDiskInnerRadius);
        float centerWeight = smoothstep(0.0, 0.15, radial) * (1.0 - smoothstep(0.68, 1.0, radial));
        float thicknessWeight = exp(-abs(hit.y) / max(0.0001, uDiskThickness));

        float angle = atan(hit.z, hit.x);
        float flow = diskFlow(radius, angle);

        vec3 velocity = normalize(vec3(-hit.z, 0.0, hit.x));
        vec3 toCam = normalize(ro - hit);
        float doppler = pow(clamp(1.0 + 0.72 * dot(velocity, toCam), 0.22, 1.95), 2.05);

        float multiImageBoost = 1.0 + float(hitCount) * 0.38;
        float emissive = (0.1 + flow * 1.48) * centerWeight * thicknessWeight;
        emissive *= doppler * uDiskIntensity * multiImageBoost;

        vec3 diskColor = blackbodyRamp(0.35 + flow * 0.85);
        color += throughput * diskColor * emissive;

        throughput *= 0.74;
        hitCount += 1;

        if (hitCount >= 4 || throughput < 0.03) {
          break;
        }
      }
    }

    if (r > 42.0 && i > 24) {
      break;
    }
  }

  float shadowMask = smoothstep(uShadowRadius * 0.92, uShadowRadius * 1.05, minR);
  color *= shadowMask;

  float ring = exp(-pow((minR - uRingRadius) / max(0.001, uRingWidth), 2.0));
  color += vec3(2.85, 1.27, 0.28) * ring * uRingIntensity;

  float halo = exp(-0.42 * max(0.0, minR - uShadowRadius));
  float haloMask = smoothstep(uShadowRadius + 0.03, uShadowRadius + 0.9, minR);
  color += vec3(0.07, 0.03, 0.01) * halo * haloMask;

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

  float vignette = 1.0 - smoothstep(0.45, 1.45, length(screen));
  color *= mix(0.88, 1.02, vignette);

  gl_FragColor = vec4(color, 1.0);
}
