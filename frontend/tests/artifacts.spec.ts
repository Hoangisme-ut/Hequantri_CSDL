import { expect, test, type Page } from "@playwright/test"

function randomArtifactCode() {
  return `PW-ART-${Date.now()}-${Math.floor(Math.random() * 10000)}`
}

/**
 * Tìm Artifact theo code và deactivate sau khi test kết thúc.
 * Chỉ cleanup Artifact do test tạo ra.
 */
async function cleanupArtifact(page: Page, code: string) {
  if (page.isClosed()) return

  try {
    await page.goto("/items")

    const searchInput = page.getByRole("textbox", {
      name: "Search artifact code",
    })

    await searchInput.fill(code)

    const artifactRow = page.getByRole("row").filter({
      hasText: code,
    })

    if (!(await artifactRow.isVisible().catch(() => false))) return

    const deactivateButton = artifactRow.getByRole("button", {
      name: `Deactivate ${code}`,
    })

    if (!(await deactivateButton.isVisible().catch(() => false))) return

    page.once("dialog", (dialog) => {
      void dialog.accept()
    })

    const responsePromise = page.waitForResponse(
      (response) =>
        response.request().method() === "DELETE" &&
        response.url().includes("/api/v1/artifacts/"),
    )

    await deactivateButton.click()

    const response = await responsePromise
    expect(response.ok()).toBeTruthy()
  } catch (error) {
    console.warn(`Could not cleanup test artifact ${code}:`, error)
  }
}

/**
 * Tạo Artifact và xác nhận phản hồi API.
 */
async function createArtifact(page: Page, code: string) {
  await page.getByRole("button", { name: "Add artifact" }).first().click()

  const dialog = page.getByRole("dialog")

  await expect(dialog).toBeVisible()

  await dialog.getByLabel("Artifact code").fill(code)

  const siteSelect = dialog.locator("#artifact-site")

  await expect(siteSelect).toBeEnabled()
  await expect(siteSelect).not.toHaveValue("")

  const siteId = await siteSelect.inputValue()

  const responsePromise = page.waitForResponse(
    (response) =>
      response.request().method() === "POST" &&
      new URL(response.url()).pathname === "/api/v1/artifacts/",
  )

  await dialog.getByRole("button", { name: "Save artifact" }).click()

  const response = await responsePromise

  expect(response.ok()).toBeTruthy()

  const body = await response.json()

  expect(body.code).toBe(code)
  expect(body.site_id).toBe(siteId)
  expect(body.id).toBeTruthy()

  await expect(page.getByText("Artifact created")).toBeVisible()
  await expect(dialog).not.toBeVisible()
  // Tìm Artifact vừa tạo bằng mã duy nhất.
  const searchInput = page.getByRole("textbox", {
    name: "Search artifact code",
  })
  await searchInput.fill(code)
  const artifactRow = page.getByRole("row").filter({
    hasText: code,
  })
  await expect(artifactRow).toBeVisible()

  return {
    id: body.id as string,
    siteId,
    row: artifactRow,
  }
}

