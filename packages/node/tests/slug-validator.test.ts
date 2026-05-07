import { isValidSlug } from "../src/slug-validator"

describe("slug-validator", () => {
  it.each([
    ["a", true],
    ["checkout-2", true],
    ["a1-b2-c3", true],
    ["a" + "b".repeat(63), true],
    [null, false],
    [undefined, false],
    ["", false],
    ["1-checkout", false],
    ["-checkout", false],
    ["Checkout", false],
    ["check_out", false],
    ["check.out", false],
    ["check out", false],
    ["a" + "b".repeat(64), false],
  ])("isValidSlug(%j) === %s", (slug, expected) => {
    expect(isValidSlug(slug)).toBe(expected)
  })
})
