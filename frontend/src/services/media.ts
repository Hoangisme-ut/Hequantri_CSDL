
import {
  MediaService,
  type MediaCreate,
  type MediaPublic,
  type MediaUpdate,
} from "@/client"
import { unwrapApi } from "./api-errors"

export const mediaKeys = {
  all: ["media"] as const,

  byArtifact: (artifactId: string) =>
    [...mediaKeys.all, artifactId] as const,

  detail: (artifactId: string, mediaId: string) =>
    [...mediaKeys.byArtifact(artifactId), mediaId] as const,
}

export const mediaService = {
  /**
   * Lấy danh sách Media của một Artifact.
   */
  async list(artifactId: string): Promise<MediaPublic[]> {
    return unwrapApi(
      MediaService.readMediaList({
        path: { artifact_id: artifactId },
      }),
      "Media",
    )
  },

  /**
   * Lấy thông tin chi tiết một Media.
   */
  async get(
    artifactId: string,
    mediaId: string,
  ): Promise<MediaPublic> {
    return unwrapApi(
      MediaService.readMedia({
        path: {
          artifact_id: artifactId,
          media_id: mediaId,
        },
      }),
      "Media",
    )
  },

  /**
   * Thêm Media mới cho Artifact.
   */
  async create(
    artifactId: string,
    input: MediaCreate,
  ): Promise<MediaPublic> {
    return unwrapApi(
      MediaService.createMedia({
        path: { artifact_id: artifactId },
        body: input,
      }),
      "Media",
    )
  },

  /**
   * Cập nhật Media hiện có.
   */
  async update(
    artifactId: string,
    mediaId: string,
    input: MediaUpdate,
  ): Promise<MediaPublic> {
    return unwrapApi(
      MediaService.updateMedia({
        path: {
          artifact_id: artifactId,
          media_id: mediaId,
        },
        body: input,
      }),
      "Media",
    )
  },

  /**
   * Xóa metadata Media.*/
  async remove(
    artifactId: string,
    mediaId: string,
  ): Promise<void> {
    await unwrapApi(
      MediaService.deleteMedia({
        path: {
          artifact_id: artifactId,
          media_id: mediaId,
        },
      }),
      "Media",
    )
  },
}
