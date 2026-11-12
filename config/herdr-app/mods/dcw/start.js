// Start work on an issue: worktree + devcontainer + an agent already looking at it.
// props { issue, repo }.
//
// herdr's exec() has a 30 s limit and a first image build takes minutes, so the dialog
// only makes the worktree (`dcw new --no-up`, quick). The new space's agent tab runs
// `dcw agent`, which brings the container up in that terminal (progress visible) and
// then turns into the agent.
import { div, svg, image } from "gpui-kit";
import { v_flex, h_flex, InputState, Input } from "gpui-base";
import { exec, run, props, closeOverlay, theme, knownAgents, spaces, shared, setShared } from "herdr";
import { viewCommand } from "./forge.js";
import { DCW } from "./config.js";

const LAST = "dcw.start.last";
const TYPES = { bug: "fix", documentation: "docs", docs: "docs", refactor: "refactor", chore: "chore" };
// Agents whose shell dcw routes into the container transparently (see `dcw agent`).
const ROUTED = new Set(["claude", "pi"]);
const MODES = [
  { id: "plan", label: "Investigate & plan" },
  { id: "implement", label: "Implement" },
];

const slug = (s) => s.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase()
  .replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").split("-").slice(0, 5).join("-");

function branchFor(issue) {
  const type = issue.labels.map((l) => TYPES[l.toLowerCase()]).find(Boolean) ?? "feat";
  return `${type}/${issue.number}-${slug(issue.title)}`;
}

function promptFor({ issue, repo, branch, path, routed, mode }) {
  const forge = repo.kind === "github" ? "GitHub" : "GitLab";
  const body = (issue.body || "(no description)").trim();
  return [
    `${forge} issue #${issue.number} of ${repo.remote?.path ?? repo.name}: ${issue.title}`,
    issue.url,
    "",
    body.length > 6000 ? body.slice(0, 6000) + `\n[... truncated, see \`${viewCommand(repo, issue.number)}\`]` : body,
    "",
    "---",
    `You are in a fresh git worktree at ${path} on branch ${branch}.`,
    routed
      ? "Your shell commands run inside this worktree's devcontainer, which has the project's toolchain (compilers, conan, cmake, ...). File paths are identical there."
      : "The project's toolchain lives in this worktree's devcontainer: run every build, test and tooling command through `dcw exec -- <command>`. File paths are identical there.",
    "Read the README, AGENTS.md and docs/ first.",
    mode === "plan"
      ? "Then investigate the relevant code and write a short plan: what to change and where, risks and open questions, and how to verify it (build, tests). Do not change any code yet; wait for my go."
      : "Then implement it, build and run the relevant tests in the devcontainer, and commit on this branch with a clear message. Do not push.",
  ].join("\n");
}

export class Start {
  init(_props, cx) {
    const p = props() ?? {};
    this.issue = p.issue; this.repo = p.repo;
    const last = shared(LAST) ?? {};
    this.mode = last.mode ?? "plan";
    this.shellTab = last.shellTab ?? true;
    this.agents = [];
    this.branch = InputState.new({ value: this.issue ? branchFor(this.issue) : "", placeholder: "branch name" });
    this.branch.on("submit", (_e, cx) => this.start(cx));
    cx.spawn(async (cx) => {
      try {
        this.agents = (await knownAgents()).filter((a) => a.installed);
        this.agent = this.agents.find((a) => a.key === last.agent) ?? this.agents.find((a) => ROUTED.has(a.key)) ?? this.agents[0];
      } catch (e) { this.error = `Could not list agents: ${e}`; }
      cx.notify();
    });
  }

  start(cx) {
    const branch = this.branch.value().trim();
    if (this.busy || !this.agent || !branch || !this.issue) return;
    const agent = this.agent, mode = this.mode, shellTab = this.shellTab, issue = this.issue, repo = this.repo;
    this.busy = true; this.error = null;
    cx.spawn(async (cx) => {
      try {
        const r = await exec(DCW, ["new", branch, "--repo", repo.main, "--no-up"]);
        if (r.code !== 0) throw new Error((r.stderr || r.stdout).trim().split("\n").pop() || "dcw new failed");
        const path = r.stdout.trim().split("\n").pop();
        const routed = ROUTED.has(agent.key);
        const prompt = promptFor({ issue, repo, branch, path, routed, mode });
        // Routed agents get the prompt as their first argument (it waits for the container);
        // others get it from herdr as their first message.
        const argv = [DCW, "agent", "-w", path, ...agent.run, ...(routed ? [prompt] : [])];
        run("space.new", { folder: path, tab: `#${issue.number}`, argv, ...(routed ? {} : { task: prompt }) });
        if (shellTab) {
          const space = spaces().find((s) => s.folder === path);
          if (space) {
            run("tab.new", { space: space.id, name: "container", argv: [DCW, "sh", path] });
            run("tab.select", { id: space.tabs[0]?.id });
          }
        }
        setShared(LAST, { agent: agent.key, mode, shellTab });
        closeOverlay(props().overlay);
      } catch (e) { this.error = String(e.message ?? e); }
      finally { this.busy = false; cx.notify(); }
    });
    cx.notify();
  }

