export const invocation = "/review-change";

export function reviewChangeInvocation(...args) {
  return [invocation, ...args].join(" ");
}
