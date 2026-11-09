import { expect, test } from "@playwright/test"

test.describe("Admin - Site Translations", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("/sites")
  })

  test("View and save English Site translation", async ({ page }) => {
    const siteName = `PW-Translation-${Date.now()}`
    const englishName = `English ${siteName}`
    const englishDescription = "English translation created by Playwright"
    const englishAddress = "English Test Address"

    let createdSiteId: string | undefined

    try {
      // 1. Create a Site for translation testing
      await page.getByRole("button", { name: "Add site" }).click()

      const createDialog = page.getByRole("dialog")
      await expect(createDialog).toBeVisible()

      await createDialog.locator("#site-name").fill(siteName)
      await createDialog
        .locator("#site-address")
        .fill("Vietnamese Test Address")
      await createDialog
        .locator("#site-description")
        .fill("Vietnamese source description")
      await createDialog.locator("#site-latitude").fill("10.762622")
      await createDialog.locator("#site-longitude").fill("106.660172")

      const createResponsePromise = page.waitForResponse((response) => {
        const url = new URL(response.url())

        return (
          response.request().method() === "POST" &&
          url.pathname.replace(/\/$/, "").endsWith("/api/v1/sites")
        )
      })

      await createDialog.getByRole("button", { name: "Add site" }).click()

      const createResponse = await createResponsePromise
      expect(createResponse.status()).toBe(200)

      const createdSite = await createResponse.json()
      createdSiteId = createdSite.id

      expect(createdSiteId).toBeTruthy()

      // 2. Find the created Site
      const siteRow = page.getByRole("row").filter({
        hasText: siteName,
      })

      await expect(siteRow).toBeVisible()

      // 3. Register API response listener before opening dialog
      const translationResponsePromise = page.waitForResponse((response) => {
        const url = new URL(response.url())

        return (
          response.request().method() === "GET" &&
          url.pathname.endsWith(
            `/api/v1/sites/${createdSiteId}/translations`,
          )
        )
      })

      // 4. Open Site translation dialog
      await siteRow
        .getByRole("button", { name: `Translate ${siteName}` })
        .click()

      const translationDialog = page.getByRole("dialog")
      await expect(translationDialog).toBeVisible()

      await expect(
        translationDialog.getByText(`Site translation · ${siteName}`),
      ).toBeVisible()

      // 5. Inspect GET translations response
      const translationResponse = await translationResponsePromise

      const translationResponseBody = await translationResponse.text()

      console.log("Translation API URL:", translationResponse.url())
      console.log("Translation API status:", translationResponse.status())
      console.log("Translation API body:", translationResponseBody)

      // Stop with a clear diagnostic if the backend request fails.
      expect(
        translationResponse.status(),
        `GET Site translations failed: ${translationResponseBody}`,
      ).toBe(200)

      // 6. Wait for the dialog to finish loading
      await expect(
        translationDialog.getByRole("tab", { name: "English" }),
      ).toBeVisible({ timeout: 15000 })

      await expect(
        translationDialog.getByRole("tab", { name: "Tiếng Việt" }),
      ).toHaveAttribute("aria-selected", "true")

      // 7. Verify Vietnamese source is read-only
      await expect(
        translationDialog.locator("#site-translation-name"),
      ).toHaveValue(siteName)

      await expect(
        translationDialog.locator("#site-translation-name"),
      ).toHaveAttribute("readonly", "")

      // 8. Switch to English
      await translationDialog.getByRole("tab", {
        name: "English",
      }).click()

      const nameInput = translationDialog.locator(
        "#site-translation-name",
      )
      const descriptionInput = translationDialog.locator(
        "#site-translation-description",
      )
      const addressInput = translationDialog.locator(
        "#site-translation-address",
      )

      await expect(nameInput).toBeEditable()

      await nameInput.fill(englishName)
      await descriptionInput.fill(englishDescription)
      await addressInput.fill(englishAddress)

      // 9. Save translation and verify API response
      const saveResponsePromise = page.waitForResponse((response) => {
        const url = new URL(response.url())

        return (
          response.request().method() === "PUT" &&
          url.pathname.endsWith(
            `/api/v1/sites/${createdSiteId}/translations/${url.pathname.split("/").pop()}`,
          )
        )
      })

      await translationDialog.getByRole("button", {
        name: "Save translation",
      }).click()

      const saveResponse = await saveResponsePromise

      expect(saveResponse.status()).toBe(200)

      const savedTranslation = await saveResponse.json()

      expect(savedTranslation.site_id).toBe(createdSiteId)
      expect(savedTranslation.language_code).toBe("en")
      expect(savedTranslation.name).toBe(englishName)
      expect(savedTranslation.description).toBe(englishDescription)
      expect(savedTranslation.address).toBe(englishAddress)
      expect(savedTranslation.is_confirmed).toBe(true)
      expect(savedTranslation.is_stale).toBe(false)

      // 10. Verify success notification
      await expect(
        page.getByText("English translation saved and confirmed."),
      ).toBeVisible()

      // 11. Close and reopen dialog to verify persisted translation
      await translationDialog.getByRole("button", {
        name: "Close",
        exact: true,
        }).first().click()

      await siteRow
        .getByRole("button", { name: `Translate ${siteName}` })
        .click()

      const reopenedDialog = page.getByRole("dialog")

      await reopenedDialog.getByRole("tab", {
        name: "English",
      }).click()

      await expect(
        reopenedDialog.locator("#site-translation-name"),
      ).toHaveValue(englishName)

      await expect(
        reopenedDialog.locator("#site-translation-description"),
      ).toHaveValue(englishDescription)

      await expect(
        reopenedDialog.locator("#site-translation-address"),
      ).toHaveValue(englishAddress)
    } finally {
      // 12. Cleanup: deactivate the test Site
      if (createdSiteId) {
        await page.goto("/sites")

        const cleanupRow = page.getByRole("row").filter({
          hasText: siteName,
        })

        await expect(cleanupRow).toBeVisible()

        page.once("dialog", async (dialog) => {
          await dialog.accept()
        })

        const deleteResponsePromise = page.waitForResponse((response) => {
          const url = new URL(response.url())

          return (
            response.request().method() === "DELETE" &&
            url.pathname.endsWith(`/api/v1/sites/${createdSiteId}`)
          )
        })

        await cleanupRow
          .getByRole("button", { name: `Deactivate ${siteName}` })
          .click()

        const deleteResponse = await deleteResponsePromise
        expect(deleteResponse.status()).toBe(200)
      }
    }
  })
})
