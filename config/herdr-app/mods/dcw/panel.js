// The panel: the space repo's open issues (start work on one) and the dcw containers.
import { div } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { spaces, panes, focused, exec, theme, run, openOverlay, notify } from "herdr";
import { repoOf, listIssues } from "./forge.js";
import { DCW } from "./config.js";

const REFRESH_MS = 60000;

function location() {
  const space = spaces().find((s) => s.active), f = focused();
  const pane = f?.pane ? panes().find((p) => p.pane === f.pane) : null;
  return pane?.cwd || f?.cwd || space?.folder || null;
}

function ago(iso) {
  const minutes = Math.max(0, Math.round((Date.now() - Date.parse(iso)) / 60000));
  if (minutes < 60) return `${minutes}m`;
  if (minutes < 1440) return `${Math.round(minutes / 60)}h`;
  return `${Math.round(minutes / 1440)}d`;
}

const base = (p) => p.split("/").pop();

export class Panel {
  init(_props, cx) {
    this.tab = "issues"; this.issues = []; this.containers = []; this.generation = 0; this.confirm = null;
    this.refresh(cx);
    cx.timer.every(REFRESH_MS, (cx) => this.refresh(cx));
  }

  refresh(cx) {
    const cwd = location();
    this.cwd = cwd;
    const generation = ++this.generation;
    this.loading = true;
    cx.spawn(async (cx) => {
      try {
        const [repo, containers] = await Promise.all([
          cwd ? repoOf(cwd) : Promise.reject(new Error("No folder in this space")),
          this.loadContainers(),
        ]);
        if (generation !== this.generation) return;
        this.repo = repo; this.containers = containers;
        this.issues = await listIssues(repo);
        if (generation === this.generation) this.error = null;
      } catch (e) {
        if (generation === this.generation) { this.error = String(e.message ?? e); this.containers = await this.loadContainers().catch(() => []); }
      } finally { if (generation === this.generation) this.loading = false; cx.notify(); }
    });
    cx.notify();
  }

  async loadContainers() {
    const r = await exec(DCW, ["ls", "--json"]);
    if (r.code !== 0) throw new Error(r.stderr.trim() || "dcw ls failed");
    return JSON.parse(r.stdout || "[]");
  }

  reloadContainers(cx) {
    cx.spawn(async (cx) => {
      try { this.containers = await this.loadContainers(); } catch (e) { this.error = String(e.message ?? e); }
      cx.notify();
    });
  }

  start(issue) {
    openOverlay({ mod: "dcw", kind: "dialog", width: 480, height: 470, props: { view: "start", issue, repo: this.repo } });
  }

  // A space already showing this worktree, else a new one with a container shell.
  open(c) {
    const pane = panes().find((p) => p.cwd && (p.cwd === c.workspace || p.cwd.startsWith(c.workspace + "/")));
    const space = pane ? spaces().find((s) => s.tabs.some((t) => t.id === pane.tab)) : null;
    if (space) run("space.select", { id: space.id });
    else run("space.new", { folder: c.workspace, tab: "container", argv: [DCW, "sh", c.workspace] });
  }

  shell(c) {
    const space = spaces().find((s) => s.active);
    run("tab.new", { space: space?.id, name: `🐳 ${base(c.workspace)}`, argv: [DCW, "sh", c.workspace] });
  }

  act(c, args, done, cx) {
    this.busy = c.name;
    cx.spawn(async (cx) => {
      try {
        const r = await exec(DCW, args);
        if (r.code !== 0) notify({ title: "dcw", body: (r.stderr || r.stdout).trim().split("\n").pop(), level: "error" });
        else if (done) notify({ title: "dcw", body: done, level: "success", timeout: 3000 });
      } catch (e) { notify({ title: "dcw", body: String(e.message ?? e), level: "error" }); }
      this.busy = null; this.confirm = null;
      this.reloadContainers(cx);
    });
    cx.notify();
  }

  // ---- drawing

  tabButton(id, label, count, t) {
    const active = this.tab === id;
    return h_flex().id(`dcw-tab-${id}`).h(26).px(10).gap(6).items_center().rounded(7).cursor_pointer()
      .when(active, (e) => e.bg(t.selected)).hover((s) => s.bg(t.hover))
      .on_click((_e, cx) => { this.tab = id; cx.notify(); })
      .child(div().text_color(active ? t.foreground : t.muted).child(label))
      .child(div().text_size(10).text_color(t.dim).child(String(count)));
  }

  button(id, label, onClick, t, strong = false) {
    return div().id(id).flex_none().px(7).h(20).flex().items_center().rounded(6).cursor_pointer()
      .text_size(11).border_1().border_color(strong ? t.accent : t.border).text_color(strong ? t.foreground : t.muted)
      .hover((s) => s.bg(t.raised).text_color(t.foreground))
      .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
      .on_click((_e, cx) => { cx.stop_propagation(); onClick(cx); }).child(label);
  }

