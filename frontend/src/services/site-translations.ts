import axios, { AxiosError } from "axios"
import type { Site } from "@/services/sites"

export type SiteTranslationInput = Pick<
  Site,
  "name" | "description" | "address"
>

export type SiteTranslation = SiteTranslationInput & {
  id: string
  site_id: string
  language_id: string
  language_code: string
  source_hash: string
  translation_source: string
  is_confirmed: boolean
  is_stale: boolean
  updated_at: string | null
}

export type TranslationLanguage = {
  id: string
  code: string
  name: string
  is_active: boolean
}

const api = axios.create({ baseURL: import.meta.env.VITE_API_URL ?? "" })

function headers() {
  const token = localStorage.getItem("access_token")
  if (!token)
    throw new Error("Sign in as an administrator to manage translations.")
  return { Authorization: `Bearer ${token}` }
}

function toTranslationError(error: unknown): Error {
  if (!(error instanceof AxiosError)) {
    return error instanceof Error
      ? error
      : new Error("Site translation request failed.")
  }
  if (error.response?.status === 401) {
    localStorage.removeItem("access_token")
    window.location.assign("/login")
    return new Error("Your session has expired. Please sign in again.")
  }
  if (error.response?.status === 403)
    return new Error("You do not have permission to manage Site translations.")
  const detail = (error.response?.data as { detail?: unknown } | undefined)
    ?.detail
  return new Error(
    typeof detail === "string"
      ? detail
      : `Site translation request failed (${error.response?.status ?? "network"}).`,
  )
}

async function run<T>(request: Promise<{ data: T }>): Promise<T> {
  try {
    return (await request).data
  } catch (error) {
    throw toTranslationError(error)
  }
}

export const siteTranslationsService = {
  async languages(): Promise<TranslationLanguage[]> {
    const response = await run(
      api.get<{ data: TranslationLanguage[] }>("/api/v1/languages/", {
        headers: headers(),
      }),
    )
    return response.data.filter((language) => language.is_active)
  },

  list(siteId: string): Promise<SiteTranslation[]> {
    return run(
      api.get(`/api/v1/sites/${siteId}/translations`, { headers: headers() }),
    )
  },

  save(
    siteId: string,
    languageId: string,
    input: SiteTranslationInput,
  ): Promise<SiteTranslation> {
    return run(
      api.put(`/api/v1/sites/${siteId}/translations/${languageId}`, input, {
        headers: headers(),
      }),
    )
  },

  remove(siteId: string, languageId: string): Promise<void> {
    return run<{ message: string }>(
      api.delete(`/api/v1/sites/${siteId}/translations/${languageId}`, {
        headers: headers(),
      }),
    ).then(() => undefined)
  },
}
