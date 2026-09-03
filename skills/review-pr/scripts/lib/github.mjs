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

export function parsePullRequestTarget(value, repository) {
  const input = String(value ?? "").trim();
  const errorMessage = "pull request target must be a GitHub PR URL or positive PR number";
  let url;
  let match;

  if (!input) return null;
  if (/^[1-9][0-9]*$/.test(input)) {
    if (repository.owner === "_local") {
      throw new Error("a pull request number requires a GitHub origin remote");
    }
    return {
      owner: repository.owner,
      repo: repository.repo,
      number: Number(input),
    };
  }
  try {
    url = new URL(input);
  } catch {
    throw new Error(errorMessage);
  }
  match = url.hostname === "github.com"
    && url.pathname.match(/^\/([^/]+)\/([^/]+)\/pull\/([1-9][0-9]*)\/?$/);
  if (!match) throw new Error(errorMessage);
  return {
    owner: match[1],
    repo: match[2],
    number: Number(match[3]),
  };
}

function pullRequestSelector({ branch, detached, number }) {
  if (number) return String(number);
  if (!detached && branch) return branch;
  return null;
}

function readPullRequestMetadata({ cwd, owner, repo, selector }) {
  const raw = run("gh", [
    "pr",
    "view",
    selector,
    "--repo",
    `${owner}/${repo}`,
    "--json",
    "number,title,body,url,baseRefName,headRefName,headRefOid,state",
  ], {
    cwd,
    allowFailure: true,
  });

  return raw ? parseJson(raw, "gh pr view") : null;
}

function collectPullRequestComments({ cwd, owner, repo, number }) {
  const root = `repos/${owner}/${repo}`;

  return {
    conversation: fetchAll({
      cwd,
      endpoint: `${root}/issues/${number}/comments`,
      source: "pull request conversation comments",
    }),
    inline: fetchAll({
      cwd,
      endpoint: `${root}/pulls/${number}/comments`,
      source: "pull request inline comments",
    }),
    reviews: fetchAll({
      cwd,
      endpoint: `${root}/pulls/${number}/reviews`,
      source: "pull request reviews",
    }),
  };
}

export function collectPullRequest({
  cwd,
  owner,
  repo,
  branch,
  detached = false,
  number,
  required = false,
}) {
  const selector = pullRequestSelector({ branch, detached, number });
  let metadata;
  let viewerLogin;

  if (owner === "_local") return null;
  if (!commandExists("gh")) {
    if (required) throw new Error("cannot verify PR activity because gh is unavailable");
    return null;
  }
  if (!selector) {
    if (required) throw new Error("could not verify the existing pull request");
    return null;
  }
  metadata = readPullRequestMetadata({
    cwd,
    owner,
    repo,
    selector,
  });
  if (!metadata) {
    if (required) throw new Error("could not verify the existing pull request");
    return null;
  }
  if (metadata.state !== "OPEN") {
    if (required) throw new Error(`pull request #${metadata.number} is no longer open`);
    return null;
  }
  viewerLogin = run(
    "gh",
    ["api", "user", "--jq", ".login"],
    { cwd },
  );

  return {
    metadata,
    viewerLogin,
    comments: collectPullRequestComments({
      cwd,
      owner,
      repo,
      number: metadata.number,
    }),
  };
}
