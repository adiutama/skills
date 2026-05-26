# Body guidance

## Structure

**When a personal message was inferred from user instructions:**

```
<personal message>

<transition sentence>
```

**When no personal message:** write a dynamic 1–2 sentence opener reflecting the actual tone of the findings — encouraging for a clean diff with only nits, more direct when warnings are present. Draw on the PR title, branch name, and finding severities to make it feel specific rather than generic. Keep it conversational; avoid em-dashes. Append the transition sentence as a new paragraph.

## Transition sentence

A short, natural sentence bridging the opener to the inline comments. It must convey that findings come from an AI-assisted review and are offered as additional things to consider. Vary the phrasing every time; never use em-dashes; write like a human colleague leaving a note.

Spirit examples (never copy verbatim):
- "Here are a few things an AI review flagged that might be worth a second look."
- "My AI reviewer surfaced some points you may want to consider before merging."
- "Ran this through an automated review so dropping the notes here for your consideration."
- "Some AI-assisted observations that could be helpful. Take what's useful."

## Inline comment format by severity

| Severity | Fields |
|----------|--------|
| critical | one-line summary · `*Risk:*` · `*Suggestion:*` |
| warning  | one line · optional `*Why:*` · `*Suggestion:*` |
| nit      | one line · optional `*Suggestion:*` |
