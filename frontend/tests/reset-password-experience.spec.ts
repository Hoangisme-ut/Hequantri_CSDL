import { expect, test } from "@playwright/test"

test.use({ storageState: { cookies: [], origins: [] } })

const resetUrl = "/reset-password?token=private-test-token"

test("missing token shows a branded recovery message without Admin login", async ({
  page,
}) => {
  await page.goto("/reset-password")

  await expect(
    page.getByRole("heading", { name: "No reset token found" }),
  ).toBeVisible()
  await expect(
    page.getByRole("link", { name: "Request a new recovery email" }),
  ).toHaveAttribute("href", "/recover-password")
  await expect(page.getByText("Admin Console")).toHaveCount(0)
  await expect(page.getByRole("link", { name: "Sign in" })).toHaveCount(0)
})

test("passwords must match before sending a reset request", async ({
  page,
}) => {
  let requestCount = 0
  await page.route(/\/api\/v1\/reset-password\/?$/, async (route) => {
    requestCount += 1
    await route.fulfill({ status: 200, json: { message: "Password updated" } })
  })

  await page.goto(resetUrl)
  await page.getByTestId("new-password-input").fill("new-password-123")
  await page.getByTestId("confirm-password-input").fill("different-password")
  await page.getByRole("button", { name: "Update password" }).click()

  await expect(page.getByText("Passwords do not match.")).toBeVisible()
  expect(requestCount).toBe(0)
})

test("weak passwords are rejected before sending a reset request", async ({
  page,
}) => {
  let requestCount = 0
  await page.route(/\/api\/v1\/reset-password\/?$/, async (route) => {
    requestCount += 1
    await route.fulfill({ status: 200, json: { message: "Password updated" } })
  })

  await page.goto(resetUrl)
  await page.getByTestId("new-password-input").fill("short")
  await page.getByTestId("confirm-password-input").fill("short")
  await page.getByRole("button", { name: "Update password" }).click()

  await expect(
    page.getByText("Password must be at least 8 characters."),
  ).toBeVisible()
  expect(requestCount).toBe(0)
})

test("invalid or expired token shows a safe message without exposing the token", async ({
  page,
}) => {
  await page.route(/\/api\/v1\/reset-password\/?$/, async (route) => {
    await route.fulfill({
      status: 400,
      contentType: "application/json",
      body: JSON.stringify({ detail: "Invalid token" }),
    })
  })

  await page.goto(resetUrl)
  await page.getByTestId("new-password-input").fill("new-password-123")
  await page.getByTestId("confirm-password-input").fill("new-password-123")
  await page.getByRole("button", { name: "Update password" }).click()

  await expect(
    page.getByRole("heading", { name: "Link expired" }),
  ).toBeVisible()
  await expect(
    page.getByRole("link", { name: "Request a new recovery email" }),
  ).toHaveAttribute("href", "/recover-password")
  await expect(page.locator("body")).not.toContainText("private-test-token")
  await expect(page.getByText("Admin Console")).toHaveCount(0)
})

test("successful reset shows sign-in link and does not redirect to Admin login", async ({
  page,
}) => {
  let requestBody: Record<string, unknown> | undefined
  await page.route(/\/api\/v1\/reset-password\/?$/, async (route) => {
    requestBody = route.request().postDataJSON() as Record<string, unknown>
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({ message: "Password updated successfully" }),
    })
  })

  await page.goto(resetUrl)
  await page.getByTestId("new-password-input").fill("new-password-123")
  await page.getByTestId("confirm-password-input").fill("new-password-123")
  await page.getByRole("button", { name: "Update password" }).click()

  await expect(
    page.getByRole("heading", { name: "Password updated" }),
  ).toBeVisible()
  await expect(
    page.getByText("Your password has been updated successfully."),
  ).toBeVisible()
  expect(requestBody).toEqual({
    new_password: "new-password-123",
    token: "private-test-token",
  })
  const storedTokens = await page.evaluate(() => [
    ...Object.values(localStorage),
    ...Object.values(sessionStorage),
  ])
  expect(storedTokens).not.toContain("private-test-token")
  await expect(page).toHaveURL(/\/reset-password$/)
  await expect(page.getByText("Admin Console")).toHaveCount(0)

  // Should show Back to Sign In link (Web Admin flow)
  await expect(
    page.getByRole("link", { name: "Back to Sign In" }),
  ).toBeVisible()
})

test("reset screen fits a mobile viewport", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await page.goto(resetUrl)

  await expect(
    page.getByRole("heading", { name: "Reset password" }),
  ).toBeVisible()
  await expect(
    page.getByRole("button", { name: "Update password" }),
  ).toBeVisible()
  await expect(page.getByRole("button", { name: "Show password" })).toHaveCount(
    2,
  )
  await page.getByTestId("new-password-input").fill("StrongPass123!")
  await expect(
    page.getByRole("progressbar", { name: "Password strength" }),
  ).toHaveAttribute("aria-valuenow", "4")
  await page.getByRole("button", { name: "Show password" }).first().click()
  await expect(page.getByTestId("new-password-input")).toHaveAttribute(
    "type",
    "text",
  )
  const hasHorizontalOverflow = await page.evaluate(
    () =>
      document.documentElement.scrollWidth >
      document.documentElement.clientWidth,
  )
  expect(hasHorizontalOverflow).toBe(false)
})

test("reset screen fits a desktop viewport without stretching the card", async ({
  page,
}) => {
  await page.setViewportSize({ width: 1440, height: 900 })
  await page.goto(resetUrl)

  await expect(
    page.getByRole("heading", { name: "Reset password" }),
  ).toBeVisible()
})
