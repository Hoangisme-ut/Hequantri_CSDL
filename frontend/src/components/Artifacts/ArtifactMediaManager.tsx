
import { useState } from "react"
import {
  useMutation,
  useQuery,
  useQueryClient,
} from "@tanstack/react-query"
import { Plus, X } from "lucide-react"

import type {
  MediaCreate,
  MediaPublic,
  MediaUpdate,
} from "@/client"

import { translationsService } from "@/services/translations"
import { mediaKeys, mediaService } from "@/services/media"

import MediaForm from "./MediaForm"
import { MediaList } from "./MediaList"

interface ArtifactMediaManagerProps {
  artifactId: string
}

export default function ArtifactMediaManager({
  artifactId,
}: ArtifactMediaManagerProps) {
  const queryClient = useQueryClient()

  const [editingMedia, setEditingMedia] =
    useState<MediaPublic | null>(null)

  const [isFormOpen, setIsFormOpen] = useState(false)
  const [feedback, setFeedback] = useState<{
    type: "success" | "error"
    message: string
  } | null>(null)

  // Load Media list
  const mediaQuery = useQuery({
    queryKey: mediaKeys.byArtifact(artifactId),
    queryFn: () => mediaService.list(artifactId),
    enabled: Boolean(artifactId),
  })

  // Load available languages
  const languagesQuery = useQuery({
    queryKey: ["languages", "active"],
    queryFn: () => translationsService.languages(),
  })

  // Refresh Media data after mutations
  const refreshMedia = async () => {
    await queryClient.invalidateQueries({
      queryKey: mediaKeys.byArtifact(artifactId),
    })
  }

  // Create Media
  const createMutation = useMutation({
    mutationFn: (input: MediaCreate) =>
      mediaService.create(artifactId, input),

    onSuccess: async () => {
      await refreshMedia()
      setIsFormOpen(false)
      setEditingMedia(null)
      setFeedback({
        type: "success",
        message: "Media added successfully.",
      })
    },

    onError: (error) => {
      setFeedback({
        type: "error",
        message:
          error instanceof Error
            ? error.message
            : "Failed to add media.",
      })
    },
  })

  // Update Media
  const updateMutation = useMutation({
    mutationFn: ({
      mediaId,
      input,
    }: {
      mediaId: string
      input: MediaUpdate
    }) => mediaService.update(artifactId, mediaId, input),

    onSuccess: async () => {
      await refreshMedia()
      setIsFormOpen(false)
      setEditingMedia(null)
      setFeedback({
        type: "success",
        message: "Media updated successfully.",
      })
    },

    onError: (error) => {
      setFeedback({
        type: "error",
        message:
          error instanceof Error
            ? error.message
            : "Failed to update media.",
      })
    },
  })

  // Delete Media
  const deleteMutation = useMutation({
    mutationFn: (mediaId: string) =>
      mediaService.remove(artifactId, mediaId),

    onSuccess: async () => {
      await refreshMedia()
      setFeedback({
        type: "success",
        message: "Media deleted successfully.",
      })
    },

    onError: (error) => {
      setFeedback({
        type: "error",
        message:
          error instanceof Error
            ? error.message
            : "Failed to delete media.",
      })
    },
  })

  const isSubmitting =
    createMutation.isPending || updateMutation.isPending

  const handleAdd = () => {
    setEditingMedia(null)
    setFeedback(null)
    setIsFormOpen(true)
  }

  const handleEdit = (media: MediaPublic) => {
    setEditingMedia(media)
    setFeedback(null)
    setIsFormOpen(true)
  }

  const handleCancel = () => {
    if (isSubmitting) return

    setIsFormOpen(false)
    setEditingMedia(null)
  }

  const handleSubmit = async (input: MediaCreate) => {
    setFeedback(null)

    if (editingMedia) {
      await updateMutation.mutateAsync({
        mediaId: editingMedia.id,
        input: input as MediaUpdate,
      })
    } else {
      await createMutation.mutateAsync(input)
    }
  }

  const handleDelete = (media: MediaPublic) => {
    const confirmed = window.confirm(
      `Are you sure you want to delete "${media.caption || media.media_type || "this media"}"?`,
    )

    if (!confirmed) return

    setFeedback(null)
    deleteMutation.mutate(media.id)
  }

  const mediaError = mediaQuery.error
    ? mediaQuery.error instanceof Error
      ? mediaQuery.error.message
      : "Failed to load media."
    : null

  const languageError = languagesQuery.error
    ? languagesQuery.error instanceof Error
      ? languagesQuery.error.message
      : "Failed to load languages."
    : null

  return (
    <section className="space-y-5">
      {/* Header */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h3 className="text-lg font-semibold">Media Management</h3>
          <p className="text-sm text-muted-foreground">
            Manage images, videos, and audio associated with this artifact.
          </p>
        </div>

        {!isFormOpen && (
          <button
            type="button"
            onClick={handleAdd}
            className="inline-flex items-center justify-center gap-2 rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground hover:opacity-90"
          >
            <Plus className="size-4" />
            Add Media
          </button>
        )}
      </div>

      {/* Feedback */}
      {feedback && (
        <div
          role="alert"
          className={`flex items-start justify-between gap-3 rounded-md border p-3 text-sm ${
            feedback.type === "success"
              ? "border-green-200 bg-green-50 text-green-700"
              : "border-destructive/30 bg-destructive/5 text-destructive"
          }`}
        >
          <p>{feedback.message}</p>

          <button
            type="button"
            aria-label="Dismiss message"
            onClick={() => setFeedback(null)}
          >
            <X className="size-4" />
          </button>
        </div>
      )}

      {/* Form */}
      {isFormOpen && (
        <div className="rounded-lg border p-4 sm:p-5">
          <div className="mb-4 flex items-center justify-between gap-2">
            <h4 className="font-semibold">
              {editingMedia ? "Edit Media" : "Add New Media"}
            </h4>

            <button
              type="button"
              onClick={handleCancel}
              disabled={isSubmitting}
              aria-label="Close form"
              className="rounded-md p-1 hover:bg-muted disabled:opacity-50"
            >
              <X className="size-5" />
            </button>
          </div>

          {languagesQuery.isLoading ? (
            <p className="text-sm text-muted-foreground">
              Loading languages...
            </p>
          ) : languageError ? (
            <div className="space-y-2">
              <p className="text-sm text-destructive">
                {languageError}
              </p>

              <button
                type="button"
                onClick={() => languagesQuery.refetch()}
                className="text-sm font-medium text-primary hover:underline"
              >
                Retry
              </button>
            </div>
          ) : (
            <MediaForm
              languages={languagesQuery.data ?? []}
              initialData={editingMedia}
              isSubmitting={isSubmitting}
              onSubmit={handleSubmit}
              onCancel={handleCancel}
            />
          )}
        </div>
      )}

      {/* Media List */}
      <div className="space-y-3">
        <div className="flex items-center justify-between">
          <h4 className="font-medium">
            Media Files
            {mediaQuery.data && (
              <span className="ml-2 text-sm font-normal text-muted-foreground">
                ({mediaQuery.data.length})
              </span>
            )}
          </h4>
        </div>

        <MediaList
          media={mediaQuery.data ?? []}
          languages={languagesQuery.data ?? []}
          isLoading={mediaQuery.isLoading}
          error={mediaError}
          deletingMediaId={
            deleteMutation.isPending
              ? deleteMutation.variables
              : null
          }
          onRetry={() => mediaQuery.refetch()}
          onEdit={handleEdit}
          onDelete={handleDelete}
        />
      </div>
    </section>
  )
}
