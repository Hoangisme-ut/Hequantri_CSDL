import {
  type ArtifactContentPublic,
  type ArtifactCreate,
  type ArtifactPublic,
  type ArtifactSummary,
  ArtifactsService,
  type ArtifactUpdate,
  type artifactsReadArtifactsData,
} from "@/client"
import { unwrapApi } from "./api-errors"

export type ArtifactFilters = NonNullable<artifactsReadArtifactsData["query"]>

export const artifactKeys = {
  all: ["artifacts"] as const,
  lists: () => [...artifactKeys.all, "list"] as const,
  list: (filters: ArtifactFilters) =>
    [...artifactKeys.lists(), filters] as const,
  details: () => [...artifactKeys.all, "detail"] as const,
  detail: (id: string, lang?: string) =>
    [...artifactKeys.details(), id, lang ?? ""] as const,
}

export const artifactsService = {
  async list(filters: ArtifactFilters = {}) {
    return unwrapApi(
      ArtifactsService.readArtifacts({ query: filters }),
      "Artifact",
    )
  },

  async get(id: string, lang?: string): Promise<ArtifactContentPublic> {
    return unwrapApi(
      ArtifactsService.readArtifact({
        path: { artifact_id: id },
        query: lang ? { lang } : {},
      }),
      "Artifact",
    )
  },

  async create(input: ArtifactCreate): Promise<ArtifactPublic> {
    return unwrapApi(
      ArtifactsService.createArtifact({ body: input }),
      "Artifact",
    )
  },

  async update(id: string, input: ArtifactUpdate): Promise<ArtifactPublic> {
    return unwrapApi(
      ArtifactsService.updateArtifact({
        path: { artifact_id: id },
        body: input,
      }),
      "Artifact",
    )
  },

  async deactivate(id: string): Promise<void> {
    await unwrapApi(
      ArtifactsService.deleteArtifact({ path: { artifact_id: id } }),
      "Artifact",
    )
  },
}

export type { ArtifactSummary }
