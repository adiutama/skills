import { createHash } from "node:crypto";

const rings = ["direct", "glue", "contract", "parallel", "integration", "operational"];
const statuses = new Set(["checked", "not_applicable", "not_verified"]);

function object(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function nonempty(value) {
  return typeof value === "string" && value.trim().length > 0;
}

export function contentHash(value) {
  return createHash("sha256").update(JSON.stringify(value)).digest("hex");
}

export const studyHash = contentHash;

function stringArray(value, label) {
  if (!Array.isArray(value) || value.some((item) => !nonempty(item))) throw new Error(`${label} must be an array of non-empty text`);
}

export function validateSummary(summary, context, source = "summary") {
  if (!object(summary)) throw new Error(`${source} must be a JSON object`);
  if (!object(summary.study)) throw new Error(`${source} study must be an object`);
  if (!Array.isArray(summary.updates)) throw new Error(`${source} updates must be an array`);

  const pass = context.passes.at(-1);
  const study = summary.study;
  if (!Number.isInteger(study.revision) || study.revision < 1) throw new Error(`${source} study revision must be a positive integer`);
  if (!Number.isInteger(study.writtenAtPass) || study.writtenAtPass < 1) throw new Error(`${source} study writtenAtPass must be a positive integer`);
  for (const field of ["oneSentence", "purpose"]) {
    if (!nonempty(study[field])) throw new Error(`${source} study ${field} must be non-empty text`);
  }
  for (const field of ["claimedIntent", "observedBehavior", "before", "after", "flow", "components", "contracts", "unknowns"]) {
    if (!Array.isArray(study[field])) throw new Error(`${source} study ${field} must be an array`);
  }
  for (const field of ["claimedIntent", "observedBehavior", "before", "after", "contracts", "unknowns"]) {
    stringArray(study[field], `${source} study ${field}`);
  }
  for (const [index, item] of study.flow.entries()) {
    if (!object(item) || !nonempty(item.step) || !nonempty(item.explanation)) throw new Error(`${source} study flow ${index + 1} must include a step and explanation`);
    stringArray(item.evidence, `${source} study flow ${index + 1} evidence`);
  }
  for (const [index, item] of study.components.entries()) {
    if (!object(item) || !nonempty(item.name) || !nonempty(item.role) || !nonempty(item.reason)) throw new Error(`${source} study component ${index + 1} must include name, role, and reason`);
    stringArray(item.evidence, `${source} study component ${index + 1} evidence`);
  }

  if (summary.updates.length !== context.passes.length) {
    throw new Error(`${source} must contain one update for each collected pass`);
  }
  summary.updates.forEach((update, index) => {
    const expectedPass = index + 1;
    const matchingPass = context.passes[index];
    if (!object(update) || update.pass !== expectedPass) throw new Error(`${source} update ${expectedPass} must match pass ${expectedPass}`);
    if (update.kind !== matchingPass.kind) throw new Error(`${source} update ${expectedPass} kind must be ${matchingPass.kind}`);
    if (update.head !== matchingPass.head) throw new Error(`${source} update ${expectedPass} head must match the collected pass`);
    if (!nonempty(update.summary)) throw new Error(`${source} update ${expectedPass} summary must be non-empty text`);
    if (!object(update.changes) || update.changes.code !== matchingPass.changes.code || update.changes.activity !== matchingPass.changes.activity) {
      throw new Error(`${source} update ${expectedPass} changes must match the collected pass`);
    }
    if (!Array.isArray(update.blastRadius)) throw new Error(`${source} update ${expectedPass} blastRadius must be an array`);
    const seen = new Set();
    for (const item of update.blastRadius) {
      if (!rings.includes(item?.ring)) throw new Error(`${source} update ${expectedPass} has an invalid blast-radius ring`);
      if (seen.has(item.ring)) throw new Error(`${source} update ${expectedPass} repeats the ${item.ring} ring`);
      if (!statuses.has(item.status)) throw new Error(`${source} update ${expectedPass} ${item.ring} has an invalid status`);
      if (!Array.isArray(item.scope) || !Array.isArray(item.evidence) || !nonempty(item.notes)) {
        throw new Error(`${source} update ${expectedPass} ${item.ring} must include scope, evidence, and notes`);
      }
      stringArray(item.scope, `${source} update ${expectedPass} ${item.ring} scope`);
      stringArray(item.evidence, `${source} update ${expectedPass} ${item.ring} evidence`);
      seen.add(item.ring);
    }
    const missing = rings.filter((ring) => !seen.has(ring));
    if (missing.length) throw new Error(`${source} update ${expectedPass} is missing blast-radius rings: ${missing.join(", ")}`);
    if (!Array.isArray(update.reviewTargets)) throw new Error(`${source} update ${expectedPass} reviewTargets must be an array`);
    stringArray(update.reviewTargets, `${source} update ${expectedPass} reviewTargets`);
  });

  const priorUpdates = context.summary?.updates ?? [];
  for (let index = 0; index < priorUpdates.length; index += 1) {
    if (contentHash(summary.updates[index]) !== priorUpdates[index]) {
      throw new Error(`${source} changed the already-checkpointed update for pass ${index + 1}`);
    }
  }

  const prior = context.summary?.study;
  const hash = studyHash(study);
  if (!prior) {
    if (study.revision !== 1 || study.writtenAtPass !== pass.number) {
      throw new Error(`${source} must establish study revision 1 during the first summary checkpoint`);
    }
  } else if (hash !== prior.hash) {
    if (study.revision !== prior.revision + 1 || study.writtenAtPass !== pass.number || !nonempty(study.refreshReason)) {
      throw new Error(`${source} changed the durable study without a new revision and refresh reason`);
    }
  } else if (study.revision !== prior.revision) {
    throw new Error(`${source} study revision changed without changing the study`);
  }

  return summary;
}