test.describe("Admin - Artifact Management", () => {
  test.beforeEach(async ({ page }) => {
  await page.goto("/items")
  await expect(
    page.getByRole("heading", {
      name: "Artifact Management",
      level: 2,
    }),
  ).toBeVisible()
})

  test("Artifact page is accessible and displays correct content", async ({
    page,
  }) => {
    await expect(
      page.getByText("Manage artifact records and their language content."),
    ).toBeVisible()

    await expect(
      page.getByRole("button", { name: "Add artifact" }).first(),
    ).toBeVisible()

    await expect(
      page.getByRole("textbox", { name: "Search artifact code" }),
    ).toBeVisible()

    await expect(
      page.getByRole("combobox", { name: "Filter by site" }),
    ).toBeVisible()

    await expect(
      page.getByRole("combobox", { name: "Artifact title language" }),
    ).toBeVisible()
  })

  test("Create a new artifact successfully", async ({ page }) => {
    const code = randomArtifactCode()

    try {
      await createArtifact(page, code)
    } finally {
      await cleanupArtifact(page, code)
    }
  })

  test("Artifact code is required", async ({ page }) => {
    await page.getByRole("button", { name: "Add artifact" }).first().click()

    const dialog = page.getByRole("dialog")

    await dialog.getByRole("button", { name: "Save artifact" }).click()

    await expect(
      page.getByRole("alert"),
    ).toHaveText("Artifact code is required.")

    await dialog.getByRole("button", { name: "Cancel" }).click()

    await expect(dialog).not.toBeVisible()
  })

  test("Reject latitude outside valid range", async ({ page }) => {
    await page.getByRole("button", { name: "Add artifact" }).first().click()

    const dialog = page.getByRole("dialog")
    const code = randomArtifactCode()

    await dialog.getByLabel("Artifact code").fill(code)
    await dialog.locator("#artifact-latitude").fill("91")

    await dialog.getByRole("button", { name: "Save artifact" }).click()

    await expect(
      page.getByRole("alert"),
    ).toHaveText("Latitude must be between -90 and 90.")

    await dialog.getByRole("button", { name: "Cancel" }).click()
  })

  test("Reject longitude outside valid range", async ({ page }) => {
    await page.getByRole("button", { name: "Add artifact" }).first().click()

    const dialog = page.getByRole("dialog")
    const code = randomArtifactCode()

    await dialog.getByLabel("Artifact code").fill(code)
    await dialog.locator("#artifact-longitude").fill("181")

    await dialog.getByRole("button", { name: "Save artifact" }).click()

    await expect(
      page.getByRole("alert"),
    ).toHaveText("Longitude must be between -180 and 180.")

    await dialog.getByRole("button", { name: "Cancel" }).click()
  })

  test("Cancel artifact creation", async ({ page }) => {
    await page.getByRole("button", { name: "Add artifact" }).first().click()

    const dialog = page.getByRole("dialog")

    await dialog.getByLabel("Artifact code").fill(randomArtifactCode())

    await dialog.getByRole("button", { name: "Cancel" }).click()

    await expect(dialog).not.toBeVisible()
  })

  test("Edit an artifact successfully", async ({ page }) => {
    const code = randomArtifactCode()
    const updatedEra = `Updated Era ${Date.now()}`

    try {
      const artifact = await createArtifact(page, code)

      await artifact.row.getByRole("button", {
        name: `Edit ${code}`,
      }).click()

      const dialog = page.getByRole("dialog")

      await expect(dialog).toBeVisible()

      await expect(dialog.getByLabel("Era")).toBeEnabled()

      await dialog.getByLabel("Era").fill(updatedEra)

      const responsePromise = page.waitForResponse(
        (response) =>
          response.request().method() === "PUT" &&
          new URL(response.url()).pathname ===
            `/api/v1/artifacts/${artifact.id}`,
      )

      await dialog.getByRole("button", { name: "Save artifact" }).click()

      const response = await responsePromise

      expect(response.ok()).toBeTruthy()

      const body = await response.json()

      expect(body.id).toBe(artifact.id)
      expect(body.code).toBe(code)
      expect(body.era).toBe(updatedEra)

      await expect(page.getByText("Artifact updated")).toBeVisible()

      await expect(artifact.row).toContainText(updatedEra)
    } finally {
      await cleanupArtifact(page, code)
    }
  })

  test("View artifact details in read-only mode", async ({ page }) => {
    const code = randomArtifactCode()

    try {
      const artifact = await createArtifact(page, code)

      const responsePromise = page.waitForResponse(
        (response) =>
          response.request().method() === "GET" &&
          new URL(response.url()).pathname ===
            `/api/v1/artifacts/${artifact.id}`,
      )

      await artifact.row.getByRole("button", {
        name: `View ${code}`,
      }).click()

      const response = await responsePromise

      expect(response.ok()).toBeTruthy()

      const dialog = page.getByRole("dialog")

      await expect(
        dialog.getByRole("heading", {
          name: `Artifact details · ${code}`,
        }),
      ).toBeVisible()

      await expect(dialog.getByLabel("Artifact code")).toBeDisabled()
      await expect(dialog.getByLabel("Era")).toBeDisabled()

      await expect(
        dialog.getByRole("button", { name: "Save artifact" }),
      ).not.toBeVisible()

      await dialog.getByRole("button", {
        name: "Close",
        exact: true,
      }).first().click()

      await expect(dialog).not.toBeVisible()
    } finally {
      await cleanupArtifact(page, code)
    }
  })

  test("Deactivate an artifact successfully", async ({ page }) => {
    const code = randomArtifactCode()

    try {
      const artifact = await createArtifact(page, code)

      page.once("dialog", async (dialog) => {
        expect(dialog.message()).toContain(code)
        await dialog.accept()
      })

      const responsePromise = page.waitForResponse(
        (response) =>
          response.request().method() === "DELETE" &&
          new URL(response.url()).pathname ===
            `/api/v1/artifacts/${artifact.id}`,
      )

      await artifact.row.getByRole("button", {
        name: `Deactivate ${code}`,
      }).click()

      const response = await responsePromise

      expect(response.ok()).toBeTruthy()

      await expect(page.getByText("Artifact deactivated")).toBeVisible()

      await expect(artifact.row.getByText("Inactive")).toBeVisible()
    } finally {
      await cleanupArtifact(page, code)
    }
  })
})
