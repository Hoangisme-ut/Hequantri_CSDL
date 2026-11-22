import { expect, type Page, test } from "@playwright/test"
import type {
  DashboardSummary,
  FeedbackAdminStatusUpdate,
  FeedbackReviewPublic,
  Overview,
  UserMePublic,
  VisitsByLanguage,
} from "../src/client"

test.use({ storageState: { cookies: [], origins: [] } })

const admin: UserMePublic = {
  id: "10000000-0000-4000-8000-000000000001",
  email: "moderator@example.com",
  full_name: "Moderator",
  is_active: true,
  is_superuser: true,
  role_name: "admin",
}
const versionA = "2026-11-20T10:00:00Z"
const versionB = "2026-11-20T11:00:00Z"

async function signIn(page: Page) {
  await page.addInitScript(() => {
    localStorage.setItem("access_token", "mock-admin-token")
  })
}

async function openFeedback(page: Page, timestamp: string | null) {
  let feedback: FeedbackReviewPublic = {
    id: "20000000-0000-4000-8000-000000000001",
    user_id: "10000000-0000-4000-8000-000000000002",
    artifact_id: "30000000-0000-4000-8000-000000000001",
    visitor_name: "Visitor",
    visitor_email: "visitor@example.com",
    artifact_code: "ART-001",
    artifact_title: "Historic Artifact",
    site_name: "Museum",
    rating: 5,
    comment: "Original content A",
    status: "pending",
    created_at: "2026-11-19T10:00:00Z",
    updated_at: timestamp,
  }
  const updates: FeedbackAdminStatusUpdate[] = []
  let reads = 0

  await signIn(page)
  await page.route("**/api/v1/**", async (route) => {
    const request = route.request()
    const path = new URL(request.url()).pathname
    if (request.method() === "GET" && path === "/api/v1/users/me") {
      await route.fulfill({ json: admin })
    } else if (request.method() === "GET" && path === "/api/v1/feedbacks/") {
      reads += 1
      await route.fulfill({ json: { data: [feedback], count: 1 } })
    } else if (
      request.method() === "PATCH" &&
      path === `/api/v1/feedbacks/${feedback.id}/status`
    ) {
      const update = request.postDataJSON() as FeedbackAdminStatusUpdate
      updates.push(update)
      // Match the backend's optional version check, including explicit null.
      if (
        "expected_updated_at" in update &&
        update.expected_updated_at !== feedback.updated_at
      ) {
        await route.fulfill({
          status: 409,
          json: { detail: "Feedback changed; reload before moderating" },
        })
      } else {
        feedback = { ...feedback, status: update.status, updated_at: versionB }
        await route.fulfill({ json: feedback })
      }
    } else {
      await route.abort("blockedbyclient")
    }
  })

  return {
    updates,
    get feedback() {
      return feedback
    },
    get reads() {
      return reads
    },
    editAsOwner() {
      feedback = {
        ...feedback,
        comment: "Updated content B",
        updated_at: versionB,
      }
    },
    async open(status = "pending") {
      feedback.status = status
      await page.goto("/feedback")
      await expect(
        page.getByText("Original content A", { exact: true }),
      ).toBeVisible()
    },
  }
}

for (const timestamp of [versionA, null]) {
  test(`stale moderation from ${timestamp ?? "null"} reloads and requires review before retry`, async ({
    page,
  }) => {
    const state = await openFeedback(page, timestamp)
    await state.open()
    state.editAsOwner()
    const approve = page.getByRole("button", { name: "Approve", exact: true })
    await approve.click()

    await expect.poll(() => state.updates.length).toBe(1)
    expect(state.updates[0]).toEqual({
      status: "approved",
      expected_updated_at: timestamp,
    })
    await expect(page.getByRole("alert")).toContainText("Feedback changed")
    await expect(
      page.getByText("Updated content B", { exact: true }),
    ).toBeVisible()
    expect(state.reads).toBe(2)
    expect(state.feedback.status).toBe("pending")
    await expect(approve).toBeDisabled()
    await expect(
      page.getByRole("button", { name: "Hide", exact: true }),
    ).toBeDisabled()
    expect(state.updates).toHaveLength(1)

    await page
      .getByRole("button", { name: "I have read the updated feedback" })
      .click()
    await approve.click()
    await expect(
      page.getByText("Feedback status updated successfully."),
    ).toBeVisible()
    expect(state.updates).toEqual([
      { status: "approved", expected_updated_at: timestamp },
      { status: "approved", expected_updated_at: versionB },
    ])
    expect(state.feedback.status).toBe("approved")
  })

  for (const [label, status, initialStatus] of [
    ["Approve", "approved", "pending"],
    ["Hide", "hidden", "pending"],
    ["Set as Pending", "pending", "approved"],
  ] as const) {
    test(`${label} sends the displayed version ${timestamp ?? "null"}`, async ({
      page,
    }) => {
      const state = await openFeedback(page, timestamp)
      await state.open(initialStatus)
      await page.getByRole("button", { name: label, exact: true }).click()
      await expect(
        page.getByText("Feedback status updated successfully."),
      ).toBeVisible()
      expect(state.updates).toEqual([
        { status, expected_updated_at: timestamp },
      ])
      expect(state.feedback.status).toBe(status)
    })
  }
}

