import { expect, type Page, test } from "@playwright/test"
import type { UserMePublic, UserPublic, UserUpdate } from "../src/client"

test.use({ storageState: { cookies: [], origins: [] } })

const adminRoleId = "10000000-0000-4000-8000-000000000001"
const visitorRoleId = "10000000-0000-4000-8000-000000000002"

async function openUserEditor(page: Page, initial: Partial<UserPublic> = {}) {
  const user: UserPublic = {
    id: "20000000-0000-4000-8000-000000000001",
    email: "editor@example.com",
    full_name: "Content Editor",
    is_superuser: false,
    is_active: true,
    role_id: adminRoleId,
    ...initial,
  }
  const currentUser: UserMePublic = {
    id: "20000000-0000-4000-8000-000000000002",
    email: "superuser@example.com",
    full_name: "Superuser",
    is_superuser: true,
    is_active: true,
    role_id: adminRoleId,
    role_name: "admin",
  }
  const updates: UserUpdate[] = []

  await page.addInitScript(() => {
    localStorage.setItem("access_token", "mock-superuser-token")
  })

  await page.route("**/api/v1/**", async (route) => {
    const request = route.request()
    const path = new URL(request.url()).pathname

    if (request.method() === "GET" && path === "/api/v1/users/me") {
      await route.fulfill({ json: currentUser })
    } else if (request.method() === "GET" && path === "/api/v1/roles/") {
      await route.fulfill({
        json: [
          {
            id: adminRoleId,
            name: "admin",
            description: "Administrator",
          },
          {
            id: visitorRoleId,
            name: "visitor",
            description: "Visitor",
          },
        ],
      })
    } else if (request.method() === "GET" && path === "/api/v1/users/") {
      await route.fulfill({ json: { data: [user], count: 1 } })
    } else if (
      request.method() === "PATCH" &&
      path === `/api/v1/users/${user.id}`
    ) {
      const update = request.postDataJSON() as UserUpdate
      updates.push(update)

      const { password: _, ...publicFields } = update
      Object.assign(user, publicFields)

      await route.fulfill({ json: user })
    } else {
      await route.abort("blockedbyclient")
    }
  })

  await page.goto("/admin")

  const row = page.getByRole("row").filter({ hasText: user.email })
  await row.getByRole("button").click()
  await page.getByRole("menuitem", { name: "Edit User" }).click()

  const dialog = page.getByRole("dialog")
  await expect(dialog).toBeVisible()

  return {
    user,
    updates,
    dialog,
    save: dialog.getByRole("button", { name: "Save" }),
  }
}

for (const [field, placeholder, value] of [
  ["full_name", "Full name", "Updated Editor"],
  ["email", "Email", "updated-editor@example.com"],
] as const) {
  test(`editing only ${field} preserves the content admin role and flags`, async ({
    page,
  }) => {
    const { user, updates, dialog, save } = await openUserEditor(page)

    await dialog.getByPlaceholder(placeholder, { exact: true }).fill(value)
    await save.click()

    await expect(dialog).not.toBeVisible()

    expect(updates).toEqual([{ [field]: value }])
    expect(user).toMatchObject({
      role_id: adminRoleId,
      is_superuser: false,
      is_active: true,
    })
  })
}

test("editing only the password preserves the role and flags", async ({
  page,
}) => {
  const { user, updates, dialog, save } = await openUserEditor(page)
  const password = "NewEditorPassword123!"

  await dialog
    .getByPlaceholder("Password", { exact: true })
    .nth(0)
    .fill(password)

  await dialog
    .getByPlaceholder("Password", { exact: true })
    .nth(1)
    .fill(password)

  await save.click()

  await expect(dialog).not.toBeVisible()

  expect(updates).toEqual([{ password }])
  expect(user).toMatchObject({
    role_id: adminRoleId,
    is_superuser: false,
    is_active: true,
  })
})

const accountTransitions = [
  {
    from: "Visitor",
    to: "Admin",
    initialRoleId: visitorRoleId,
    initialSuperuser: false,
    target: "Admin",
    expectedRoleId: adminRoleId,
    expectedSuperuser: false,
  },
  {
    from: "Admin",
    to: "Superuser",
    initialRoleId: adminRoleId,
    initialSuperuser: false,
    target: "Superuser",
    expectedRoleId: adminRoleId,
    expectedSuperuser: true,
  },
  {
    from: "Superuser",
    to: "Admin",
    initialRoleId: adminRoleId,
    initialSuperuser: true,
    target: "Admin",
    expectedRoleId: adminRoleId,
    expectedSuperuser: false,
  },
  {
    from: "Admin",
    to: "Visitor",
    initialRoleId: adminRoleId,
    initialSuperuser: false,
    target: "Visitor",
    expectedRoleId: visitorRoleId,
    expectedSuperuser: false,
  },
] as const

for (const transition of accountTransitions) {
  test(`changing account type from ${transition.from} to ${transition.to}`, async ({
    page,
  }) => {
    const { user, updates, dialog, save } = await openUserEditor(page, {
      role_id: transition.initialRoleId,
      is_superuser: transition.initialSuperuser,
    })

    await dialog.getByRole("combobox").click()
    await page.getByRole("option", { name: transition.target }).click()

    await save.click()

    await expect(dialog).not.toBeVisible()

    expect(updates).toEqual([
      {
        role_id: transition.expectedRoleId,
        is_superuser: transition.expectedSuperuser,
      },
    ])

    expect(user).toMatchObject({
      role_id: transition.expectedRoleId,
      is_superuser: transition.expectedSuperuser,
      is_active: true,
    })
  })
}

for (const initial of [false, true]) {
  test(`changing is_active from ${initial} sends only that flag`, async ({
    page,
  }) => {
    const { user, updates, dialog, save } = await openUserEditor(page, {
      is_active: initial,
    })

    await dialog.getByLabel("Is active?").setChecked(!initial)
    await save.click()

    await expect(dialog).not.toBeVisible()

    expect(updates).toEqual([{ is_active: !initial }])
    expect(user).toMatchObject({
      is_active: !initial,
      is_superuser: false,
      role_id: adminRoleId,
    })
  })
}

test("an unchanged form cannot submit an update", async ({ page }) => {
  const { updates, save } = await openUserEditor(page)

  await expect(save).toBeDisabled()
  expect(updates).toEqual([])
})

test("reverting edits and clearing the password leaves nothing to save", async ({
  page,
}) => {
  const { updates, dialog, save } = await openUserEditor(page)

  await dialog.getByPlaceholder("Full name").fill("Temporary Name")
  await dialog.getByPlaceholder("Full name").fill("Content Editor")

  await dialog.getByRole("combobox").click()
  await page.getByRole("option", { name: "Superuser" }).click()

  await dialog.getByRole("combobox").click()
  await page.getByRole("option", { name: "Admin" }).click()

  await dialog.getByLabel("Is active?").uncheck()
  await dialog.getByLabel("Is active?").check()

  await dialog
    .getByPlaceholder("Password", { exact: true })
    .nth(0)
    .fill("TemporaryPassword123!")

  await dialog.getByPlaceholder("Password", { exact: true }).nth(0).fill("")

  await expect(save).toBeDisabled()
  expect(updates).toEqual([])
})
