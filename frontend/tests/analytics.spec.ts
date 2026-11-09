import { expect, test } from "@playwright/test"

test.describe("Analytics & Reports", () => {
  test("Analytics page is accessible and shows its title", async ({ page }) => {
    await page.goto("/analytics")

    await expect(
      page.getByText("Total visits", { exact: true }),
    ).toBeVisible()
    await expect(
        page.getByRole("paragraph").filter({ hasText: "Artifact views" }),
        ).toBeVisible()
    await expect(
        page.getByRole("paragraph").filter({ hasText: "Interactions" }),
        ).toBeVisible()
    await expect(
        page.getByRole("paragraph").filter({ hasText: "Content views" }),
        ).toBeVisible()
  })

  test("Shows that analytics data is not available yet", async ({ page }) => {
    await page.goto("/analytics")

    await expect(
      page.getByText("Analytics are not available", { exact: true }),
    ).toBeVisible()

    await expect(
      page.getByText("Waiting for analytics API", { exact: true }).first(),
    ).toBeVisible()

    await expect(
        page.getByText("API pending", { exact: true }).first(),
        ).toBeVisible()
  })

  test("Report filters and export actions are disabled", async ({ page }) => {
    await page.goto("/analytics")

    await expect(
      page.getByRole("button", { name: "Date range unavailable" }),
    ).toBeDisabled()

    await expect(
      page.getByRole("button", { name: "Apply" }),
    ).toBeDisabled()

    await expect(
      page.getByRole("button", { name: "Reset" }),
    ).toBeDisabled()

    await expect(
      page.getByRole("button", { name: "Export PDF" }),
    ).toBeDisabled()

    await expect(
      page.getByRole("button", { name: "Export Excel" }),
    ).toBeDisabled()
  })

  test("Shows an empty state for site analytics", async ({ page }) => {
    await page.goto("/analytics")

    await expect(
      page.getByText("No site analytics available", { exact: true }),
    ).toBeVisible()

    await expect(
      page.getByText(
        "Verified site, artifact and beacon totals are not available for reporting.",
        { exact: true },
      ),
    ).toBeVisible()
  })
})
