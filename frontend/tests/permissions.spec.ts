import { expect, test } from "@playwright/test"
import {
  firstSuperuser,
  firstSuperuserPassword,
} from "./config"
import { createAdminUser, createUser } from "./utils/privateApi"
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

    await expect(page.getByRole("heading", { name: "403" })).toBeVisible()

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

// 3. Admin - Người dùng có role admin nhưng không phải Superuser

test.describe("Permissions - Admin role", () => {
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

    const admin = await createAdminUser({
      email,
      password,
    })

    expect(admin.role_name).toBe("admin")
    expect(admin.is_superuser).toBe(false)
  })

  test("Admin can access dashboard", async ({ page }) => {
    await logInUser(page, email, password)

    await page.goto("/")

    await expect(page).toHaveURL(/\/$/)

    await expect(
      page.getByText("Overview", { exact: true }).first(),
    ).toBeVisible()
  })

  test("Admin can access content management pages", async ({ page }) => {
    await logInUser(page, email, password)

    const routes = [
      "/sites",
      "/items",
      "/beacons",
      "/analytics",
      "/feedback",
      "/visitors",
      "/settings",
    ]

    for (const route of routes) {
      await page.goto(route)

      await expect(page).toHaveURL(
        new RegExp(`${route.replace("/", "\\/")}$`),
      )

      await expect(
        page.getByRole("heading", { name: "Access Denied" }),
      ).toHaveCount(0)
    }
  })

  test("Admin cannot access Team & Roles", async ({ page }) => {
    await logInUser(page, email, password)

    await page.goto("/admin")

    await expect(page).toHaveURL(/\/forbidden$/)

    await expect(
      page.getByRole("heading", { name: "Access Denied" }),
    ).toBeVisible()
  })

  test("Admin sidebar does not display Team & Roles", async ({ page }) => {
    await logInUser(page, email, password)

    await page.goto("/")

    await expect(
      page.getByRole("link", { name: "Team & Roles" }),
    ).toHaveCount(0)
  })

  test("Admin cannot access users API", async ({ page }) => {
    await logInUser(page, email, password)

    const result = await page.evaluate(async () => {
      const token = localStorage.getItem("access_token")

      if (!token) {
        throw new Error("Không tìm thấy access token của Admin.")
      }

      const apiBaseUrl = "http://localhost:8000"

      const response = await fetch(
        `${apiBaseUrl}/api/v1/users/`,
        {
          method: "GET",
          headers: {
            Authorization: `Bearer ${token}`,
          },
        },
      )

      const contentType = response.headers.get("content-type")
      const body = await response.text()

      return {
        status: response.status,
        url: response.url,
        contentType,
        body: body.slice(0, 500),
      }
    })

    console.log("ADMIN USERS API RESPONSE:", result)

    expect(result.status).toBe(403)
  })
})

// 4. Superuser - Người dùng có toàn quyền quản trị

test.describe("Permissions - Superuser role", () => {
  test.use({
    storageState: {
      cookies: [],
      origins: [],
    },
  })

  test("Superuser can access Team & Roles", async ({ page }) => {
    await logInUser(
      page,
      firstSuperuser,
      firstSuperuserPassword,
    )

    await page.goto("/admin")

    await expect(page).toHaveURL(/\/admin$/)

    await expect(
      page.getByRole("heading", { name: "Access Denied" }),
    ).toHaveCount(0)
  })

  test("Superuser can see Team & Roles in sidebar", async ({ page }) => {
    await logInUser(
      page,
      firstSuperuser,
      firstSuperuserPassword,
    )

    await page.goto("/")

    await expect(
      page.getByRole("link", { name: "Team & Roles" }),
    ).toBeVisible()
  })

  test("Superuser can access users API", async ({ page }) => {
    await logInUser(
      page,
      firstSuperuser,
      firstSuperuserPassword,
    )

    const result = await page.evaluate(async () => {
      const token = localStorage.getItem("access_token")

      if (!token) {
        throw new Error("Không tìm thấy access token của Superuser.")
      }

      const apiBaseUrl = "http://localhost:8000"

      const response = await fetch(
        `${apiBaseUrl}/api/v1/users/`,
        {
          method: "GET",
          headers: {
            Authorization: `Bearer ${token}`,
          },
        },
      )

      const contentType = response.headers.get("content-type")
      const body = await response.text()

      return {
        status: response.status,
        url: response.url,
        contentType,
        body: body.slice(0, 500),
      }
    })

    console.log("SUPERUSER USERS API RESPONSE:", result)

    expect(result.status).toBe(200)
  })
})