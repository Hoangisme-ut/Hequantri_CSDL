import type { Site, SiteInput } from "./sites"

export function isValidCoverImageUrl(value: string): boolean {
  try {
    const url = new URL(value)
    return url.protocol === "https:" || url.protocol === "http:"
  } catch {
    return false
  }
}

export function validateSiteInput(site: SiteInput): string[] {
  const errors: string[] = []
  if (!site.name.trim()) errors.push("Site name is required.")
  if (site.name.trim().length > 255) {
    errors.push("Site name must be 255 characters or fewer.")
  }
  if ((site.address?.length ?? 0) > 500) {
    errors.push("Address must be 500 characters or fewer.")
  }
  if ((site.description?.length ?? 0) > 2000) {
    errors.push("Description must be 2,000 characters or fewer.")
  }
  if (
    site.latitude !== null &&
    (!Number.isFinite(site.latitude) ||
      site.latitude < -90 ||
      site.latitude > 90)
  ) {
    errors.push("Latitude must be a number between -90 and 90.")
  }
  if (
    site.longitude !== null &&
    (!Number.isFinite(site.longitude) ||
      site.longitude < -180 ||
      site.longitude > 180)
  ) {
    errors.push("Longitude must be a number between -180 and 180.")
  }
  const imageUrl = site.cover_image_url?.trim() ?? ""
  if (imageUrl && (imageUrl.length > 500 || !isValidCoverImageUrl(imageUrl))) {
    errors.push(
      "Cover image must be a valid HTTP or HTTPS URL of 500 characters or fewer.",
    )
  }
  return errors
}

export function filterSites<T extends Pick<Site, "name" | "address">>(
  sites: T[],
  search: string,
): T[] {
  const term = search.trim().toLocaleLowerCase()
  if (!term) return sites
  return sites.filter((site) =>
    `${site.name} ${site.address ?? ""}`.toLocaleLowerCase().includes(term),
  )
}
