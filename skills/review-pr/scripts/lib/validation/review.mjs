export function validateReview(review, source = "review") {
  if (review === null || typeof review !== "object" || Array.isArray(review)) {
    throw new Error(`${source} must be a JSON object`);
  }
  const verdict = review.verdict?.value;
  if (verdict !== "approve" && verdict !== "reject") {
    throw new Error(`${source} verdict must be approve or reject`);
  }
  if (!Array.isArray(review.findings)) throw new Error(`${source} findings must be an array`);

  for (const finding of review.findings) {
    if (typeof finding.blocking !== "boolean") {
      throw new Error(`${source} finding ${finding.id ?? "unknown"} must declare blocking as true or false`);
    }
    if (finding.severity === "critical" && !finding.blocking) {
      throw new Error(`${source} critical finding ${finding.id ?? "unknown"} must be blocking`);
    }
    if (finding.severity === "nit" && finding.blocking) {
      throw new Error(`${source} nit finding ${finding.id ?? "unknown"} cannot be blocking`);
    }
  }

  const hasBlockingFinding = review.findings.some((finding) => finding.blocking);
  if (verdict === "approve" && hasBlockingFinding) {
    throw new Error(`${source} cannot approve while a blocking finding remains`);
  }
  if (verdict === "reject" && !hasBlockingFinding) {
    throw new Error(`${source} cannot reject without a blocking finding`);
  }
  return review;
}
