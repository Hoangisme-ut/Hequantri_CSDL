import { test, expect, type Page } from "@playwright/test"

const randomArtifactCode = () =>
  `PW-TRANS-${Date.now()}-${Math.floor(Math.random() * 10000)}`

let artifactCode = ""

async function createArtifact(page: Page, code: string) {
  await page.goto("/items")

  await page.getByRole("heading", {
    name: "Artifact Management",
    level: 2,
  }).waitFor()

  await page.getByRole("button", {
    name: "Add artifact",
  }).first().click()

  const dialog = page.getByRole("dialog")

  await dialog.getByLabel("Artifact code").fill(code)

  const siteSelect = dialog.getByLabel("Site")
  await expect(siteSelect.locator("option")).toHaveCount(2, {
    timeout: 10000,
  }).catch(() => undefined)

  const options = await siteSelect.locator("option").count()
  expect(options).toBeGreaterThan(1)

  await siteSelect.selectOption({ index: 1 })

  const createResponse = page.waitForResponse((response) =>
    response.request().method() === "POST" &&
    response.url().includes("/api/v1/artifacts/"),
  )

  await dialog.getByRole("button", {
    name: "Save artifact",
  }).click()

  const response = await createResponse
  expect(response.ok()).toBeTruthy()

  await expect(page.getByText(code)).toBeVisible()
}

async function openTranslationDialog(page: Page, code: string) {
  await page.getByRole("button", {
    name: `Manage translations for ${code}`,
  }).click()

  const dialog = page.getByRole("dialog")

  await expect(dialog.getByRole("heading", {
    name: `Translations · ${code}`,
  })).toBeVisible()

  await expect(dialog.getByLabel("Title")).toBeVisible()
  await expect(dialog.getByLabel("Description")).toBeVisible()
  await expect(dialog.getByLabel("History content")).toBeVisible()

  return dialog
}

async function saveTranslation(
  page: Page,
  dialog: ReturnType<Page["getByRole"]>,
  title: string,
) {
  await dialog.getByLabel("Title").fill(title)
  await dialog.getByLabel("Description").fill(
    "Playwright translation description",
  )
  await dialog.getByLabel("History content").fill(
    "Playwright translation history content",
  )

  const saveResponse = page.waitForResponse((response) =>
    response.request().method() === "PUT" &&
    response.url().includes("/translations"),
  )

  await dialog.getByRole("button", {
    name: "Save translation",
  }).click()

  const response = await saveResponse
  expect(response.ok()).toBeTruthy()

  await expect(page.getByText("Translation saved")).toBeVisible()
}

async function cleanupArtifact(page: Page, code: string) {
  try {
    await page.goto("/items")

    const search = page.getByRole("textbox", {
      name: "Search artifact code",
    })

    await search.fill(code)

    const row = page.getByRole("row").filter({
      hasText: code,
    })

    if (await row.count()) {
      page.once("dialog", (dialog) => dialog.accept())

      const deleteResponse = page.waitForResponse((response) =>
        response.request().method() === "DELETE" &&
        response.url().includes("/api/v1/artifacts/"),
      )

      await row.getByRole("button", {
        name: `Deactivate ${code}`,
      }).click()

      const response = await deleteResponse
      expect(response.ok()).toBeTruthy()
    }
  } catch (error) {
    console.warn(`Could not clean up artifact ${code}:`, error)
  }
}

test.describe("Artifact Translations", () => {
  test.beforeEach(async ({ page }) => {
    artifactCode = randomArtifactCode()
    await createArtifact(page, artifactCode)
  })

  test.afterEach(async ({ page }) => {
    await cleanupArtifact(page, artifactCode)
  })

  test("should open translation dialog", async ({ page }) => {
    const dialog = await openTranslationDialog(page, artifactCode)

    await expect(dialog.getByText(
      "No translation for this language yet.",
    )).toBeVisible()
  })

  test("should create a new translation", async ({ page }) => {
    const dialog = await openTranslationDialog(page, artifactCode)

    await saveTranslation(
      page,
      dialog,
      "Playwright Test Translation",
    )

    await expect(dialog.getByText(
      "Translation exists; saving updates it.",
    )).toBeVisible()

    await expect(dialog.getByLabel("Title")).toHaveValue(
      "Playwright Test Translation",
    )
  })

  test("should update an existing translation", async ({ page }) => {
    const dialog = await openTranslationDialog(page, artifactCode)

    await saveTranslation(
      page,
      dialog,
      "Original Translation",
    )

    await dialog.getByLabel("Title").fill(
      "Updated Playwright Translation",
    )

    const updateResponse = page.waitForResponse((response) =>
      response.request().method() === "PUT" &&
      response.url().includes("/translations"),
    )

    await dialog.getByRole("button", {
      name: "Save translation",
    }).click()

    const response = await updateResponse
    expect(response.ok()).toBeTruthy()

    await expect(page.getByText("Translation saved")).toBeVisible()

    await expect(dialog.getByLabel("Title")).toHaveValue(
      "Updated Playwright Translation",
    )
  })

  test("should delete an existing translation", async ({ page }) => {
    const dialog = await openTranslationDialog(page, artifactCode)

    await saveTranslation(
      page,
      dialog,
      "Translation To Delete",
    )

    await expect(dialog.getByRole("button", {
      name: "Delete translation",
    })).toBeVisible()

    page.once("dialog", (confirmation) => {
      expect(confirmation.message()).toContain(
        "Delete the",
      )
      confirmation.accept()
    })

    const deleteResponse = page.waitForResponse((response) =>
      response.request().method() === "DELETE" &&
      response.url().includes("/translations"),
    )

    await dialog.getByRole("button", {
      name: "Delete translation",
    }).click()

    const response = await deleteResponse
    expect(response.ok()).toBeTruthy()

    await expect(page.getByText("Translation deleted")).toBeVisible()

    await expect(dialog.getByText(
      "No translation for this language yet.",
    )).toBeVisible()

    await expect(dialog.getByRole("button", {
      name: "Delete translation",
    })).toHaveCount(0)
  })

  test("should disable saving when title is empty", async ({ page }) => {
    const dialog = await openTranslationDialog(page, artifactCode)

    const titleInput = dialog.getByLabel("Title")
    const saveButton = dialog.getByRole("button", {
      name: "Save translation",
    })

    await expect(titleInput).toHaveValue("")
    await expect(saveButton).toBeDisabled()

    await titleInput.fill("Valid translation title")
    await expect(saveButton).toBeEnabled()

    await titleInput.clear()
    await expect(saveButton).toBeDisabled()
  })
})
