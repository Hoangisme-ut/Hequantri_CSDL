import { expect, test } from "@playwright/test"
import { createUser } from "./utils/privateApi"
import { randomEmail, randomPassword } from "./utils/random"
import { logInUser } from "./utils/user"

// 1. Unauthenticated - Người dùng chưa đăng nhập

test.describe("Permissions - Unauthenticated user", () => {
  test.use({
    storageState: {
      cookies: [],
      origins: [],
    },
  })

  test("Unauthenticated user cannot access the protected dashboard", async ({
    page,
  }) => {
    await page.goto("/")

    await expect(page).toHaveURL(/\/login$/)
  })
})

// 2. Visitor - Người dùng đã đăng nhập nhưng không có quyền Admin

test.describe("Permissions - Visitor role", () => {
  test.use({
    storageState: {
      cookies: [],
      origins: [],
    },
  })

  let email: string
  let password: string

  test.beforeAll(async () => {
    email = randomEmail()
    password = randomPassword()

    // Tạo tài khoản không có quyền Superuser.
    // Theo cơ chế RBAC hiện tại, tài khoản này có role visitor.
    await createUser({
      email,
      password,
    })
  })

  test("Visitor cannot access the protected dashboard", async ({ page }) => {
    await logInUser(page, email, password)

    await page.goto("/")

    await expect(page).toHaveURL(/\/forbidden$/)

    await expect(
      page.getByRole("heading", { name: "403" }),
    ).toBeVisible()

    await expect(
      page.getByRole("heading", { name: "Access Denied" }),
    ).toBeVisible()

    await expect(
      page.getByText(
        "You do not have permission to access the Smart Heritage Administration Console.",
      ),
    ).toBeVisible()
  })

  test("Visitor is redirected to forbidden page when accessing Team & Roles", async ({
    page,
  }) => {
    await logInUser(page, email, password)

    await page.goto("/admin")

    await expect(page).toHaveURL(/\/forbidden$/)

    await expect(
      page.getByRole("heading", { name: "Access Denied" }),
    ).toBeVisible()
  })
})
