import type { Site, SiteInput, SiteService, SitesResponse } from "./sites"

const initialSites: Site[] = [
  {
    id: "demo-site-temple-of-literature",
    name: "Temple of Literature",
    address: "58 Quoc Tu Giam, Dong Da, Hanoi",
    description:
      "A historic complex dedicated to Confucius and Vietnam's scholars, including the Imperial Academy.",
    latitude: 21.0278,
    longitude: 105.8355,
    cover_image_url: null,
    is_active: true,
    created_at: "2025-10-01T08:00:00Z",
    updated_at: null,
  },
  {
    id: "demo-site-thang-long-citadel",
    name: "Imperial Citadel of Thang Long",
    address: "19C Hoang Dieu, Ba Dinh, Hanoi",
    description:
      "UNESCO World Heritage archaeological site and former political centre of Thang Long.",
    latitude: 21.0358,
    longitude: 105.8412,
    cover_image_url: null,
    is_active: true,
    created_at: "2025-10-02T08:00:00Z",
    updated_at: null,
  },
  {
    id: "demo-site-one-pillar-pagoda",
    name: "One Pillar Pagoda",
    address: "Chua Mot Cot, Ba Dinh, Hanoi",
    description:
      "An eleventh-century Buddhist temple known for its distinctive lotus-shaped structure.",
    latitude: 21.0359,
    longitude: 105.8334,
    cover_image_url: null,
    is_active: false,
    created_at: "2025-10-03T08:00:00Z",
    updated_at: null,
  },
]

let sites = initialSites.map((site) => ({ ...site }))

function findSite(id: string): Site {
  const site = sites.find((record) => record.id === id)
  if (!site) throw new Error("Site not found in demo data")
  return site
}

export const mockSitesService: SiteService = {
  async list(): Promise<SitesResponse> {
    const data = [...sites]
      .sort((first, second) => first.name.localeCompare(second.name))
      .map((site) => ({ ...site }))
    return { data, count: data.length }
  },
  async get(id) {
    return { ...findSite(id) }
  },
  async create(input: SiteInput) {
    const site: Site = {
      ...input,
      id: `demo-site-${crypto.randomUUID()}`,
      created_at: new Date().toISOString(),
      updated_at: null,
    }
    sites = [...sites, site]
    return { ...site }
  },
  async update(id, input) {
    const current = findSite(id)
    const updated = {
      ...current,
      ...input,
      updated_at: new Date().toISOString(),
    }
    sites = sites.map((site) => (site.id === id ? updated : site))
    return { ...updated }
  },
  async deactivate(id) {
    const current = findSite(id)
    const updated = {
      ...current,
      is_active: false,
      updated_at: new Date().toISOString(),
    }
    sites = sites.map((site) => (site.id === id ? updated : site))
  },
}
