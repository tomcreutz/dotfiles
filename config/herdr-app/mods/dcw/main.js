import { View } from "gpui-kit";
import { props } from "herdr";
import { Panel } from "./panel.js";
import { Start } from "./start.js";

// One mod, two views: the issues/containers panel, or { view: "start" } (the start dialog).
export default class Dcw extends View {
  init(_props, cx) {
    this.view = props()?.view === "start" ? new Start() : new Panel();
    this.view.init(props(), cx);
  }

  render(cx) {
    return this.view.render(cx);
  }
}
