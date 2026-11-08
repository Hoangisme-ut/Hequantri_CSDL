// Opt-in acceptance against a separately provisioned LOCAL QA backend only.
// Requires @playwright/test from the repository's locked dependencies.
const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const { chromium, expect } = require("@playwright/test")

async function main() {
  const api = process.env.QA_API_URL
  const web = process.env.QA_WEB_URL
  const media = process.env.QA_MEDIA_URL
  for (const value of [api, web, media]) {
    assert(value, "Set QA_API_URL, QA_WEB_URL and QA_MEDIA_URL")
    assert(["localhost", "127.0.0.1"].includes(new URL(value).hostname), "QA origins must be loopback")
  }
  assert(process.env.QA_ADMIN_EMAIL && process.env.QA_ADMIN_PASSWORD)
  assert(process.env.QA_HANDOFF_FILE, "Set a temporary QA_HANDOFF_FILE outside Git")
  const evidence = process.env.QA_EVIDENCE_DIR
    ? path.resolve(process.env.QA_EVIDENCE_DIR)
    : path.resolve(__dirname, "../../docs/qa/evidence")
  fs.mkdirSync(evidence, { recursive: true })
  const browser = await chromium.launch({ headless: true, channel: "chrome" })
  const context = await browser.newContext({ viewport: { width: 1440, height: 1000 } })
  const page = await context.newPage()
  const steps = []
  const save = () => fs.writeFileSync(path.join(evidence, "web-admin-results.json"), JSON.stringify(steps, null, 2) + "\n")
  const record = (id, result) => { steps.push({ id, status: "PASS", ...result }); save() }
  const responseFor = (method, suffix) => page.waitForResponse(r =>
    r.url().startsWith(api + "/api/v1" + suffix) && r.request().method() === method)
  const body = async response => { assert(response.ok(), `HTTP ${response.status()} ${response.url()}`); return response.json() }
  try {
    await page.goto(web + "/login")
    await page.getByPlaceholder("Enter your email address").fill(process.env.QA_ADMIN_EMAIL)
    await page.getByPlaceholder("Enter your password").fill(process.env.QA_ADMIN_PASSWORD)
    const login = responseFor("POST", "/login/access-token")
    await page.getByRole("button", { name: "Sign In", exact: true }).click()
    assert((await login).ok())
    await page.waitForURL(web + "/")
    record("WEB-00", { action: "Real admin login through UI" })

    const suffix = Date.now().toString(36)
    const name = "QA Heritage " + suffix
    const code = "QA-" + suffix.toUpperCase()
    const image = media + "/van_mieu_welcome.jpg"
    await page.goto(web + "/sites")
    await page.getByRole("button", { name: "Add site", exact: true }).first().click()
    await page.locator("#site-name").fill(name)
    await page.locator("#site-description").fill("Dữ liệu nghiệm thu riêng — không phải production")
    const siteResponse = responseFor("POST", "/sites/")
    await page.getByRole("dialog").getByRole("button", { name: "Add site", exact: true }).click()
    const site = await body(await siteResponse)
    await expect(page.getByRole("dialog")).toHaveCount(0)
    record("WEB-01", { site_id: site.id, name: site.name })

    await page.goto(web + "/items")
    await page.getByRole("button", { name: "Add artifact", exact: true }).first().click()
    await page.locator("#artifact-code").fill(code)
    await page.locator("#artifact-site").selectOption(site.id)
    await page.locator("#artifact-cover").fill(image)
    const artifactResponse = responseFor("POST", "/artifacts/")
    await page.getByRole("button", { name: "Save artifact", exact: true }).click()
    const artifact = await body(await artifactResponse)
    await expect(page.getByRole("dialog")).toHaveCount(0)
    record("WEB-02", { artifact_id: artifact.id, site_id: artifact.site_id, code: artifact.code })

    await page.getByRole("button", { name: "Manage translations for " + code, exact: true }).click()
    for (const [language, title] of [["Tiếng Việt", "Trống đồng nghiệm thu"], ["English", "Acceptance bronze drum"]]) {
      await page.getByRole("dialog").getByRole("button", { name: language, exact: true }).click()
      await page.locator("#translation-title").fill(title)
      await page.locator("#translation-description").fill(title + " description")
      await page.locator("#translation-history").fill(title + " history")
      const translationResponse = responseFor("PUT", "/artifacts/" + artifact.id + "/translations/")
      await page.getByRole("button", { name: "Save translation", exact: true }).click()
      const translation = await body(await translationResponse)
      await expect(page.getByRole("button", { name: "Save translation", exact: true })).toBeEnabled()
      record(language === "English" ? "WEB-04" : "WEB-03", { language, title: translation.title, language_id: translation.language_id })
    }
    await page.getByRole("dialog").getByRole("button", { name: "Close", exact: true }).first().click()
    await page.getByRole("button", { name: "Edit " + code, exact: true }).click()
    await page.getByRole("button", { name: "Add Media", exact: true }).click()
    await page.locator("#media_url").fill(image)
    await page.locator("#media_caption").fill("Real JPEG from QA media server")
    const mediaResponse = responseFor("POST", "/artifacts/" + artifact.id + "/media")
    await page.getByRole("button", { name: "Add Media", exact: true }).click()
    const storedMedia = await body(await mediaResponse)
    await expect(page.getByText("Media added successfully.", { exact: true })).toBeVisible()
    // The current Admin media list exposes a link, rather than an inline preview.
    await expect(page.getByRole("link", { name: image, exact: true })).toBeVisible()
    const mediaPage = await page.context().newPage()
    await mediaPage.goto(image)
    const img = mediaPage.locator("img").first()
    await expect(img).toBeVisible()
    await expect.poll(() => img.evaluate(e => e.complete && e.naturalWidth > 0)).toBe(true)
    await mediaPage.screenshot({ path: path.join(evidence, "web-real-image.jpg"), type: "jpeg", quality: 80 })
    await mediaPage.close()
    record("WEB-05", { media_id: storedMedia.id, url: storedMedia.url, image_decoded: true })
    await page.getByRole("dialog").getByRole("button", { name: "Cancel", exact: true }).click()

    await page.getByRole("button", { name: "Manage translations for " + code, exact: true }).click()
    await page.getByRole("dialog").getByRole("button", { name: "Tiếng Việt", exact: true }).click()
    const updatedTitle = "Trống đồng đã cập nhật từ Web"
    await page.locator("#translation-title").fill(updatedTitle)
    const updateResponse = responseFor("PUT", "/artifacts/" + artifact.id + "/translations/")
    await page.getByRole("button", { name: "Save translation", exact: true }).click()
    assert.equal((await body(await updateResponse)).title, updatedTitle)
    await expect(page.getByRole("button", { name: "Save translation", exact: true })).toBeEnabled()
    await page.getByRole("dialog").getByRole("button", { name: "Close", exact: true }).first().click()
    record("WEB-07", { title: updatedTitle })
    await page.screenshot({ path: path.join(evidence, "web-artifact.png"), fullPage: true })

    await page.goto(web + "/beacons")
    await page.getByRole("button", { name: /Add beacon/i }).first().click()
    const dialog = page.getByRole("dialog")
    const uuid = require("node:crypto").randomUUID()
    await dialog.getByLabel("Proximity UUID", { exact: false }).fill(uuid)
    await dialog.getByLabel("Major", { exact: true }).fill("101")
    await dialog.getByLabel("Minor", { exact: true }).fill("202")
    await dialog.getByRole("combobox").nth(0).selectOption(site.id)
    await expect(dialog.getByRole("combobox").nth(1)).toBeEnabled()
    await dialog.getByRole("combobox").nth(1).selectOption(artifact.id)
    const beaconResponse = responseFor("POST", "/beacons/")
    await dialog.getByRole("button", { name: "Add Beacon", exact: true }).click()
    const beacon = await body(await beaconResponse)
    await expect(page.getByRole("dialog")).toHaveCount(0)
    record("WEB-06", { beacon_id: beacon.id, artifact_id: beacon.artifact_id, site_id: beacon.site_id })
    await page.screenshot({ path: path.join(evidence, "web-beacon.png"), fullPage: true })
    fs.writeFileSync(process.env.QA_HANDOFF_FILE, JSON.stringify({ site, artifact, beacon, image, updatedTitle }, null, 2))
    console.log("Web Admin acceptance: " + steps.length + " checks PASS; handoff saved outside Git")
  } catch (error) {
    steps.push({ id: "WEB-ERROR", status: "FAIL", message: error.message })
    save()
    await page.screenshot({ path: path.join(evidence, "web-failure.png"), fullPage: true }).catch(() => {})
    throw error
  } finally {
    await browser.close()
  }
}

main().catch(error => { console.error(error); process.exitCode = 1 })
