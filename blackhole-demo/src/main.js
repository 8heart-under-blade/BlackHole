import * as THREE from 'three';
import { EffectComposer } from 'three/examples/jsm/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/examples/jsm/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/examples/jsm/postprocessing/UnrealBloomPass.js';

import { createOrbitControls } from './controls/createOrbitControls.js';
import vertexShader from './shaders/blackhole.vert.glsl?raw';
import fragmentShader from './shaders/blackhole.frag.glsl?raw';
import './styles.css';

const app = document.querySelector('#app');

const renderer = new THREE.WebGLRenderer({
  antialias: true,
  alpha: false,
  powerPreference: 'high-performance'
});
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
// Before: exposure clipped large areas to white.
// After: lower exposure keeps the disk in deep orange/amber.
renderer.toneMappingExposure = 0.94;
app.appendChild(renderer.domElement);

const raytraceScene = new THREE.Scene();
const quadCamera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);

const viewCamera = new THREE.PerspectiveCamera(
  46,
  window.innerWidth / window.innerHeight,
  0.1,
  100
);
viewCamera.position.set(0.0, 2.55, 10.8);
viewCamera.lookAt(0, 0, 0);

const controls = createOrbitControls(viewCamera, renderer.domElement);

const params = {
  shadowRadius: 1.24,
  diskInnerRadius: 2.3,
  diskOuterRadius: 8.9,
  diskThickness: 0.145,
  diskIntensity: 1.18,
  lensingStrength: 2.34,
  ringIntensity: 0.9,
  ringRadius: 1.48,
  ringWidth: 0.058,
  stepScale: 0.088
};

const uniforms = {
  uTime: { value: 0 },
  uCameraPos: { value: viewCamera.position.clone() },
  uCamForward: { value: new THREE.Vector3(0, 0, -1) },
  uCamRight: { value: new THREE.Vector3(1, 0, 0) },
  uCamUp: { value: new THREE.Vector3(0, 1, 0) },
  uAspect: { value: viewCamera.aspect },
  uFov: { value: viewCamera.fov },

  uShadowRadius: { value: params.shadowRadius },
  uDiskInnerRadius: { value: params.diskInnerRadius },
  uDiskOuterRadius: { value: params.diskOuterRadius },
  uDiskThickness: { value: params.diskThickness },
  uDiskIntensity: { value: params.diskIntensity },
  uLensingStrength: { value: params.lensingStrength },
  uRingIntensity: { value: params.ringIntensity },
  uRingRadius: { value: params.ringRadius },
  uRingWidth: { value: params.ringWidth },
  uStepScale: { value: params.stepScale }
};

const material = new THREE.ShaderMaterial({
  uniforms,
  vertexShader,
  fragmentShader,
  depthWrite: false,
  depthTest: false
});

const quad = new THREE.Mesh(new THREE.PlaneGeometry(2, 2), material);
raytraceScene.add(quad);

const composer = new EffectComposer(renderer);
composer.addPass(new RenderPass(raytraceScene, quadCamera));

const bloomPass = new UnrealBloomPass(
  new THREE.Vector2(window.innerWidth, window.innerHeight),
  // Before: bloom flooded the disk and caused a neon halo.
  // After: high threshold + low strength keeps bloom subtle.
  0.11,
  0.28,
  1.1
);
composer.addPass(bloomPass);

const camRight = new THREE.Vector3();
const camUp = new THREE.Vector3();
const camForward = new THREE.Vector3();
const clock = new THREE.Clock();

function updateCameraUniforms() {
  viewCamera.updateMatrixWorld();
  const e = viewCamera.matrixWorld.elements;

  camRight.set(e[0], e[1], e[2]).normalize();
  camUp.set(e[4], e[5], e[6]).normalize();
  camForward.set(-e[8], -e[9], -e[10]).normalize();

  uniforms.uCameraPos.value.copy(viewCamera.position);
  uniforms.uCamRight.value.copy(camRight);
  uniforms.uCamUp.value.copy(camUp);
  uniforms.uCamForward.value.copy(camForward);
}

function onResize() {
  const width = window.innerWidth;
  const height = window.innerHeight;

  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.setSize(width, height);
  composer.setSize(width, height);

  bloomPass.setSize(width, height);

  viewCamera.aspect = width / height;
  viewCamera.updateProjectionMatrix();

  uniforms.uAspect.value = viewCamera.aspect;
  uniforms.uFov.value = viewCamera.fov;
}

window.addEventListener('resize', onResize);

function tick() {
  const elapsed = clock.getElapsedTime();

  controls.update();
  uniforms.uTime.value = elapsed;
  updateCameraUniforms();

  composer.render();
  requestAnimationFrame(tick);
}

onResize();
tick();
