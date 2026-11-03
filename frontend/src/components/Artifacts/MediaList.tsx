
import {
  ExternalLink,
  FileImage,
  Music2,
  Pencil,
  Trash2,
  Video,
} from "lucide-react"

import type { LanguagePublic, MediaPublic } from "@/client"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Skeleton } from "@/components/ui/skeleton"

type MediaListProps = {
  media: MediaPublic[]
  languages: LanguagePublic[]
  isLoading?: boolean
  error?: string | null
  deletingMediaId?: string | null
  onRetry?: () => void
  onEdit: (media: MediaPublic) => void
  onDelete: (media: MediaPublic) => void
}

function getMediaType(type?: string) {
  switch (type) {
    case "video":
      return {
        label: "Video",
        icon: Video,
        variant: "default" as const,
      }
    case "audio":
      return {
        label: "Audio",
        icon: Music2,
        variant: "secondary" as const,
      }
    default:
      return {
        label: "Image",
        icon: FileImage,
        variant: "outline" as const,
      }
  }
}

export function MediaList({
  media,
  languages,
  isLoading = false,
  error,
  deletingMediaId,
  onRetry,
  onEdit,
  onDelete,
}: MediaListProps) {
  function getLanguageName(languageId?: string | null) {
    if (!languageId) return "Shared"

    return (
      languages.find((language) => language.id === languageId)?.name ??
      "Unknown language"
    )
  }

  if (isLoading) {
    return (
      <div className="space-y-3">
        {Array.from({ length: 3 }, (_, index) => (
          <Skeleton key={index} className="h-20 w-full rounded-lg" />
        ))}
      </div>
    )
  }

  if (error) {
    return (
      <div
        role="alert"
        className="rounded-lg border border-destructive/30 bg-destructive/5 p-4"
      >
        <p className="text-sm font-medium text-destructive">
          Could not load media
        </p>
        <p className="mt-1 text-sm text-muted-foreground">{error}</p>

        {onRetry && (
          <Button
            className="mt-3"
            variant="outline"
            size="sm"
            onClick={onRetry}
          >
            Try again
          </Button>
        )}
      </div>
    )
  }

  if (media.length === 0) {
    return (
      <div className="rounded-lg border border-dashed p-8 text-center">
        <FileImage className="mx-auto size-9 text-muted-foreground" />

        <p className="mt-3 font-medium">No media yet</p>

        <p className="mt-1 text-sm text-muted-foreground">
          Add an image, video, or audio URL for this artifact.
        </p>
      </div>
    )
  }

  return (
    <div className="space-y-3">
      {media.map((item) => {
        const mediaType = getMediaType(item.media_type)
        const MediaIcon = mediaType.icon

        return (
          <div
            key={item.id}
            className="flex flex-col gap-3 rounded-lg border p-3 sm:flex-row sm:items-center"
          >
            <div className="flex size-12 shrink-0 items-center justify-center rounded-lg bg-muted">
              <MediaIcon className="size-6 text-muted-foreground" />
            </div>

            <div className="min-w-0 flex-1 space-y-1">
              <div className="flex flex-wrap items-center gap-2">
                <Badge variant={mediaType.variant}>
                  {mediaType.label}
                </Badge>

                <Badge variant="outline">
                  {getLanguageName(item.language_id)}
                </Badge>

                <span className="text-xs text-muted-foreground">
                  Order: {item.sort_order ?? 0}
                </span>
              </div>

              <p className="truncate text-sm font-medium">
                {item.caption || "Untitled media"}
              </p>

              <a
                href={item.url}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex max-w-full items-center gap-1 text-xs text-muted-foreground hover:text-primary"
                title={item.url}
              >
                <span className="truncate">{item.url}</span>
                <ExternalLink className="size-3 shrink-0" />
              </a>
            </div>

            <div className="flex shrink-0 items-center justify-end gap-1">
              <Button
                type="button"
                size="icon"
                variant="ghost"
                aria-label="Edit media"
                onClick={() => onEdit(item)}
              >
                <Pencil />
              </Button>

              <Button
                type="button"
                size="icon"
                variant="ghost"
                aria-label="Delete media"
                disabled={deletingMediaId === item.id}
                onClick={() => onDelete(item)}
              >
                <Trash2 className="text-destructive" />
              </Button>
            </div>
          </div>
        )
      })}
    </div>
  )
}
