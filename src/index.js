import "./main.css";
import grassPath from "../textures/grass.jpg";
import woodCratePath from "../textures/wood-crate.jpg";
import { Elm } from "./Main.elm";
import registerServiceWorker from "./registerServiceWorker";

const app = Elm.Main.init({
  node: document.getElementById("root"),
  flags: {
    textures: {
      grassPath,
      woodCratePath
    }
  }
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

const move = event => {
  const movementX =
    event.movementX ||
    event.mozMovementX ||
    event.msMovementX ||
    event.webkitMovementX ||
    0;

  const movementY =
    event.movementY ||
    event.mozMovementY ||
    event.msMovementY ||
    event.webkitMovementY ||
    0;

  app.ports.pointerMovement.send([movementX, movementY]);
};

const pointerLockChange = () => {
  if (isLocked(body)) {
    body.addEventListener("mousemove", move, false);
    app.ports.pointerLockChanged.send(true);
  } else {
    body.removeEventListener("mousemove", move, false);
    app.ports.pointerLockChanged.send(false);
  }
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
