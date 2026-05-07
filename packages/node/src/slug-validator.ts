const SLUG_PATTERN = /^[a-z][a-z0-9\-]{0,63}$/

export const SLUG_RULES_HUMAN =
  "Workspace slugs must be lowercase letters, numbers, or hyphens. " +
  "Must start with a letter. 1-64 characters."

export function isValidSlug(slug: unknown): boolean {
  if (typeof slug !== "string" || slug.length === 0) return false
  return SLUG_PATTERN.test(slug)
}
