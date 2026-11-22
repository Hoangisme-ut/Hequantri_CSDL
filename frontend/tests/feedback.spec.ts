import { expect, test, type Page } from "@playwright/test"

const feedbackFixture = {
  id: "11111111-1111-4111-8111-111111111111",
  user_id: "22222222-2222-4222-8222-222222222222",
  artifact_id: "33333333-3333-4333-8333-333333333333",
  visitor_name: "Sample visitor",
  visitor_email: "visitor@example.com",
  artifact_title: "Sample artifact",
  artifact_code: "ART-001",
  site_name: "Sample heritage site",
  rating: 5,
  comment: "A sample feedback for Playwright testing.",
  status: "pending",
  created_at: "2026-11-20T08:00:00Z",
  updated_at: "2026-11-22T08:00:00Z",
}

const feedbackListUrl = "/api/v1/feedbacks/"

async function mockFeedbackApi(
  page: Page,
  options: { conflict?: boolean } = {},
) {
  let feedback = { ...feedbackFixture }
  let listRequestCount = 0
  let moderationRequestBody: Record<string, unknown> | null = null

  await page.route("**/api/v1/feedbacks**", async (route) => {
    const request = route.request()
    const url = new URL(request.url())

    if (
      request.method() === "GET" &&
      url.pathname === feedbackListUrl
    ) {
      listRequestCount++

      await route.fulfill({
        status: 200,
        contentType: "application/json",
        json: {
          data: [feedback],
          count: 1,
        },
      })
      return
    }

    if (
      request.method() === "PATCH" &&
      url.pathname === `${feedbackListUrl}${feedback.id}/status`
    ) {
      moderationRequestBody = request.postDataJSON()

      if (options.conflict) {
        await route.fulfill({
          status: 409,
          contentType: "application/json",
          json: {
            detail: "Feedback changed; reload before moderating",
          },
        })
        return
      }

      const body = moderationRequestBody as {
        status: "pending" | "approved" | "hidden"
        expected_updated_at: string | null
      }

      feedback = {
        ...feedback,
        status: body.status,
        updated_at: "2026-11-22T09:00:00Z",
      }

      await route.fulfill({
        status: 200,
        contentType: "application/json",
        json: feedback,
      })
      return
    }

    await route.continue()
  })

  return {
    getListRequestCount: () => listRequestCount,
    getModerationRequestBody: () => moderationRequestBody,
  }
}

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
          url.pathname === feedbackListUrl &&
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

  test("Admin can approve feedback with its expected updated timestamp", async ({
    page,
  }) => {
    const api = await mockFeedbackApi(page)

    await page.goto("/feedback")

    const feedbackRow = page
      .getByRole("row")
      .filter({ hasText: "Sample visitor" })

    await expect(feedbackRow).toBeVisible()

    const moderationResponse = page.waitForResponse(
      (response) =>
        response.url().includes(
          `${feedbackFixture.id}/status`,
        ) && response.request().method() === "PATCH",
    )

    await page.getByRole("button", { name: "Approve", exact: true }).click()

    expect((await moderationResponse).status()).toBe(200)

    expect(api.getModerationRequestBody()).toEqual({
      status: "approved",
      expected_updated_at: feedbackFixture.updated_at,
    })

    await expect(
      feedbackRow.getByText("Approved", { exact: true }),
    ).toBeVisible()

    await expect(
      page.getByText("Feedback status updated successfully.").first(),
    ).toBeVisible()
  })

  test("Admin can hide feedback", async ({ page }) => {
    const api = await mockFeedbackApi(page)

    await page.goto("/feedback")

    const feedbackRow = page
      .getByRole("row")
      .filter({ hasText: "Sample visitor" })

    await expect(feedbackRow).toBeVisible()

    const moderationResponse = page.waitForResponse(
      (response) =>
        response.url().includes(
          `${feedbackFixture.id}/status`,
        ) && response.request().method() === "PATCH",
    )

    await page.getByRole("button", { name: "Hide", exact: true }).click()

    expect((await moderationResponse).status()).toBe(200)

    expect(api.getModerationRequestBody()).toEqual({
      status: "hidden",
      expected_updated_at: feedbackFixture.updated_at,
    })

    await expect(
      feedbackRow.getByText("Hidden", { exact: true }),
    ).toBeVisible()

    await expect(
      page.getByText("Feedback status updated successfully.").first(),
    ).toBeVisible()
  })
  
  test("Shows conflict warning and reloads feedback after HTTP 409", async ({
    page,
  }) => {
    const api = await mockFeedbackApi(page, { conflict: true })

    await page.goto("/feedback")

    const feedbackRow = page
      .getByRole("row")
      .filter({ hasText: "Sample visitor" })

    await expect(feedbackRow).toBeVisible()

    const moderationResponse = page.waitForResponse(
      (response) =>
        response.url().includes(
          `${feedbackFixture.id}/status`,
        ) && response.request().method() === "PATCH",
    )

    await page.getByRole("button", { name: "Approve", exact: true }).click()

    expect((await moderationResponse).status()).toBe(409)

    expect(api.getModerationRequestBody()).toEqual({
      status: "approved",
      expected_updated_at: feedbackFixture.updated_at,
    })

    await expect(
      page.getByText(
        "Feedback has changed. The latest data has been reloaded. Please review it again.",
      ),
    ).toBeVisible()

    expect(api.getListRequestCount()).toBeGreaterThanOrEqual(2)

    await expect(feedbackRow).toBeVisible()
  })
})
