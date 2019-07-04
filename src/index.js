import "./main.css";
import woodCratePath from "../textures/wood-crate.jpg";
import { Elm } from "./Main.elm";
import registerServiceWorker from "./registerServiceWorker";

const app = Elm.Main.init({
  node: document.getElementById("root"),
  flags: { textures: { woodCratePath } }
});

const body = document.body;

app.ports.requestPointerLock.subscribe(() => {
  body.requestPointerLock =
    body.requestPointerLock ||
    body.mozRequestPointerLock ||
    body.msRequestPointerLock ||
    body.webkitRequestPointerLock;

  body.requestPointerLock();
});

const isLocked = element =>
  element === document.pointerLockElement ||
  element === document.mozPointerLockElement ||
  element === document.msPointerLockElement ||
  element === document.webkitPointerLockElement;

const pointerLockChange = () => {
  app.ports.pointerLockChanged.send(isLocked(body));
};

[
  "onpointerlockchange",
  "onmozpointerlockchange",
  "onmspointerlockchange",
  "onwebkitpointerlockchange"
].forEach(property => {
  if (property in document) {
    const event = property.slice(2);
    document.addEventListener(event, pointerLockChange, false);
  }
});

registerServiceWorker();
