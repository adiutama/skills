# Low-load explanations

Make the code easier to hold in working memory. Use this order for every new concept:

1. **Plain model** — answer “what happens?” and “why does it matter?” in one or two familiar sentences.
2. **Bridge** — choose one analogy or visual that exposes the relationship.
3. **Code anchor** — show the smallest relevant code excerpt or `path:line` trail.
4. **Depth on demand** — introduce implementation detail only when it answers the current question.

## Language

- Use one new idea per paragraph.
- Prefer concrete verbs: “saves,” “calls,” “waits,” “rejects,” “retries.”
- Use the codebase's exact technical term only after explaining it in ordinary words: “Running it twice has the same effect as once; this is called idempotency.”
- Define domain words at first use and keep a short glossary in the notebook.
- Never replace one unfamiliar term with several unfamiliar synonyms.
- If the learner says an explanation is confusing, rebuild it from a smaller example; do not repeat the same explanation with shuffled words.

## Analogy

Use analogy to bridge into literal behavior, not replace it. State:

1. the familiar situation;
2. what each part maps to in the code;
3. where the analogy stops matching.

Skip analogy when the literal explanation is already simpler.

## Choose one visual

| Relationship | Default visual |
|---|---|
| exact before/after or field mapping | small table |
| control, data, request, or event sequence | ASCII arrows |
| branching decisions or fallback behavior | ASCII tree |
| ownership, nesting, or dependencies | indented tree |
| lifecycle or state changes | state diagram |
| several spatial relationships that text obscures | linked SVG/image |

Examples:

```text
request -> handler -> validator -> database
                         |
                         +-> reject invalid input
```

```text
Does the cache contain the key?
├─ yes -> return cached value
└─ no  -> load -> cache -> return
```

Do not stack a table, diagram, analogy, and prose that all say the same thing. Use the smallest visual that removes a real ambiguity. For a generated SVG or image, link it in the conversation and describe its meaning in the notebook so the session never depends on pixels alone.

## Check understanding

Ask for a lightweight restatement after a difficult concept: “What do you think happens next?” or “How would you describe this path?” If the learner must copy the technical terms verbatim, simplify again.
