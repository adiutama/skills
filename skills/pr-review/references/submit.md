# Submit

The user's explicit `submit` is the only authorization to post. Use the latest completed `NN.report.md` for the PR reviewed in this conversation.

1. **Select.** Take the comma-separated IDs (default: none, which posts the verdict and message only). The report footer's `findings:` entry gives each ID's `path`, `line`, `side`, placement, and posting status; the finding's "Comment to post" gives the `body`, without the blockquote markers. Refuse IDs that are unknown, `duplicate`, or already `posted`. Use `--message` text verbatim when given, adding the authorship line if it's missing.
2. **Recheck the PR.** `gh pr view <n> --json state,headRefOid`. If it's not `OPEN`, stop. If `headRefOid` differs from the reviewed head (the report footer) and the user didn't include `--accept-moved-head`, stop: say the head moved from `<old>` to `<new>`, that inline lines may now be wrong, and that a re-review is recommended. Never accept the move on the user's behalf. Acceptance covers only the head seen during that attempt.
3. **Post one review.** Write the payload to `<S>/submit.json` and run `gh api repos/<o>/<r>/pulls/<n>/reviews --method POST --input <S>/submit.json`:

   ```json
   {
     "commit_id": "<reviewed head>",
     "event": "APPROVE | REQUEST_CHANGES",
     "body": "<message>",
     "comments": [{ "path": "<path>", "line": 42, "side": "<RIGHT | LEFT>", "body": "<comment>" }]
   }
   ```

   `comments` holds only selected `inline` findings; selected `body` findings are appended to `body` under "Other findings:". GitHub rejects the whole review if any inline line is outside the diff — on that error, move the offending finding to `body` and retry once.

   `Approve` → `APPROVE`, `Request changes` → `REQUEST_CHANGES`. `commit_id` stays the reviewed head so inline lines match the code you read. If GitHub rejects the event (e.g. you're the author), report it and offer `COMMENT`; don't switch silently.
4. **Record.** Change the posted findings' footer entries to `posted` in the report. Report the review URL, event, and finding IDs.
