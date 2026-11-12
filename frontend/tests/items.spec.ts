import { expect, test } from "@playwright/test"

function randomArtifactCode() {
  return `TEST-${Date.now()}-${Math.floor(Math.random() * 10000)}`
}

test.describe("Admin - Artifact Management", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("/items")
  })

  test("Artifact page is accessible and displays correct content", async ({
    page,
  }) => {
    await expect(
      page.getByRole("heading", {
        name: "Artifact Management",
        level: 2,
      }),
    ).toBeVisible()

    await expect(
      page.getByText("Manage artifact records and their language content."),
    ).toBeVisible()

    await expect(
      page.getByRole("button", { name: "Add artifact" }),
    ).toBeVisible()
  })

  test("Create a new artifact successfully", async ({ page }) => {
    const code = randomArtifactCode()

    await page.getByRole("button", { name: "Add artifact" }).click()

    await expect(page.getByRole("dialog")).toBeVisible()

    await page.getByLabel("Artifact code", { exact: true }).fill(code)

    // The form automatically selects the first active site.
    await expect(page.locator("#artifact-site")).not.toHaveValue("")

    await page.getByRole("button", { name: "Save artifact" }).click()

    await expect(page.getByText("Artifact created")).toBeVisible()

    const artifactRow = page.getByRole("row").filter({ hasText: code })
    await expect(artifactRow).toBeVisible()
    await expect(page.getByRole("dialog")).not.toBeVisible()
  })

  test("Artifact code is required", async ({ page }) => {
    await page.getByRole("button", { name: "Add artifact" }).click()

    await page.getByRole("button", { name: "Save artifact" }).click()

    await expect(page.getByRole("alert")).toHaveText(
      "Artifact code is required.",
    )
  })

  test("Cancel artifact creation", async ({ page }) => {
    await page.getByRole("button", { name: "Add artifact" }).click()

    await page
      .getByLabel("Artifact code", { exact: true })
      .fill(randomArtifactCode())

    await page.getByRole("button", { name: "Cancel" }).click()

    await expect(page.getByRole("dialog")).not.toBeVisible()
  })

  test("Edit an artifact successfully", async ({ page }) => {
    const code = randomArtifactCode()
    const updatedEra = `Updated Era ${Date.now()}`

    // Create test artifact.
    await page.getByRole("button", { name: "Add artifact" }).click()
    await page.getByLabel("Artifact code", { exact: true }).fill(code)
    await page.getByRole("button", { name: "Save artifact" }).click()

    await expect(page.getByText("Artifact created")).toBeVisible()

    // Open edit dialog.
    await page.getByRole("button", { name: `Edit ${code}` }).click()

    await expect(page.getByRole("dialog")).toBeVisible()

    await expect(page.getByLabel("Era")).toBeEnabled()
    await page.getByLabel("Era").fill(updatedEra)

    await page.getByRole("button", { name: "Save artifact" }).click()

    await expect(page.getByText("Artifact updated")).toBeVisible()

    const artifactRow = page.getByRole("row").filter({ hasText: code })
    await expect(artifactRow).toContainText(updatedEra)
  })

  test("View artifact details in read-only mode", async ({ page }) => {
    const code = randomArtifactCode()

    await page.getByRole("button", { name: "Add artifact" }).click()
    await page.getByLabel("Artifact code", { exact: true }).fill(code)
    await page.getByRole("button", { name: "Save artifact" }).click()

    await expect(page.getByText("Artifact created")).toBeVisible()

    await page.getByRole("button", { name: `View ${code}` }).click()

    await expect(
      page.getByRole("heading", { name: `Artifact details · ${code}` }),
    ).toBeVisible()

    await expect(
      page.getByLabel("Artifact code", { exact: true }),
    ).toBeDisabled()

    await expect(
      page.getByRole("button", { name: "Save artifact" }),
    ).not.toBeVisible()
  })

  test("Deactivate an artifact successfully", async ({ page }) => {
    const code = randomArtifactCode()

    await page.getByRole("button", { name: "Add artifact" }).click()
    await page.getByLabel("Artifact code", { exact: true }).fill(code)
    await page.getByRole("button", { name: "Save artifact" }).click()

    await expect(page.getByText("Artifact created")).toBeVisible()

    page.on("dialog", async (dialog) => {
      await dialog.accept()
    })

    await page.getByRole("button", { name: `Deactivate ${code}` }).click()

    await expect(page.getByText("Artifact deactivated")).toBeVisible()

    const artifactRow = page.getByRole("row").filter({ hasText: code })
    await expect(artifactRow.getByText("Inactive")).toBeVisible()
  })
})
