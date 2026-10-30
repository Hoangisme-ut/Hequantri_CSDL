import {
  ArtifactsService,
  type ArtifactTranslationBase,
  type ArtifactTranslationPublic,
  type LanguagePublic,
  LanguagesService,
} from "@/client"
import { unwrapApi } from "./api-errors"

export const languageKeys = {
  all: ["languages"] as const,
  active: () => [...languageKeys.all, "active"] as const,
}

export const translationKeys = {
  all: ["translations"] as const,
  byArtifact: (artifactId: string) =>
    [...translationKeys.all, artifactId] as const,
}

export const translationsService = {
  async list(artifactId: string): Promise<ArtifactTranslationPublic[]> {
    return unwrapApi(
      ArtifactsService.readTranslations({ path: { artifact_id: artifactId } }),
      "Translation",
    )
  },

  async upsert(
    artifactId: string,
    languageId: string,
    input: ArtifactTranslationBase,
  ): Promise<ArtifactTranslationPublic> {
    return unwrapApi(
      ArtifactsService.upsertTranslation({
        path: { artifact_id: artifactId, language_id: languageId },
        body: input,
      }),
      "Translation",
    )
  },

  async remove(artifactId: string, languageId: string): Promise<void> {
    await unwrapApi(
      ArtifactsService.deleteTranslation({
        path: { artifact_id: artifactId, language_id: languageId },
      }),
      "Translation",
    )
  },

  async languages(): Promise<LanguagePublic[]> {
    const response = await unwrapApi(
      LanguagesService.readLanguages(),
      "Language",
    )
    return response.data
  },
}
