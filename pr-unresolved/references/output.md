# Output format

## Header

```
# Unresolved feedback — <PR title>
<PR URL>
N critical · N warning · N nit
```

## Finding block

One block per finding:

```
### <ID> — <short title>

| Field    | Value                    |
|----------|--------------------------|
| Severity | critical / warning / nit |
| Location | `path/to/file:LINE`      |
| Reviewer | @handle                  |

**Comment** (paste `body_excerpt` verbatim — do not rephrase, reformat, or modify):

> <body_excerpt>

<comment URL>
```

For threads with `anchor_moved: true`, add a note below the table:
> ⚠️ File modified since comment — issue may still be present.

For threads with replies, use the last reply's `body_excerpt`, not the first.

## Findings index

Append after all finding blocks:

```
---
## Findings index

C1 — <title>  path/to/file:LINE
W1 — <title>  path/to/file:LINE
N1 — <title>  path/to/file:LINE
```

## Severity scale

Assign IDs: `C1, C2…` critical · `W1, W2…` warning · `N1, N2…` nit

| Level    | Examples                                                    |
|----------|-------------------------------------------------------------|
| critical | security issues, auth bypass, data loss, broken behavior    |
| warning  | correctness bugs, missing error handling, UX regressions    |
| nit      | accessibility, style, naming, minor cleanup                 |
