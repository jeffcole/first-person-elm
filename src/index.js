import "./main.css";
import woodCratePath from "../textures/wood-crate.jpg";
import { Elm } from "./Main.elm";
import registerServiceWorker from "./registerServiceWorker";

Elm.Main.init({
  node: document.getElementById("root"),
  flags: { textures: { woodCratePath } }
});

registerServiceWorker();
