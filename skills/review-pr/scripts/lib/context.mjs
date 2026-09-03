import { randomUUID } from "node:crypto";
import {
  existsSync,
  mkdirSync,
  readFileSync,
  renameSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { basename, dirname, join } from "node:path";
import {
  artifactRoot,
  repositoryContext,
  slug,
} from "./git.mjs";

export function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

export function writeJson(path, value) {
  mkdirSync(dirname(path), { recursive: true });
  const temporary = join(dirname(path), `.json-${randomUUID()}.tmp`);
  writeFileSync(temporary, `${JSON.stringify(value, null, 2)}\n`);
  renameSync(temporary, path);
}

export const readContext = readJson;
export const writeContext = writeJson;

export function resolveContext({ cwd, env }) {
  const repository = repositoryContext(cwd);
  const root = artifactRoot({ root: repository.root, env });
  const path = join(
    root,
    repository.owner,
    repository.repo,
    slug(repository.branch),
    "review-pr",
    "context.json",
  );

  if (!existsSync(path)) {
    throw new Error(
      `no review-pr session found for ${repository.owner}/${repository.repo} on ${repository.branch}`,
    );
  }

  return path;
}

export function archiveContext(contextPath, context, reason) {
  const session = dirname(contextPath);
  const stamp = new Date().toISOString().replaceAll(":", "-").replaceAll(".", "-");
  const archive = join(session, "archive", `${stamp}-${reason}-${randomUUID()}`);
  mkdirSync(archive, { recursive: true });

  const archived = structuredClone(context);
  const relocate = (path) => {
    if (!path) return path;
    const target = join(archive, basename(path));
    if (existsSync(path)) renameSync(path, target);
    return target;
  };
  for (const key of Object.keys(archived.sources ?? {})) {
    archived.sources[key] = relocate(archived.sources[key]);
  }
  if (archived.summary) {
    archived.summary.data = relocate(archived.summary.data);
    archived.summary.report = relocate(archived.summary.report);
  }
  for (const pass of archived.passes ?? []) {
    pass.diff = relocate(pass.diff);
    pass.activity = relocate(pass.activity);
    pass.review = relocate(pass.review);
    pass.report = relocate(pass.report);
  }
  archived.output = archived.passes?.at(-1)?.review ?? null;
  archived.archived = { reason, at: new Date().toISOString() };
  writeJson(join(archive, "context.json"), archived);
  rmSync(contextPath, { force: true });
  return archive;
}
