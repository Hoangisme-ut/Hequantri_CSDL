import { expect, test } from "@playwright/test"

test.describe("Admin - Site Management", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("/sites")
  })

  test("Site management page is accessible", async ({ page }) => {
    await expect(
      page.getByText("Manage heritage sites", { exact: true }),
    ).toBeVisible()

    await expect(
      page.getByRole("button", { name: "Add site" }),
    ).toBeVisible()

    await expect(
      page.getByRole("textbox", { name: "Search sites" }),
    ).toBeVisible()
  })

  test("Create a site and verify persisted backend data", async ({
    page,
  }) => {
    const siteName = `PW-Site-${Date.now()}-${Math.floor(Math.random() * 10000)}`
    const address = "Test Address - Ho Chi Minh City"
    const description = "Playwright business flow test"

    let createdSiteId: string | undefined

    try {
      await page.getByRole("button", { name: "Add site" }).click()

      const dialog = page.getByRole("dialog")
      await expect(dialog).toBeVisible()

      await dialog.locator("#site-name").fill(siteName)
      await dialog.locator("#site-address").fill(address)
      await dialog.locator("#site-description").fill(description)
      await dialog.locator("#site-latitude").fill("10.762622")
      await dialog.locator("#site-longitude").fill("106.660172")

      const createResponsePromise = page.waitForResponse((response) => {
        const url = new URL(response.url())

        return (
          response.request().method() === "POST" &&
          url.pathname.replace(/\/$/, "").endsWith("/api/v1/sites")
        )
      })
      await dialog.getByRole("button", { name: "Add site" }).click()

      const createResponse = await createResponsePromise
      expect(createResponse.status()).toBe(200)

      const createdSite = await createResponse.json()

      expect(createdSite.id).toBeTruthy()
      expect(createdSite.name).toBe(siteName)
      expect(createdSite.address).toBe(address)
      expect(createdSite.description).toBe(description)
      expect(createdSite.latitude).toBe(10.762622)
      expect(createdSite.longitude).toBe(106.660172)
      expect(createdSite.is_active).toBe(true)

      createdSiteId = createdSite.id

      await expect(page.getByText("Site added")).toBeVisible()

      const getResponsePromise = page.waitForResponse((response) => {
        const url = new URL(response.url())

        return (
          response.request().method() === "GET" &&
          url.pathname.endsWith(`/api/v1/sites/${createdSiteId}`)
        )
      })

      await page.goto(`/sites/${createdSiteId}`)

      const getResponse = await getResponsePromise
      expect(getResponse.status()).toBe(200)

      const savedSite = await getResponse.json()

      expect(savedSite.id).toBe(createdSiteId)
      expect(savedSite.name).toBe(siteName)
      expect(savedSite.address).toBe(address)
      expect(savedSite.description).toBe(description)
      expect(savedSite.is_active).toBe(true)

      await expect(page.locator("#site-name")).toHaveValue(siteName)
      await expect(page.locator("#site-address")).toHaveValue(address)
    } finally {
      if (createdSiteId) {
        await page.goto("/sites")

        page.once("dialog", async (dialog) => {
          await dialog.accept()
        })

        const siteRow = page.getByRole("row").filter({
          hasText: siteName,
        })

        await expect(siteRow).toBeVisible()

        const deleteResponsePromise = page.waitForResponse((response) => {
          const url = new URL(response.url())

          return (
            response.request().method() === "DELETE" &&
            url.pathname.endsWith(`/api/v1/sites/${createdSiteId}`)
          )
        })

        await siteRow
          .getByRole("button", { name: `Deactivate ${siteName}` })
          .click()

        const deleteResponse = await deleteResponsePromise
        expect(deleteResponse.status()).toBe(200)

        await expect(page.getByText("Site deactivated")).toBeVisible()
      }
    }
  })

  test("Update a site and verify persisted backend data", async ({ page }) => {
    const originalName = `PW-Site-Update-${Date.now()}`
    const updatedName = `${originalName}-Updated`
    const originalAddress = "Original Test Address"
    const updatedAddress = "Updated Test Address - Ho Chi Minh City"
    const updatedDescription = "Updated by Playwright business flow test"

    let createdSiteId: string | undefined
    let currentSiteName = originalName

    try {
      // 1. Create a test Site
      await page.getByRole("button", { name: "Add site" }).click()

      const dialog = page.getByRole("dialog")
      await expect(dialog).toBeVisible()

      await dialog.locator("#site-name").fill(originalName)
      await dialog.locator("#site-address").fill(originalAddress)
      await dialog.locator("#site-description").fill("Original description")
      await dialog.locator("#site-latitude").fill("10.762622")
      await dialog.locator("#site-longitude").fill("106.660172")

      const createResponsePromise = page.waitForResponse((response) => {
        const url = new URL(response.url())

        return (
          response.request().method() === "POST" &&
          url.pathname.replace(/\/$/, "").endsWith("/api/v1/sites")
        )
      })

      await dialog.getByRole("button", { name: "Add site" }).click()

      const createResponse = await createResponsePromise
      expect(createResponse.status()).toBe(200)

      const createdSite = await createResponse.json()
      expect(createdSite.id).toBeTruthy()

      createdSiteId = createdSite.id

      // 2. Open Site detail page
      await page.goto(`/sites/${createdSiteId}`)

      await expect(page.locator("#site-name")).toHaveValue(originalName)

      // 3. Update Site information
      await page.locator("#site-name").fill(updatedName)
      await page.locator("#site-address").fill(updatedAddress)
      await page.locator("#site-description").fill(updatedDescription)

      const updateResponsePromise = page.waitForResponse((response) => {
        const url = new URL(response.url())

        return (
          response.request().method() === "PUT" &&
          url.pathname.endsWith(`/api/v1/sites/${createdSiteId}`)
        )
      })

      await page.getByRole("button", { name: "Save changes" }).click()

      const updateResponse = await updateResponsePromise
      expect(updateResponse.status()).toBe(200)

      const updatedSite = await updateResponse.json()

      // 4. Verify backend response
      expect(updatedSite.id).toBe(createdSiteId)
      expect(updatedSite.name).toBe(updatedName)
      expect(updatedSite.address).toBe(updatedAddress)
      expect(updatedSite.description).toBe(updatedDescription)

      currentSiteName = updatedName

      // 5. Verify updated values on UI
      await expect(page.getByText("Site updated")).toBeVisible()
      await expect(page.locator("#site-name")).toHaveValue(updatedName)
      await expect(page.locator("#site-address")).toHaveValue(updatedAddress)
      await expect(page.locator("#site-description")).toHaveValue(updatedDescription)

      // 6. Reload and verify persisted data
      await page.reload()

      await expect(page.locator("#site-name")).toHaveValue(updatedName)
      await expect(page.locator("#site-address")).toHaveValue(updatedAddress)
      await expect(page.locator("#site-description")).toHaveValue(updatedDescription)
    } finally {
      // Cleanup: deactivate the test Site
      if (createdSiteId) {
        await page.goto("/sites")

        page.once("dialog", async (dialog) => {
          await dialog.accept()
        })

        const siteRow = page.getByRole("row").filter({
          hasText: currentSiteName,
        })

        await expect(siteRow).toBeVisible()

        const deleteResponsePromise = page.waitForResponse((response) => {
          const url = new URL(response.url())

          return (
            response.request().method() === "DELETE" &&
            url.pathname.endsWith(`/api/v1/sites/${createdSiteId}`)
          )
        })

        await siteRow
          .getByRole("button", { name: `Deactivate ${currentSiteName}` })
          .click()

        const deleteResponse = await deleteResponsePromise
        expect(deleteResponse.status()).toBe(200)

        await expect(page.getByText("Site deactivated")).toBeVisible()
      }
    }
  })


  test("Deactivate a site and verify backend status", async ({ page }) => {
    const siteName = `PW-Site-Deactivate-${Date.now()}`

    let createdSiteId: string | undefined
    let deactivated = false

    try {
      // 1. Create a test Site
      await page.getByRole("button", { name: "Add site" }).click()

      const dialog = page.getByRole("dialog")
      await expect(dialog).toBeVisible()

      await dialog.locator("#site-name").fill(siteName)
      await dialog.locator("#site-address").fill("Deactivate Test Address")
      await dialog.locator("#site-description").fill("Deactivate test")
      await dialog.locator("#site-latitude").fill("10.762622")
      await dialog.locator("#site-longitude").fill("106.660172")

      const createResponsePromise = page.waitForResponse((response) => {
        const url = new URL(response.url())

        return (
          response.request().method() === "POST" &&
          url.pathname.replace(/\/$/, "").endsWith("/api/v1/sites")
        )
      })

      await dialog.getByRole("button", { name: "Add site" }).click()

      const createResponse = await createResponsePromise
      expect(createResponse.status()).toBe(200)

      const createdSite = await createResponse.json()
      createdSiteId = createdSite.id

      expect(createdSiteId).toBeTruthy()
      expect(createdSite.is_active).toBe(true)

      // 2. Return to Site list
      await page.goto("/sites")

      const siteRow = page.getByRole("row").filter({
        hasText: siteName,
      })

      await expect(siteRow).toBeVisible()

      // 3. Confirm deactivation
      page.once("dialog", async (browserDialog) => {
        await browserDialog.accept()
      })

      const deleteResponsePromise = page.waitForResponse((response) => {
        const url = new URL(response.url())

        return (
          response.request().method() === "DELETE" &&
          url.pathname.endsWith(`/api/v1/sites/${createdSiteId}`)
        )
      })

      await siteRow
        .getByRole("button", { name: `Deactivate ${siteName}` })
        .click()

      const deleteResponse = await deleteResponsePromise
      expect(deleteResponse.status()).toBe(200)

      deactivated = true

      // 4. Verify success notification
      await expect(page.getByText("Site deactivated")).toBeVisible()

      // 5. Verify backend status through Site detail API
      const detailResponsePromise = page.waitForResponse((response) => {
        const url = new URL(response.url())

        return (
          response.request().method() === "GET" &&
          url.pathname.endsWith(`/api/v1/sites/${createdSiteId}`)
        )
      })

      await page.goto(`/sites/${createdSiteId}`)

      const detailResponse = await detailResponsePromise
      expect(detailResponse.status()).toBe(200)

      const deactivatedSite = await detailResponse.json()
      expect(deactivatedSite.id).toBe(createdSiteId)
      expect(deactivatedSite.is_active).toBe(false)
    } finally {
      // 6. Cleanup if deactivation did not complete
      if (createdSiteId && !deactivated) {
        await page.goto("/sites")

        const siteRow = page.getByRole("row").filter({
          hasText: siteName,
        })

        await expect(siteRow).toBeVisible()

        page.once("dialog", async (browserDialog) => {
          await browserDialog.accept()
        })

        const deleteResponsePromise = page.waitForResponse((response) => {
          const url = new URL(response.url())

          return (
            response.request().method() === "DELETE" &&
            url.pathname.endsWith(`/api/v1/sites/${createdSiteId}`)
          )
        })

        await siteRow
          .getByRole("button", { name: `Deactivate ${siteName}` })
          .click()

        const deleteResponse = await deleteResponsePromise
        expect(deleteResponse.status()).toBe(200)
      }
    }
  })
})
