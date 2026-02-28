import * as THREE from 'three';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js';

export function createOrbitControls(camera, domElement) {
  const controls = new OrbitControls(camera, domElement);

  controls.enableDamping = true;
  controls.dampingFactor = 0.065;
  controls.rotateSpeed = 0.5;
  controls.zoomSpeed = 0.9;

  controls.enablePan = false;
  controls.minDistance = 5.8;
  controls.maxDistance = 18.5;
  controls.target.set(0, 0, 0);

  controls.mouseButtons = {
    LEFT: THREE.MOUSE.ROTATE,
    MIDDLE: THREE.MOUSE.DOLLY,
    RIGHT: null
  };

  domElement.addEventListener('contextmenu', (event) => {
    event.preventDefault();
  });

  return controls;
}
