export const invocation = "/review-pr";

export function reviewPrInvocation(...args) {
  return [invocation, ...args].join(" ");
}
