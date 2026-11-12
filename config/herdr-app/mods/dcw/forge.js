// Where the issues come from: the space's repo, its origin remote, GitLab or GitHub.
import { exec } from "herdr";

async function git(cwd, args) {
  const r = await exec("git", ["-C", cwd, ...args]);
  if (r.code !== 0) throw new Error((r.stderr || r.stdout).trim().split("\n")[0] || "git failed");
  return r.stdout.trim();
}

// https://gitlab.com/a/b.git, git@gitlab.com:a/b.git, ssh://git@host:22/a/b.git -> {host, path}
export function parseRemote(url) {
  let m = url.match(/^[a-z+]+:\/\/(?:[^@/]+@)?([^/:]+)(?::\d+)?\/(.+?)(?:\.git)?\/?$/i);
  if (!m) m = url.match(/^(?:[^@]+@)?([^:]+):(.+?)(?:\.git)?\/?$/);
  return m ? { host: m[1], path: m[2] } : null;
}

export async function repoOf(cwd) {
  const common = await git(cwd, ["rev-parse", "--path-format=absolute", "--git-common-dir"]);
  const main = common.endsWith("/.git") ? common.slice(0, -5) : common;
  const url = await git(main, ["remote", "get-url", "origin"]).catch(() => "");
  const remote = parseRemote(url);
  const kind = !remote ? null : remote.host.includes("github") ? "github" : "gitlab";
  return { main, name: main.split("/").pop(), remote, kind };
}

function cliError(tool, output) {
  const text = output.trim();
  if (/401|unauthorized|auth login|not logged/i.test(text)) return `Run \`${tool} auth login\` first`;
  try { return JSON.parse(text).error?.message ?? text.split("\n")[0]; } catch { return text.split("\n")[0] || `${tool} failed`; }
}

// Issues as {number, title, labels: [name], author, updated, url, body}
export async function listIssues(repo) {
  if (repo.kind === "gitlab") {
    // glab finds the project from the checkout's remote (and the host's login).
    let r;
    try { r = await exec("glab", ["issue", "list", "--output", "json", "--per-page", "50"], { cwd: repo.main }); }
    catch { throw new Error("glab is not installed"); }
    let items;
    try { items = JSON.parse(r.stdout); } catch { items = null; }
    if (r.code !== 0 || !Array.isArray(items)) throw new Error(cliError("glab", r.stdout || r.stderr));
    return items.map((i) => ({
      number: i.iid, title: i.title, labels: i.labels ?? [], author: i.author?.username ?? "",
      updated: i.updated_at, url: i.web_url, body: i.description ?? "",
    }));
  }
  if (repo.kind === "github") {
    const r = await exec("gh", ["issue", "list", "-R", `${repo.remote.host}/${repo.remote.path}`, "--state", "open",
      "--limit", "50", "--json", "number,title,labels,author,updatedAt,url,body"]);
    if (r.code !== 0) throw new Error(cliError("gh", r.stderr || r.stdout));
    return JSON.parse(r.stdout).map((i) => ({
      number: i.number, title: i.title, labels: i.labels.map((l) => l.name), author: i.author?.login ?? "",
      updated: i.updatedAt, url: i.url, body: i.body ?? "",
    }));
  }
  throw new Error("No GitLab/GitHub origin remote");
}

export function viewCommand(repo, number) {
  return repo.kind === "github" ? `gh issue view ${number}` : `glab issue view ${number}`;
}
