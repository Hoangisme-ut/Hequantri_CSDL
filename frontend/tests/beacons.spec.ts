import { expect, test, type Page } from "@playwright/test"
import { randomUUID } from "node:crypto"

interface BeaconSeed {
  uuid: string
  major: number
  minor: number
}

function randomBeacon(): BeaconSeed {
  return {
    uuid: randomUUID(),
    major: Math.floor(Math.random() * 60000) + 1,
    minor: Math.floor(Math.random() * 60000) + 1,
  }
}

/**
 * Cleanup chỉ Beacon do test tạo ra.
 * Không xóa Site hoặc Artifact có sẵn.
 */
async function cleanupBeacon(page: Page, uuid: string) {
  if (page.isClosed()) return

  try {
    await page.goto("/beacons")

    const searchInput = page.getByPlaceholder(
      "Search UUID, Major, Minor, Site or Artifact...",
    )

    await searchInput.fill(uuid)

    const beaconRow = page.getByRole("row").filter({
      hasText: uuid,
    })

    if (!(await beaconRow.isVisible().catch(() => false))) return

    const deactivateButton = beaconRow.getByRole("button", {
      name: "Deactivate beacon",
    })

    // Nếu Beacon đã inactive thì không cần cleanup thêm.
    if (!(await deactivateButton.isVisible().catch(() => false))) return

    page.once("dialog", (dialog) => {
      void dialog.accept()
    })

    const responsePromise = page.waitForResponse(
      (response) =>
        response.request().method() === "DELETE" &&
        /^\/api\/v1\/beacons\/[^/]+\/?$/.test(
          new URL(response.url()).pathname,
        ),
    )

    await deactivateButton.click()

    const response = await responsePromise

    expect(response.ok()).toBeTruthy()
  } catch (error) {
    console.warn(
      `Could not cleanup test beacon ${uuid}:`,
      error,
    )
  }
}

/**
 * Tạo Beacon qua giao diện và xác nhận phản hồi API.
 */
async function createBeacon(page: Page, beacon: BeaconSeed) {
  await page.getByRole("button", {
    name: /add beacon/i,
  }).first().click()

  const dialog = page.getByRole("dialog")

  await expect(dialog).toBeVisible()

  await dialog.getByLabel("Proximity UUID").fill(beacon.uuid)
  await dialog.getByLabel("Major").fill(String(beacon.major))
  await dialog.getByLabel("Minor").fill(String(beacon.minor))

  const siteSelect = dialog.locator("select").nth(0)
  await expect(siteSelect).toBeVisible()
  await expect(siteSelect).toBeEnabled()
  // Chọn Site có sẵn, không tạo Site mới.
  await expect
    .poll(async () => siteSelect.locator("option").count())
    .toBeGreaterThan(1)

  await siteSelect.selectOption({ index: 1 })

  const siteId = await siteSelect.inputValue()

  const artifactSelect = dialog.getByLabel("Assigned Artifact")

  await expect(artifactSelect).toBeEnabled()

  const responsePromise = page.waitForResponse(
    (response) =>
      response.request().method() === "POST" &&
      new URL(response.url()).pathname === "/api/v1/beacons/",
  )

  await dialog.getByRole("button", {
    name: "Add Beacon",
    exact: true,
  }).click()

  const response = await responsePromise

  expect(response.ok()).toBeTruthy()

  const body = await response.json()

  expect(body.proximity_uuid.toLowerCase()).toBe(
    beacon.uuid.toLowerCase(),
    )
  expect(body.major).toBe(beacon.major)
  expect(body.minor).toBe(beacon.minor)
  expect(body.site_id).toBe(siteId)
  expect(body.id).toBeTruthy()

  await expect(
    page.getByText("Beacon created successfully."),
  ).toBeVisible()

  const beaconRow = page.getByRole("row").filter({
    hasText: beacon.uuid,
  })

  await expect(beaconRow).toBeVisible()
  await expect(dialog).not.toBeVisible()

  return {
    ...beacon,
    id: body.id as string,
    siteId,
    row: beaconRow,
  }
}

test.beforeEach(async ({ page }) => {
  await page.goto("/beacons")

  await expect(
    page.getByRole("heading", {
      name: "Beacon Management",
      exact: true,
    }).last(),
  ).toBeVisible()
})