async function openAnalytics(page: Page) {
  const requests: URL[] = []
  await page.clock.setFixedTime(new Date("2026-11-22T12:00:00Z"))
  await signIn(page)
  await page.route("**/api/v1/**", async (route) => {
    const url = new URL(route.request().url())
    if (url.pathname === "/api/v1/users/me") {
      await route.fulfill({ json: admin })
    } else if (
      url.pathname.startsWith("/api/v1/analytics/") ||
      url.pathname.startsWith("/api/v1/dashboard/")
    ) {
      requests.push(url)
      const json = url.pathname.endsWith("/overview")
        ? ({
            views: 12,
            unique_users: 3,
            artifacts_viewed: 2,
          } satisfies Overview)
        : url.pathname.endsWith("/summary")
          ? ({
              sites: { total: 1, active: 1 },
              artifacts: { total: 2, active: 2 },
              beacons: { total: 1, active: 1 },
              visits: { total: 12, unique_visitors: 3 },
              ratings: { count: 0, average: null },
            } satisfies DashboardSummary)
          : url.pathname.endsWith("/visits-by-language")
            ? ({ total: 0, data: [] } satisfies VisitsByLanguage)
            : []
      await route.fulfill({ json })
    } else {
      await route.abort("blockedbyclient")
    }
  })
  await page.goto("/analytics")
  await expect.poll(() => requests.length).toBe(7)
  await expect(
    page.getByText("Daily content views", { exact: true }),
  ).toBeVisible()
  return requests
}

for (const scenario of [
  {
    name: "empty start",
    field: "From date",
    value: "",
    message: "Choose both dates.",
  },
  {
    name: "empty end",
    field: "To date",
    value: "",
    message: "Choose both dates.",
  },
  {
    name: "malformed date",
    field: "To date",
    value: "not-a-date",
    message: "Enter valid dates in YYYY-MM-DD format.",
  },
  {
    name: "impossible date",
    field: "To date",
    value: "2026-02-30",
    message: "Enter valid dates in YYYY-MM-DD format.",
  },
  {
    name: "reversed range",
    field: "From date",
    value: "2099-01-01",
    message: "The start date must not be later than the end date.",
  },
  {
    name: "367 inclusive days",
    field: "From date",
    value: "2025-11-21",
    message: "Choose a range of at most 366 days.",
  },
]) {
  test(`analytics blocks queries for ${scenario.name} and recovers`, async ({
    page,
  }) => {
    const errors: string[] = []
    page.on("pageerror", (error) => errors.push(error.message))
    const requests = await openAnalytics(page)
    const input = page.getByLabel(scenario.field, { exact: true })
    if (
      scenario.name === "malformed date" ||
      scenario.name === "impossible date"
    ) {
      // Exercise string validation beyond the native date input's sanitization.
      await input.evaluate((element: HTMLInputElement) => {
        element.type = "text"
      })
    }
    await input.fill(scenario.value)
    await expect(page.getByRole("alert")).toHaveText(scenario.message)
    await expect(
      page.getByText("Daily content views", { exact: true }),
    ).toBeVisible()
    await expect(
      page.getByRole("button", { name: "Export PDF", exact: true }),
    ).toBeDisabled()
    await expect(
      page.getByRole("button", { name: "Export Excel", exact: true }),
    ).toBeDisabled()
    expect(requests).toHaveLength(7)

    await page.getByRole("button", { name: "Reset filters" }).click()
    await expect(page.getByRole("alert")).toHaveCount(0)
    await expect(
      page.getByRole("button", { name: "Export PDF", exact: true }),
    ).toBeEnabled()
    await expect.poll(() => requests.length).toBe(14)
    await page.getByLabel("From date", { exact: true }).fill("2024-01-01")
    await expect(page.getByRole("alert")).toHaveText(
      "Choose a range of at most 366 days.",
    )
    expect(requests).toHaveLength(14)
    await page.getByLabel("To date", { exact: true }).fill("2024-12-31")
    await expect(page.getByRole("alert")).toHaveCount(0)
    await expect.poll(() => requests.length).toBe(21)
    await expect(
      page.getByRole("button", { name: "Export Excel", exact: true }),
    ).toBeEnabled()
    expect(errors).toEqual([])
    for (const request of requests.slice(14)) {
      if (request.pathname.startsWith("/api/v1/analytics/")) {
        expect(request.searchParams.get("from")).toBe("2024-01-01T00:00:00Z")
        expect(request.searchParams.get("to")).toBe("2025-01-01T00:00:00Z")
      } else {
        expect(request.searchParams.get("from_date")).toBe("2024-01-01")
        expect(request.searchParams.get("to_date")).toBe("2024-12-31")
      }
    }
  })
}
