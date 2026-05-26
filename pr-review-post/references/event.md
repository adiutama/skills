# Event inference

## Stance to event (no user instructions)

| Session file stance              | GitHub event        |
|----------------------------------|---------------------|
| Approve                          | `APPROVE`           |
| Approve with notes               | `APPROVE`           |
| Request Changes                  | `REQUEST_CHANGES`   |
| Comment / missing / ambiguous    | `COMMENT`           |

## Inference from user instructions

| Instruction examples                          | Event               | Personal message       |
|-----------------------------------------------|---------------------|------------------------|
| "approve, great work"                         | `APPROVE`           | "great work"           |
| "lgtm" / "ship it" / "looks good"            | `APPROVE`           | none                   |
| "request changes — the naming is off"         | `REQUEST_CHANGES`   | derived from context   |
| "block this" / "block"                        | `REQUEST_CHANGES`   | none                   |
| "leave as comment" / "just comment"           | `COMMENT`           | none                   |
| "be encouraging" / "be firm"                  | preserve default    | tone guidance for body |

## Drop instructions

If the instructions say "drop N1 N2" (or similar), exclude those finding IDs from the post. Leave them in the session file unchanged (`Posted: ❌`).

## Tone

If the instructions include tone guidance, apply it to both the opener and the inline comment bodies.