// Các test phải nằm bên ngoài beforeEach
test("Beacon page is accessible and displays correct content", async ({
  page,
}) => {
    await expect(
      page.getByRole("button", {
        name: /add beacon/i,
      }).first(),
    ).toBeVisible()

    await expect(
      page.getByPlaceholder(
        "Search UUID, Major, Minor, Site or Artifact...",
      ),
    ).toBeVisible()

    await expect(page.getByText("Total Beacons")).toBeVisible()

    await expect(
      page.getByText("Active", { exact: true }).first(),
    ).toBeVisible()

    await expect(
      page.getByText("Inactive", { exact: true }).first(),
    ).toBeVisible()

    await expect(
      page.getByText("Unassigned", { exact: true }).first(),
    ).toBeVisible()
  })

  test("Beacon list displays its table columns", async ({ page }) => {
    await expect(
      page.getByRole("columnheader", {
        name: /proximity uuid/i,
      }),
    ).toBeVisible()

    await expect(
      page.getByRole("columnheader", {
        name: /major/i,
      }),
    ).toBeVisible()

    await expect(
      page.getByRole("columnheader", {
        name: /minor/i,
      }),
    ).toBeVisible()

    await expect(
      page.getByRole("columnheader", {
        name: /site/i,
      }),
    ).toBeVisible()

    await expect(
      page.getByRole("columnheader", {
        name: /artifact/i,
      }),
    ).toBeVisible()
  })

  test("Create a Beacon successfully", async ({ page }) => {
    const beacon = randomBeacon()

    try {
      await createBeacon(page, beacon)
    } finally {
      await cleanupBeacon(page, beacon.uuid)
    }
  })

  test("Search Beacon by Proximity UUID", async ({ page }) => {
    const beacon = randomBeacon()

    try {
      const created = await createBeacon(page, beacon)

      const searchInput = page.getByPlaceholder(
        "Search UUID, Major, Minor, Site or Artifact...",
      )

      await searchInput.fill(created.uuid)
      await expect(created.row).toBeVisible()
      await expect(created.row).toContainText(
        new RegExp(created.uuid, "i"),
        )
    } finally {
      await cleanupBeacon(page, beacon.uuid)
    }
  })

  test("Filter Beacons by Active and Unassigned status", async ({
    page,
  }) => {
    const beacon = randomBeacon()

    try {
      const created = await createBeacon(page, beacon)

      // Kiểm tra bộ lọc Active.
      await page.getByRole("button", {
        name: "Active",
        exact: true,
      }).click()

      await expect(created.row).toBeVisible()

      await expect(
        created.row.getByText("Active", {
          exact: true,
        }),
      ).toBeVisible()

      // Kiểm tra bộ lọc Unassigned.
      await page.getByRole("button", {
        name: "Unassigned",
        exact: true,
      }).click()

      await expect(created.row).toBeVisible()
      await expect(created.row).toContainText("Unassigned")

      // Beacon mới tạo đang Active nên không xuất hiện ở Inactive.
      await page.getByRole("button", {
        name: "Inactive",
        exact: true,
      }).click()

      await expect(created.row).not.toBeVisible()
    } finally {
      await cleanupBeacon(page, beacon.uuid)
    }
  })

  test("Reject Major value outside the allowed range", async ({
    page,
  }) => {
    await page.getByRole("button", {
      name: /add beacon/i,
    }).first().click()

    const dialog = page.getByRole("dialog")

    await dialog.getByLabel("Proximity UUID").fill(randomUUID())

    const siteSelect = dialog.locator("select").nth(0)

    await expect
      .poll(async () => siteSelect.locator("option").count())
      .toBeGreaterThan(1)

    await siteSelect.selectOption({ index: 1 })

    const majorInput = dialog.getByLabel("Major")

    await majorInput.fill("65536")

    // Kiểm tra validation HTML5: 65536 vượt quá max=65535.
    const isValid = await majorInput.evaluate(
      (element: HTMLInputElement) => element.validity.valid,
    )

    expect(isValid).toBe(false)

    await dialog.getByRole("button", {
      name: "Cancel",
    }).click()

    await expect(dialog).not.toBeVisible()
  })

  test("Edit a Beacon successfully", async ({ page }) => {
    const beacon = randomBeacon()

    try {
      const created = await createBeacon(page, beacon)

      await created.row.getByRole("button", {
        name: "Edit beacon",
      }).click()

      const dialog = page.getByRole("dialog")

      await expect(dialog).toBeVisible()

      const updatedMajor = created.major + 1

      await dialog.getByLabel("Major").fill(String(updatedMajor))

      const responsePromise = page.waitForResponse(
        (response) =>
          response.request().method() === "PUT" &&
          new URL(response.url()).pathname ===
            `/api/v1/beacons/${created.id}`,
      )

      await dialog.getByRole("button", {
        name: "Save changes",
      }).click()

      const response = await responsePromise

      expect(response.ok()).toBeTruthy()

      const body = await response.json()

      expect(body.id).toBe(created.id)
      expect(body.proximity_uuid.toLowerCase()).toBe(
        created.uuid.toLowerCase(),
        )
      expect(body.major).toBe(updatedMajor)

      await expect(
        page.getByText("Beacon updated successfully."),
      ).toBeVisible()

      await expect(created.row).toContainText(
        String(updatedMajor),
      )
    } finally {
      await cleanupBeacon(page, beacon.uuid)
    }
  })

  test("Deactivate a Beacon successfully", async ({ page }) => {
    const beacon = randomBeacon()

    try {
      const created = await createBeacon(page, beacon)

      page.once("dialog", async (dialog) => {
        expect(dialog.message()).toContain(
          `${created.major}/${created.minor}`,
        )

        await dialog.accept()
      })

      const responsePromise = page.waitForResponse(
        (response) =>
          response.request().method() === "DELETE" &&
          new URL(response.url()).pathname ===
            `/api/v1/beacons/${created.id}`,
      )

      await created.row.getByRole("button", {
        name: "Deactivate beacon",
      }).click()

      const response = await responsePromise

      expect(response.ok()).toBeTruthy()

      await expect(
        page.getByText("Beacon deactivated successfully."),
      ).toBeVisible()

      await expect(
        created.row.getByText("Inactive", {
          exact: true,
        }),
      ).toBeVisible()
    } finally {
      await cleanupBeacon(page, beacon.uuid)
    }
  })