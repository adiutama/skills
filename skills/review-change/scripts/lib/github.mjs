import { createHash } from "node:crypto";
import { commandExists, run } from "./command.mjs";

function parseJson(value, source) {
  try {
    return JSON.parse(value);
  } catch (error) {
    throw new Error(`${source} returned invalid JSON: ${error.message}`);
  }
}

function parsePages(value, source) {
  const parsed = parseJson(value, source);
  if (!Array.isArray(parsed)) throw new Error(`${source} did not return an array`);
  return parsed.every(Array.isArray) ? parsed.flat() : parsed;
}

function fetchAll({ cwd, endpoint, source }) {
  const raw = run("gh", ["api", endpoint, "--paginate", "--slurp"], { cwd });
  return parsePages(raw, source);
}

function canonicalize(value) {
  if (Array.isArray(value)) return value.map(canonicalize);
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.keys(value).sort().map((key) => [key, canonicalize(value[key])]));
  }
  return value;
}

export function pullRequestFingerprint(pullRequest) {
  if (!pullRequest) return null;
  const byAnotherAuthor = (item) => item?.user?.login !== pullRequest.viewerLogin;
  const reviewState = {
    metadata: pullRequest.metadata,
    comments: {
      conversation: pullRequest.comments.conversation.filter(byAnotherAuthor),
      inline: pullRequest.comments.inline.filter(byAnotherAuthor),
      reviews: pullRequest.comments.reviews.filter(byAnotherAuthor),
    },
  };
  return createHash("sha256").update(JSON.stringify(canonicalize(reviewState))).digest("hex");
}

export function collectPullRequest({ cwd, owner, repo, branch, detached = false, number, required = false }) {
  if (owner === "_local") return null;
  if (!commandExists("gh")) {
    if (required) throw new Error("cannot verify PR activity because gh is unavailable");
    return null;
  }
  const selector = number ? String(number) : (!detached && branch ? branch : null);
  if (!selector) {
    if (required) throw new Error("could not verify the existing pull request");
    return null;
  }
  const metadataRaw = run("gh", [
    "pr", "view", selector, "--repo", `${owner}/${repo}`,
    "--json", "number,title,body,url,baseRefName,headRefName,headRefOid,state",
  ], { cwd, allowFailure: true });
  if (!metadataRaw) {
    if (required) throw new Error("could not verify the existing pull request");
    return null;
  }
  const metadata = parseJson(metadataRaw, "gh pr view");
  if (metadata.state !== "OPEN") {
    if (required) throw new Error(`pull request #${metadata.number} is no longer open`);
    return null;
  }
  const viewerLogin = run("gh", ["api", "user", "--jq", ".login"], { cwd });

  return {
    metadata,
    viewerLogin,
    comments: {
      conversation: fetchAll({ cwd, endpoint: `repos/${owner}/${repo}/issues/${metadata.number}/comments`, source: "pull request conversation comments" }),
      inline: fetchAll({ cwd, endpoint: `repos/${owner}/${repo}/pulls/${metadata.number}/comments`, source: "pull request inline comments" }),
      reviews: fetchAll({ cwd, endpoint: `repos/${owner}/${repo}/pulls/${metadata.number}/reviews`, source: "pull request reviews" }),
    },
  };
}
