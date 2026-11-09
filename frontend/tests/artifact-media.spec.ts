import { test, expect, type Page, type Locator } from "@playwright/test"

const randomArtifactCode = () =>
  `PW-MEDIA-${Date.now()}-${Math.floor(Math.random() * 10000)}`

let artifactCode = ""

async function createArtifact(page: Page, code: string) {
  await page.goto("/items")

  await expect(
    page.getByRole("heading", {
      name: "Artifact Management",
      level: 2,
    }),
  ).toBeVisible()

  await page.getByRole("button", {
    name: "Add artifact",
  }).first().click()

  const dialog = page.getByRole("dialog")

  await dialog.getByLabel("Artifact code").fill(code)

  const siteSelect = dialog.getByLabel("Site")
  await expect(siteSelect.locator("option").nth(1)).toBeAttached()

  await siteSelect.selectOption({ index: 1 })

  const responsePromise = page.waitForResponse((response) =>
    response.request().method() === "POST" &&
    response.url().includes("/api/v1/artifacts/"),
  )

  await dialog.getByRole("button", {
    name: "Save artifact",
  }).click()

  const response = await responsePromise
  expect(response.ok()).toBeTruthy()

  await expect(page.getByText(code)).toBeVisible()
}

async function openMediaManager(page: Page, code: string) {
  await page.getByRole("button", {
    name: `Edit ${code}`,
  }).click()

  const dialog = page.getByRole("dialog")

  await expect(
    dialog.getByRole("heading", {
      name: `Edit ${code}`,
    }),
  ).toBeVisible()

  await expect(
    dialog.getByRole("heading", {
      name: "Media Management",
    }),
  ).toBeVisible()

  return dialog
}

async function openAddMediaForm(dialog: Locator) {
  await dialog.getByRole("button", {
    name: "Add Media",
  }).click()

  await expect(
    dialog.getByRole("heading", {
      name: "Add New Media",
    }),
  ).toBeVisible()

  await expect(dialog.getByLabel("Media Type")).toBeVisible()
  await expect(dialog.getByLabel("Media URL")).toBeVisible()
  await expect(dialog.getByLabel("Caption")).toBeVisible()
  await expect(dialog.getByLabel("Language")).toBeVisible()
  await expect(dialog.getByLabel("Sort Order")).toBeVisible()
}

async function fillMediaForm(
  dialog: Locator,
  options?: {
    type?: "image" | "video" | "audio"
    url?: string
    caption?: string
    sortOrder?: string
  },
) {
  await dialog.getByLabel("Media Type").selectOption(
    options?.type ?? "image",
  )

  await dialog.getByLabel("Media URL").fill(
    options?.url ?? "https://example.com/playwright-image.jpg",
  )

  await dialog.getByLabel("Caption").fill(
    options?.caption ?? "Playwright test media",
  )

  await dialog.getByLabel("Language").selectOption("")

  if (options?.sortOrder !== undefined) {
    await dialog.getByLabel("Sort Order").fill(options.sortOrder)
  }
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
      page.once("dialog", (confirmation) => confirmation.accept())

      const responsePromise = page.waitForResponse((response) =>
        response.request().method() === "DELETE" &&
        response.url().includes("/api/v1/artifacts/"),
      )

      await row.getByRole("button", {
        name: `Deactivate ${code}`,
      }).click()

      const response = await responsePromise
      expect(response.ok()).toBeTruthy()
    }
  } catch (error) {
    console.warn(`Could not clean up artifact ${code}:`, error)
  }
}

