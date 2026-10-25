import type { SitePublic, SitesPublic, SiteUpdate } from "@/client"

export type Site = SitePublic & {
  id: string
  name: string
  address: string | null
  description: string | null
  latitude: number | null
  longitude: number | null
  cover_image_url: string | null
  is_active: boolean
  created_at: string | null
  updated_at: string | null
}

export type SiteInput = Pick<
  Site,
  | "name"
  | "address"
  | "description"
  | "latitude"
  | "longitude"
  | "cover_image_url"
  | "is_active"
>

export type SitePatch = SiteUpdate
export type SitesResponse = SitesPublic & { data: Site[] }

export interface SiteService {
  list(): Promise<SitesResponse>
  get(id: string): Promise<Site>
  create(site: SiteInput): Promise<Site>
  update(id: string, site: SiteInput): Promise<Site>
  deactivate(id: string): Promise<void>
}

export { apiSitesService as sitesService } from "./sites.api"
