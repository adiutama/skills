---
name: study-pr
description: Visual-first, plain-language PR study—map the code change before questions, trace related behavior with evidence, keep a living notebook, and study until ready to review independently.
disable-model-invocation: true
compatibility: Requires gh CLI authenticated to GitHub, jq, and a local checkout of the repository.
metadata:
  argument-hint: "<PR URL or PR number>"
allowed-tools: Bash(gh:* git:* rg:* bash:* date:*) Read Write
---

Invoked as `/study-pr <PR URL or PR number>`. Missing or invalid → ask once; stop.

*Sit beside the learner. Let the code be the author in the room.*

## Session contract

- Simulate an author walkthrough without pretending to know private author intent. Answer from inspected evidence; label `PR`, `repository`, `inference`, or `unknown`.
- Follow the learner's questions. Offer a path when they are lost, but do not turn the session into a fixed lecture or quiz.
- Minimize cognitive load. Use familiar words, short explanations, analogy, and the smallest useful visual before introducing code vocabulary.
- Explain technically: open the changed code, then follow definitions, callers, consumers, tests, contracts, configuration, migrations, and runtime or data flow as the question requires.
- Use **evidence → explanation → implication**. Cite repository evidence as `path:line`; link PR evidence to the relevant diff file and hunk when possible.
- Keep a living notebook after every substantive exchange. Never rely on chat history as the only record.
- Lead with a code-change guide before asking questions. The guide teaches the code; conversation history is supporting material, never its organizing spine.
- Treat the conversation as the shared surface after orientation. HTML is derived output; an annotated screenshot the learner attaches is explicit new input.
- Capture possible improvements as **review leads**, not findings. Do not assign severity or merge stance; a later review must judge them independently.
- If evidence cannot answer a question, say what is unknown and record the question for the human author. Never fill the author's chair with invention.

## Step 1 — Start the pairing session

Resolve the PR and confirm the local checkout matches its repository. Parse `PR_OWNER` and `PR_REPO` from the resolved PR URL; PR identity is authoritative even when its branch is not local. Gather:

- `gh pr view <PR> --json number,title,body,url,author,baseRefName,headRefName,headRefOid,files,commits`
- `gh pr diff <PR>`
- repository instructions plus architecture or domain docs nearest the touched code

Allocate the notebook:

```bash
ARTIFACT_GITHUB_OWNER=<PR_OWNER> ARTIFACT_GITHUB_REPO=<PR_REPO> bash <SKILL_DIR>/scripts/artifacts.sh allocate study-pr <headRefName>
```

Reject an unparseable PR URL; never accept `_local/_local` for a resolved GitHub PR.

Parse `SESSION_PATH`; set `HTML_PATH` to the same path with `.html` replacing `.md`. Read `<SKILL_DIR>/references/notebook.md`, `<SKILL_DIR>/references/revisions.md`, `<SKILL_DIR>/references/explanations.md`, `<SKILL_DIR>/references/study-page.md`, and `<SKILL_DIR>/assets/study.html`; initialize the notebook.

Before asking the learner anything, inspect enough related code to build an initial model:

1. claimed intent and observable behavior;
2. before → after behavior;
3. one main control, data, request, or event path;
4. every touched file's role and reason for changing;
5. adjacent callers, consumers, contracts, configuration, and tests;
6. essential terms plus evidence gaps.

Generate `HTML_PATH` as the initial code-change guide. Print its clickable path with a two-sentence orientation and invite the learner to read, annotate, or screenshot it. Only then ask for their first question.

Completion: the notebook identifies the exact PR and head SHA, and the guide gives a useful code map without conversation history.

## Step 2 — Guard the revision

Pin all explanations to the notebook's current `Head`. Record `Last head check` in UTC and use a default `Head check interval` of 10 minutes; honor a learner-supplied interval for the rest of the session.

Re-run `gh pr view <PR> --json headRefOid,commits,files` only when:

- the learner asks to refresh, sync, or check the PR;
- the session resumes after a pause;
- the interval has elapsed when the next learner message arrives;
- cited code no longer matches the inspected evidence;
- the session is about to be marked `ready` or closed.

Do not poll in the background and do not check once per question. Inside the interval, reuse the pinned SHA and continue without GitHub calls. When checking, update `Last head check` even if the SHA is unchanged.

Same SHA → continue silently. Different SHA → pause the current thread and follow `<SKILL_DIR>/references/revisions.md`. Do not answer from a mixture of revisions.

Completion: the cached check is still fresh or has just been refreshed; after drift, the notebook's head equals the live PR head and every carried-forward explanation has a revision status.

## Step 3 — Refine the guide through conversation

After the learner views the guide, invite the first question. A useful opener is:

> What part of the guide is still unclear, surprising, or worth tracing deeper?

For each question:

1. Restate the question narrowly enough to investigate.
2. Inspect the diff and the minimum related code needed to answer it.
3. Explain using `<SKILL_DIR>/references/explanations.md`: plain mental model, one fitting visual or analogy, then code evidence.
4. Add provenance labels and file/line citations without interrupting the explanation's flow.
5. Ask whether the explanation matches the learner's model or exposes the next question.
6. Update the notebook; when the answer changes or deepens the code model, regenerate the guide before continuing.

When the learner attaches a screenshot of the study guide or their own sketch:

1. Inspect every visible annotation, arrow, grouping, deletion, and question.
2. Restate the interpretation briefly; ask only when handwriting or intent is ambiguous.
3. Treat annotations as evidence of the learner's model, never as evidence that the code behaves that way.
4. Check technical claims against PR or repository evidence.
5. Answer, correct, or extend the sketch in the conversation; record the annotations and outcome in the notebook.
6. Regenerate the study guide so the learner can inspect the corrected map.

Do not force one-question-at-a-time pedagogy when several questions form one causal thread. Keep the thread coherent; then pause.

Completion: every answer is evidence-bound, visible in the conversation, and represented in the notebook.

An answer is not complete merely because it is technically correct. It is complete when the learner can restate it without borrowing unexplained jargon.

## Step 4 — Turn understanding into intuition

When the learner understands a path, ask them what follows from it: affected consumers, preserved assumptions, boundary behavior, failure modes, concurrency, compatibility, or missing tests. Inspect their hypothesis together.

Record:

- confirmed understanding;
- corrected misconceptions and the evidence that corrected them;
- implications derived by the learner;
- questions only the author can answer;
- review leads worth investigating later.

Keep exploration and judgment separate. A suspicious pattern becomes a review lead with supporting evidence and uncertainty, never an automatic finding.

Completion: the learner can connect at least one implementation detail to an externally observable or downstream implication.

## Step 5 — Close the session

When the learner says they are ready, ask for a short teach-back:

1. What is the PR trying to change?
2. How does the main path work before and after?
3. What components, contracts, or invariants are affected?
4. What would you inspect most carefully during review?
5. What remains unknown?

Resolve contradictions by returning to evidence. Update the notebook with the learner's final model. Mark the session `ready` only when all five are answered without contradicting inspected evidence; otherwise mark it `paused`, preserving the precise gaps.

Regenerate `HTML_PATH` from the completed notebook. Synthesize the final code model; do not turn the main guide into a chronological transcript.

Print clickable paths to the notebook and study guide plus a concise readiness summary. Stop without a verdict, severity labels, or GitHub review comments.

## Boundaries

- Do not invoke, imitate, or pre-empt another review or submission workflow.
- Do not modify the PR, working tree, GitHub state, or production systems.
- Do not paste the full diff into either artifact. Use small excerpts and citations.
- Do not silently rewrite old notes after a force-push or new commit; preserve them as revision history.
- Do not assume browser interactions return automatically. Invite screenshots or exported annotations when a visual round-trip would help.
- Do not read generated HTML as code evidence. The notebook is authoritative; attached annotations are user input and must be verified against code.