  issueRow(issue, t) {
    const branchOpen = this.containers.some((c) => new RegExp(`(^|[/-])${issue.number}-`).test(base(c.workspace)));
    return v_flex().id(`dcw-issue-${issue.number}`).flex_none().px(10).py(7).gap(3).rounded(7).cursor_pointer()
      .hover((s) => s.bg(t.hover)).on_click(() => exec("xdg-open", [issue.url]).catch(() => {}))
      .child(h_flex().gap(8).items_center()
        .child(div().flex_none().text_size(11).text_color(t.accent).child(`#${issue.number}`))
        .child(div().flex_1().min_w(0).truncate().child(issue.title))
        .child(this.button(`dcw-start-${issue.number}`, branchOpen ? "Start again" : "Start", () => this.start(issue), t, !branchOpen)))
      .child(h_flex().gap(8).items_center()
        .child(h_flex().flex_1().min_w(0).gap(6).overflow_hidden().text_size(11)
          .children(issue.labels.slice(0, 3).map((l) => div().px(5).rounded(4).border_1().border_color(t.border).text_color(t.muted).child(l))))
        .child(div().flex_none().text_size(11).text_color(t.dim).child(`${issue.author} · ${ago(issue.updated)}`)));
  }

  containerRow(c, t) {
    const running = c.state === "running", busy = this.busy === c.name, isMain = c.workspace === c.main;
    const confirming = this.confirm === c.name;
    return v_flex().id(`dcw-c-${c.name}`).flex_none().px(10).py(7).gap(3).rounded(7).hover((s) => s.bg(t.hover))
      .child(h_flex().gap(8).items_center()
        .child(div().flex_none().text_color(running ? t.ansi2 : t.dim).child(running ? "●" : "○"))
        .child(div().flex_1().min_w(0).truncate().child(`${c.repo ? c.repo + " · " : ""}${base(c.workspace)}`))
        .when(busy, (e) => e.child(div().text_size(11).text_color(t.dim).child("…")))
        .when(!busy, (e) => e
          .child(this.button(`dcw-open-${c.name}`, "Open", () => this.open(c), t, true))
          .child(this.button(`dcw-sh-${c.name}`, "Shell here", () => this.shell(c), t))
          .child(this.button(`dcw-code-${c.name}`, "VS Code", (cx) => this.act(c, ["code", c.workspace], null, cx), t))
          .when(running, (e) => e.child(this.button(`dcw-stop-${c.name}`, "Stop", (cx) => this.act(c, ["stop", c.workspace], null, cx), t)))
          .child(this.button(`dcw-rm-${c.name}`, confirming ? (isMain ? "Sure?" : "Remove worktree too?") : "Remove", (cx) => {
            if (!confirming) { this.confirm = c.name; cx.notify(); return; }
            this.act(c, isMain ? ["rm", c.workspace] : ["rm", c.workspace, "--worktree"],
              isMain ? "Container removed" : "Container and worktree removed (branch kept)", cx);
          }, t))))
      .child(div().text_size(11).text_color(t.dim).truncate().child(`${c.status} · ${c.workspace}`));
  }

  emptyText(what) {
    if (this.error && what === "issues") return this.error;
    if (this.loading) return "Loading…";
    return what === "issues" ? "No open issues" : "No dcw containers. Start one from an issue.";
  }

  render(cx) {
    if (location() !== this.cwd) this.refresh(cx);
    const t = theme();
    const list = this.tab === "issues" ? this.issues.map((i) => this.issueRow(i, t)) : this.containers.map((c) => this.containerRow(c, t));
    const title = this.repo ? `${this.repo.name}${this.repo.remote ? ` · ${this.repo.remote.host}` : ""}` : "";
    return v_flex().id("dcw").size_full().min_h(0).rounded(10).overflow_hidden().bg(t.background).border_1().border_color(t.border).text_color(t.foreground).text_size(13)
      .child(h_flex().h(42).flex_none().px(10).gap(4).items_center().border_b(1).border_color(t.border)
        .child(this.tabButton("issues", "Issues", this.issues.length, t))
        .child(this.tabButton("containers", "Containers", this.containers.length, t))
        .child(div().flex_1().min_w(0).truncate().text_size(11).text_color(t.dim).text_right().child(title))
        .child(div().id("dcw-refresh").px(8).h(26).flex().items_center().rounded(7).cursor_pointer().text_size(11).text_color(t.muted)
          .hover((s) => s.bg(t.hover)).on_click((_e, cx) => this.refresh(cx)).child(this.loading ? "…" : "Refresh")))
      .child(v_flex().id("dcw-list").flex_1().min_h(0).overflow_y_scrollbar().p(6).gap(2)
        .children(list)
        .when(!list.length, (e) => e.child(div().p(8).text_color(this.error && this.tab === "issues" ? t.ansi1 : t.dim).child(this.emptyText(this.tab)))));
  }
}
