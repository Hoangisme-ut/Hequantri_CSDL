import { expect, test } from "@playwright/test"

test.describe("Analytics & Reports", () => {
  test("Analytics page is accessible and displays its main sections", async ({
    page,
  }) => {
    await page.goto("/analytics")

    await expect(page.getByLabel("From date")).toBeVisible()
    await expect(page.getByLabel("To date")).toBeVisible()
    await expect(page.getByLabel("Site", { exact: true })).toBeVisible()

    await expect(
      page.getByRole("button", { name: "Export PDF" }),
    ).toBeVisible()

    await expect(
      page.getByRole("button", { name: "Export Excel" }),
    ).toBeVisible()

    await expect(
      page.getByText("Daily content views", { exact: true }),
    ).toBeVisible()

    await expect(
      page.getByText("Visits by language", { exact: true }),
    ).toBeVisible()

    await expect(
      page.getByText("Performance by Site", { exact: true }),
    ).toBeVisible()

    await expect(
      page.getByText("Top Artifacts", { exact: true }),
    ).toBeVisible()
  })

  test("Date filters have valid default values", async ({ page }) => {
    await page.goto("/analytics")

    const fromDate = page.getByLabel("From date")
    const toDate = page.getByLabel("To date")

    await expect(fromDate).toHaveValue(/^\d{4}-\d{2}-\d{2}$/)
    await expect(toDate).toHaveValue(/^\d{4}-\d{2}-\d{2}$/)

    await expect(fromDate).toHaveAttribute("max", await toDate.inputValue())
    await expect(toDate).toHaveAttribute("min", await fromDate.inputValue())
  })

  test("Reset filters button is available", async ({ page }) => {
    await page.goto("/analytics")

    await expect(
      page.getByRole("button", { name: "Reset filters" }),
    ).toBeEnabled()
  })

  test("Export PDF and Excel buttons are available", async ({ page }) => {
    await page.goto("/analytics")

    await expect(
      page.getByRole("button", { name: "Export PDF" }),
    ).toBeEnabled()

    await expect(
      page.getByRole("button", { name: "Export Excel" }),
    ).toBeEnabled()
  })


  test("Clearing a date does not call Analytics APIs", async ({ page }) => {
    const analyticsRequests: string[] = []

    page.on("request", (request) => {
      if (request.url().includes("/api/v1/analytics/")) {
        analyticsRequests.push(request.url())
      }
    })

    await page.goto("/analytics")
    await page.waitForLoadState("networkidle")

    analyticsRequests.length = 0

    await page.getByLabel("From date").fill("")

    await expect(page.getByRole("alert")).toHaveText("Choose both dates.")

    await expect(page.getByRole("button", { name: "Export PDF" })).toBeDisabled()
    await expect(page.getByRole("button", { name: "Export Excel" })).toBeDisabled()
    await expect(page.getByRole("button", { name: "Reset filters" })).toBeEnabled()

    await page.waitForTimeout(300)
    expect(analyticsRequests).toHaveLength(0)
  })

  test("Invalid date range disables exports but allows reset", async ({ page }) => {
    await page.goto("/analytics")

    await page.getByLabel("From date").fill("2026-11-22")
    await page.getByLabel("To date").fill("2026-11-01")

    await expect(
      page.getByText("The start date must not be later than the end date."),
    ).toBeVisible()

    await expect(page.getByRole("button", { name: "Export PDF" })).toBeDisabled()
    await expect(page.getByRole("button", { name: "Export Excel" })).toBeDisabled()
    await expect(page.getByRole("button", { name: "Reset filters" })).toBeEnabled()
  })


  test("Reset restores default dates and clears the selected Site", async ({
    page,
  }) => {
    const siteId = "11111111-1111-4111-8111-111111111111"

    await page.route("**/api/v1/analytics/sites**", async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify([
          {
            site_id: siteId,
            name: "Test Site",
            views: 1,
            unique_users: 1,
          },
        ]),
      })
    })

    await page.goto("/analytics")

    const fromDate = page.getByLabel("From date")
    const toDate = page.getByLabel("To date")
    const siteSelect = page.getByLabel("Site", { exact: true })

    const defaultFrom = await fromDate.inputValue()
    const defaultTo = await toDate.inputValue()

    await expect(siteSelect.locator("option", { hasText: "Test Site" })).toHaveCount(1)

    await fromDate.fill("2026-11-01")
    await toDate.fill("2026-11-10")
    await siteSelect.selectOption(siteId)

    await page.getByRole("button", { name: "Reset filters" }).click()

    await expect(fromDate).toHaveValue(defaultFrom)
    await expect(toDate).toHaveValue(defaultTo)
    await expect(siteSelect).toHaveValue("")
  })

  test("PDF and Excel exports receive the selected filters", async ({ page }) => {
    const siteId = "11111111-1111-4111-8111-111111111111"

    await page.route("**/api/v1/analytics/sites**", async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify([
          {
            site_id: siteId,
            name: "Test Site",
            views: 1,
            unique_users: 1,
          },
        ]),
      })
    })

    await page.route("**/api/v1/analytics/export/**", async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/octet-stream",
        body: "mock report",
      })
    })

    await page.goto("/analytics")

    await page.getByLabel("From date").fill("2026-11-01")
    await page.getByLabel("To date").fill("2026-11-22")
    await page.getByLabel("Site", { exact: true }).selectOption(siteId)

    const expected = {
      from: "2026-11-01T00:00:00Z",
      to: "2026-11-23T00:00:00Z",
      site_id: siteId,
    }

    for (const format of ["pdf", "excel"]) {
      const requestPromise = page.waitForRequest((request) =>
        request.url().includes(`/api/v1/analytics/export/${format}`),
      )

      await page.getByRole("button", {
        name: format === "pdf" ? "Export PDF" : "Export Excel",
      }).click()

      const request = await requestPromise
      const params = new URL(request.url()).searchParams

      expect(params.get("from")).toBe(expected.from)
      expect(params.get("to")).toBe(expected.to)
      expect(params.get("site_id")).toBe(expected.site_id)
    }
  })
})
