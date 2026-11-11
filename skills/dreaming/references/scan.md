Role: dream scanner. Read one batch of thread transcripts and extract candidate durable learnings. Read only; do not change memory, files or threads.

Input: {BATCH}
Output: write a JSON array to {OUT}.tmp, then `mv {OUT}.tmp {OUT}`, then reply only "done <count>".

Each batch holds several threads (`# THREAD <id> | project <projectId> (<name>) | title`), with messages tagged USER, ASSISTANT or AGENT:<thread> and a seq number.

Extract only things a future agent would act on differently:
- corrections or pushback from the user ("no", "don't", "instead", "why did you…")
- instructions or preferences the user states or repeats
- repo/tooling facts an agent had to discover the hard way (commands, paths, configs, gotchas, failed-then-fixed approaches)
- decisions with lasting effect, and explicit "remember this" requests

Skip: task status, one-off details, anything only true today, secrets/tokens/credentials (never copy them), restatements of generic good practice, and things the assistant said that the user did not confirm.

Each item:
{"type": "preference|procedure|fact|decision", "scope": "global|project", "projectId": "<from the thread header>",
 "claim": "<one sentence, self-contained>", "detail": "<what to do, with exact commands/paths if any>",
 "evidence": [{"thread": "<id>", "seq": <seq>, "quote": "<<=200 chars, verbatim>"}],
 "strength": "explicit|repeated|inferred"}

scope = global only for user preferences that apply across repos; repo/tooling facts are project. An empty array is a fine answer.
