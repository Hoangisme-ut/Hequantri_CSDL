import { AxiosError } from "axios"
import { type SitePublic, SitesService } from "@/client"
import type { Site, SiteInput, SiteService } from "./sites"

function normalizeSite(site: SitePublic): Site {
  return {
    ...site,
    address: site.address ?? null,
    description: site.description ?? null,
    latitude: site.latitude ?? null,
    longitude: site.longitude ?? null,
    cover_image_url: site.cover_image_url ?? null,
    is_active: site.is_active ?? true,
    created_at: site.created_at ?? null,
    updated_at: site.updated_at ?? null,
  }
}

function toSiteError(error: unknown): Error {
  if (!(error instanceof AxiosError)) {
    return error instanceof Error ? error : new Error("Site request failed.")
  }

  const detail = error.response?.data?.detail as
    | string
    | Array<{ loc?: Array<string | number>; msg?: string }>
    | undefined
  const message = Array.isArray(detail)
    ? detail
        .map((issue) => {
          const field = issue.loc?.slice(1).join(".")
          return [field, issue.msg].filter(Boolean).join(": ")
        })
        .filter(Boolean)
        .join("; ")
    : detail

  if (error.response?.status === 404) {
    return new Error(`Site was not found. ${message ?? ""}`.trim())
  }
  if (error.response?.status === 401) {
    localStorage.removeItem("access_token")
    window.location.assign("/login")
    return new Error("Your session has expired. Please sign in again.")
  }
  if (error.response?.status === 403) {
    return new Error("You do not have permission to manage sites.")
  }
  if (error.response?.status) {
    return new Error(
      `Site API request failed (${error.response.status}): ${message ?? error.message}`,
    )
  }
  return new Error(
    `Cannot reach the Site API. Check that the backend is running. ${error.message}`,
  )
}

async function requestSite<T>(request: Promise<{ data: T }>): Promise<T> {
  try {
    return (await request).data
  } catch (error) {
    throw toSiteError(error)
  }
}

export const apiSitesService: SiteService = {
  async list() {
    const response = await requestSite(
      SitesService.readSites({
        query: { include_inactive: true, limit: 200 },
      }),
    )
    return { ...response, data: response.data.map(normalizeSite) }
  },
  async get(id) {
    return normalizeSite(
      await requestSite(SitesService.readSite({ path: { site_id: id } })),
    )
  },
  async create(site: SiteInput) {
    return normalizeSite(
      await requestSite(SitesService.createSite({ body: site })),
    )
  },
  async update(id: string, site: SiteInput) {
    return normalizeSite(
      await requestSite(
        SitesService.updateSite({ path: { site_id: id }, body: site }),
      ),
    )
  },
  async deactivate(id) {
    await requestSite(SitesService.deleteSite({ path: { site_id: id } }))
  },
}