  // ---- drawing

  section(title, child, t, hint = "") {
    return v_flex().gap(6)
      .child(h_flex().gap(6).child(div().text_size(11).text_color(t.dim).child(title)).child(div().text_size(11).text_color(t.dim).child(hint)))
      .child(child);
  }

  chip(id, label, selected, onClick, t, icon = null) {
    return h_flex().id(id).h(26).px(9).gap(6).items_center().rounded(7).cursor_pointer().flex_none()
      .bg(selected ? t.selected : t.raised).text_color(selected ? t.foreground : t.muted)
      .hover((s) => s.bg(t.hover)).on_click((_e, cx) => { onClick(); cx.notify(); })
      .when(Boolean(icon), (e) => e.child(icon)).child(label);
  }

  agentIcon(a, t) {
    if (!a.icon) return null;
    return a.tint ? svg(a.icon).size(14).text_color(t.foreground) : image(a.icon).size(14);
  }

  agentRow(t) {
    if (!this.agents.length) return div().text_color(t.dim).child(this.error ?? "Checking installed agents…");
    return h_flex().flex_wrap().gap(6).children(this.agents.map((a) =>
      this.chip(`dcw-agent-${a.key}`, ROUTED.has(a.key) ? `${a.name} 🐳` : a.name, this.agent === a, () => { this.agent = a; }, t, this.agentIcon(a, t))));
  }

  render(_cx) {
    const t = theme();
    if (!this.issue) return div().p(16).bg(t.popover).text_color(t.dim).child("Open this from an issue in the dcw panel.");
    const routed = this.agent && ROUTED.has(this.agent.key);
    const ready = Boolean(this.agent) && !this.busy;
    return v_flex().id("dcw-start").size_full().p(16).gap(14).bg(t.popover).text_color(t.foreground).text_size(12.5)
      .child(v_flex().gap(2)
        .child(div().text_size(14).font_semibold().child(`Start work on #${this.issue.number}`))
        .child(div().text_color(t.dim).truncate().child(this.issue.title)))
      .child(this.section("Branch", div().h(30).px(10).flex().items_center().rounded(8).border_1().border_color(t.border).bg(t.background)
        .child(Input.new(this.branch).h_full().text_size(12).text_color(t.foreground)), t, "new worktree + devcontainer"))
      .child(this.section("Agent", this.agentRow(t), t,
        this.agent ? (routed ? "🐳 shell runs in the container" : "runs on the host, told to use `dcw exec`") : ""))
      .child(this.section("First task", h_flex().gap(6).children(MODES.map((m) =>
        this.chip(`dcw-mode-${m.id}`, m.label, this.mode === m.id, () => { this.mode = m.id; }, t))), t))
      .child(this.chip("dcw-shell-tab", this.shellTab ? "✓ Container shell tab" : "Container shell tab", this.shellTab, () => { this.shellTab = !this.shellTab; }, t))
      .child(div().flex_1())
      .child(h_flex().gap(8).items_center()
        .child(div().flex_1().min_w(0).text_size(11).text_color(t.ansi1).child(this.error ?? ""))
        .child(h_flex().id("dcw-cancel").h(30).px(12).items_center().rounded(8).cursor_pointer().text_color(t.muted)
          .hover((s) => s.bg(t.hover)).on_click(() => closeOverlay(props().overlay)).child("Cancel"))
        .child(h_flex().id("dcw-go").h(30).px(14).items_center().rounded(8).cursor_pointer()
          .bg(ready ? t.solid : t.raised).text_color(ready ? t.solid_foreground : t.dim)
          .on_click((_e, cx) => this.start(cx)).child(this.busy ? "Creating worktree…" : "Start")));
  }
}
