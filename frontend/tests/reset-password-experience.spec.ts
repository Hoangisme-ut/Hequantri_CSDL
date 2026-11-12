import { expect, test } from "@playwright/test"

test.use({ storageState: { cookies: [], origins: [] } })

const resetUrl = "/reset-password?token=private-test-token"

test("missing token shows a branded recovery message without Admin login", async ({
  page,
}) => {
  await page.goto("/reset-password")

  await expect(
    page.getByRole("heading", { name: "Liên kết không hợp lệ" }),
  ).toBeVisible()
  await expect(
    page.getByRole("link", { name: "Yêu cầu email mới" }),
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
  await page.getByRole("button", { name: "Cập nhật mật khẩu" }).click()

  await expect(page.getByText("Mật khẩu xác nhận không khớp.")).toBeVisible()
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
  await page.getByRole("button", { name: "Cập nhật mật khẩu" }).click()

  await expect(page.getByText("Mật khẩu cần có ít nhất 8 ký tự.")).toBeVisible()
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
  await page.getByRole("button", { name: "Cập nhật mật khẩu" }).click()

  await expect(
    page.getByText(
      "Liên kết không hợp lệ, đã hết hạn hoặc đã được sử dụng. Hãy yêu cầu email khôi phục mới.",
    ),
  ).toBeVisible()
  await expect(page.locator("body")).not.toContainText("private-test-token")
  await expect(page.getByText("Admin Console")).toHaveCount(0)
})

test("successful reset shows app guidance and does not redirect to Admin login", async ({
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
  await page.getByRole("button", { name: "Cập nhật mật khẩu" }).click()

  await expect(
    page.getByRole("heading", { name: "Mật khẩu đã được cập nhật!" }),
  ).toBeVisible()
  await expect(
    page.getByText("Mật khẩu của bạn đã được cập nhật thành công!"),
  ).toBeVisible()
  await expect(
    page.getByText(
      "Hãy quay lại ứng dụng Smart Heritage và đăng nhập bằng mật khẩu mới.",
    ),
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
  await expect(page.getByRole("link", { name: "Sign in" })).toHaveCount(0)

  await page
    .getByRole("button", { name: "Tôi đã hiểu – Quay lại ứng dụng" })
    .click()
  await expect(page.getByRole("status")).toContainText(
    "hãy mở ứng dụng Smart Heritage từ màn hình chính",
  )
})

test("reset screen fits a mobile viewport", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await page.goto(resetUrl)

  await expect(
    page.getByRole("heading", { name: "Đặt lại mật khẩu" }),
  ).toBeVisible()
  await expect(
    page.getByRole("button", { name: "Cập nhật mật khẩu" }),
  ).toBeVisible()
  const hasHorizontalOverflow = await page.evaluate(
    () =>
      document.documentElement.scrollWidth >
      document.documentElement.clientWidth,
  )
  expect(hasHorizontalOverflow).toBe(false)
})
