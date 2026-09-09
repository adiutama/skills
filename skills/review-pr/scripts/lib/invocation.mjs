export const invocation = "/review-pr";

export function reviewPrInvocation(...args) {
  return [invocation, ...args].join(" ");
}

export function sessionInvocation(context, ...args) {
  return reviewPrInvocation(...args, ...(context.identity && context.contextPath ? ["--context", JSON.stringify(context.contextPath)] : []));
}
