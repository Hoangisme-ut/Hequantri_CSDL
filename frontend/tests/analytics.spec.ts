import { expect, test } from "@playwright/test"

test.describe("Analytics & Reports", () => {
  test("Analytics page is accessible and displays its main sections", async ({
    page,
  }) => {
    await page.goto("/analytics")

    await expect(page.getByLabel("From date")).toBeVisible()
    await expect(page.getByLabel("To date")).toBeVisible()
    await expect(page.getByLabel("Site")).toBeVisible()

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
})
