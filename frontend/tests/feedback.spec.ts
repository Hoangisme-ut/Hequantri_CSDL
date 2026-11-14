import { expect, test } from "@playwright/test"

test.describe("Feedback Review", () => {
  test("Feedback page is accessible to Admin", async ({ page }) => {
    await page.goto("/feedback")

    await expect(
      page.getByText("Visitor Feedback", { exact: true }),
    ).toBeVisible()

    await expect(
      page.getByText("Submission Detail", { exact: true }),
    ).toBeVisible()

    await expect(
      page.getByText("Moderation actions", { exact: true }),
    ).toBeVisible()
  })

  test("Shows search input and status filters", async ({ page }) => {
    await page.goto("/feedback")

    await expect(
      page.getByRole("textbox", { name: "Search feedback" }),
    ).toBeVisible()

    for (const status of ["All", "Pending", "Approved", "Hidden"]) {
      await expect(
        page.getByRole("button", { name: status, exact: true }),
      ).toBeVisible()
    }
  })

  test("Shows feedback empty state when no records match", async ({ page }) => {
    await page.goto("/feedback")

    const search = page.getByRole("textbox", {
      name: "Search feedback",
    })

    await search.fill(`no-feedback-${Date.now()}`)

    await expect(
      page.getByText("No feedback submissions", { exact: true }),
    ).toBeVisible()
  })

  test("Shows selection prompt when there is no matching feedback", async ({
    page,
  }) => {
    await page.goto("/feedback")

    await page
      .getByRole("textbox", {
        name: "Search feedback",
      })
      .fill(`no-feedback-${Date.now()}`)

    await expect(
      page.getByText("Submission Detail", { exact: true }),
    ).toBeVisible()

    await expect(
      page.getByRole("button", { name: "Approve", exact: true }),
    ).toBeDisabled()

    await expect(
      page.getByRole("button", { name: "Hide", exact: true }),
    ).toBeDisabled()
  })

  test("Can switch between feedback status filters", async ({ page }) => {
    await page.goto("/feedback")

    for (const [label, value] of [
      ["Pending", "pending"],
      ["Approved", "approved"],
      ["Hidden", "hidden"],
      ["All", null],
    ] as const) {
      const feedbackResponse = page.waitForResponse((response) => {
        const url = new URL(response.url())
        return (
          url.pathname === "/api/v1/feedbacks/" &&
          url.searchParams.get("status") === value &&
          response.request().method() === "GET"
        )
      })

      await page
        .getByRole("button", {
          name: label,
          exact: true,
        })
        .click()

      expect((await feedbackResponse).status()).toBe(200)

      await expect(
        page.getByText("Visitor Feedback", { exact: true }),
      ).toBeVisible()
    }
  })
})