test.describe("Artifact Media", () => {
  test.beforeEach(async ({ page }) => {
    artifactCode = randomArtifactCode()
    await createArtifact(page, artifactCode)
  })

  test.afterEach(async ({ page }) => {
    await cleanupArtifact(page, artifactCode)
  })

  test("should display Media Management and empty state", async ({ page }) => {
    const dialog = await openMediaManager(page, artifactCode)

    await expect(
      dialog.getByRole("heading", {
        name: "Media Files",
      }),
    ).toBeVisible()

    await expect(
      dialog.getByText("No media yet"),
    ).toBeVisible()

    await expect(
      dialog.getByRole("button", {
        name: "Add Media",
      }),
    ).toBeVisible()
  })

  test("should create a new media successfully", async ({ page }) => {
    const dialog = await openMediaManager(page, artifactCode)

    await openAddMediaForm(dialog)

    await fillMediaForm(dialog, {
      type: "image",
      url: "https://example.com/playwright-image.jpg",
      caption: "Playwright Image Test",
      sortOrder: "1",
    })

    const responsePromise = page.waitForResponse((response) =>
      response.request().method() === "POST" &&
      response.url().includes("/media"),
    )

    await dialog.getByRole("button", {
      name: "Add Media",
    }).last().click()

    const response = await responsePromise
    expect(response.ok()).toBeTruthy()

    await expect(
      dialog.getByRole("alert"),
    ).toHaveText("Media added successfully.")

    await expect(
      dialog.getByText("Playwright Image Test"),
    ).toBeVisible()

    await expect(
      dialog.getByText("Image", { exact: true }),
    ).toBeVisible()

    await expect(
      dialog.getByText("Order: 1"),
    ).toBeVisible()
  })

  test("should reject a URL that does not use HTTP or HTTPS", async ({ page }) => {
    const dialog = await openMediaManager(page, artifactCode)

    await openAddMediaForm(dialog)

    await fillMediaForm(dialog, {
      url: "ftp://example.com/media.jpg",
    })

    await dialog.getByRole("button", {
      name: "Add Media",
    }).last().click()

    await expect(dialog.getByRole("alert")).toHaveText(
      "The URL must use HTTP or HTTPS.",
    )
  })

  test("should update an existing media", async ({ page }) => {
    const dialog = await openMediaManager(page, artifactCode)

    await openAddMediaForm(dialog)

    await fillMediaForm(dialog, {
      caption: "Original Media Caption",
    })

    const createResponsePromise = page.waitForResponse((response) =>
      response.request().method() === "POST" &&
      response.url().includes("/media"),
    )

    await dialog.getByRole("button", {
      name: "Add Media",
    }).last().click()

    const createResponse = await createResponsePromise
    expect(createResponse.ok()).toBeTruthy()

    await expect(
      dialog.getByText("Original Media Caption"),
    ).toBeVisible()

    await dialog.getByRole("button", {
      name: "Edit media",
    }).click()

    await expect(
      dialog.getByRole("heading", {
        name: "Edit Media",
      }),
    ).toBeVisible()

    await expect(
      dialog.getByLabel("Caption"),
    ).toHaveValue("Original Media Caption")

    await dialog.getByLabel("Caption").fill(
      "Updated Media Caption",
    )

    const updateResponsePromise = page.waitForResponse((response) =>
      response.request().method() === "PUT" &&
      response.url().includes("/media"),
    )

    await dialog.getByRole("button", {
      name: "Update Media",
    }).click()

    const updateResponse = await updateResponsePromise
    expect(updateResponse.ok()).toBeTruthy()

    await expect(
      dialog.getByRole("alert"),
    ).toHaveText("Media updated successfully.")

    await expect(
      dialog.getByText("Updated Media Caption"),
    ).toBeVisible()
  })

  test("should delete an existing media", async ({ page }) => {
    const dialog = await openMediaManager(page, artifactCode)

    await openAddMediaForm(dialog)

    await fillMediaForm(dialog, {
      caption: "Media To Delete",
    })

    const createResponsePromise = page.waitForResponse((response) =>
      response.request().method() === "POST" &&
      response.url().includes("/media"),
    )

    await dialog.getByRole("button", {
      name: "Add Media",
    }).last().click()

    const createResponse = await createResponsePromise
    expect(createResponse.ok()).toBeTruthy()

    await expect(
      dialog.getByText("Media To Delete"),
    ).toBeVisible()

    page.once("dialog", (confirmation) => {
      expect(confirmation.message()).toContain("Media To Delete")
      confirmation.accept()
    })

    const deleteResponsePromise = page.waitForResponse((response) =>
      response.request().method() === "DELETE" &&
      response.url().includes("/media"),
    )

    await dialog.getByRole("button", {
      name: "Delete media",
    }).click()

    const deleteResponse = await deleteResponsePromise
    expect(deleteResponse.ok()).toBeTruthy()

    await expect(
      dialog.getByRole("alert"),
    ).toHaveText("Media deleted successfully.")

    await expect(
      dialog.getByText("No media yet"),
    ).toBeVisible()
  })

  test("should cancel adding media without creating a record", async ({ page }) => {
    const dialog = await openMediaManager(page, artifactCode)

    await openAddMediaForm(dialog)

    await fillMediaForm(dialog, {
      caption: "Cancelled Media",
    })

    await dialog.locator("form").getByRole("button", {
        name: "Cancel",
        }).click()
        
    await expect(
      dialog.getByRole("heading", {
        name: "Add New Media",
      }),
    ).toHaveCount(0)

    await expect(
      dialog.getByText("No media yet"),
    ).toBeVisible()
  })
})
