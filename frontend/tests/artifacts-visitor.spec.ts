import { expect, test } from "@playwright/test"
import { createUser } from "./utils/privateApi"
import {
  randomEmail,
  randomPassword,
} from "./utils/random"
import { logInUser } from "./utils/user"

test.describe("Visitor - Artifact Management permissions", () => {
  test.use({ storageState: { cookies: [], origins: [] } })

  let email: string
  let password: string

  test.beforeAll(async () => {
    email = randomEmail()
    password = randomPassword()

    await createUser({ email, password })
  })

  test("Visitor cannot access Artifact Management", async ({ page }) => {
    await logInUser(page, email, password)

    await page.goto("/items")

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

  test("Visitor can return to sign in", async ({ page }) => {
    await logInUser(page, email, password)

    await page.goto("/items")

    await expect(page).toHaveURL(/\/forbidden$/)

    await page.getByRole("button", { name: "Back to Sign In" }).click()

    await expect(page).toHaveURL(/\/login$/)
  })
})
