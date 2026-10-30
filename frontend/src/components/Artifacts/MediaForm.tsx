
import { useEffect, useState, type FormEvent } from "react"
import type {
  LanguagePublic,
  MediaCreate,
  MediaPublic,
} from "@/client"

type MediaType = "image" | "video" | "audio"

interface MediaFormProps {
  languages: LanguagePublic[]
  initialData?: MediaPublic | null
  isSubmitting?: boolean
  onSubmit: (data: MediaCreate) => Promise<void>
  onCancel?: () => void
}

interface MediaFormState {
  media_type: MediaType
  url: string
  caption: string
  language_id: string
  sort_order: number
}

const defaultFormState: MediaFormState = {
  media_type: "image",
  url: "",
  caption: "",
  language_id: "",
  sort_order: 0,
}

export default function MediaForm({
  languages,
  initialData = null,
  isSubmitting = false,
  onSubmit,
  onCancel,
}: MediaFormProps) {
  const [formData, setFormData] =
    useState<MediaFormState>(defaultFormState)

  const [error, setError] = useState("")

  useEffect(() => {
    if (initialData) {
      setFormData({
        media_type: (initialData.media_type ?? "image") as MediaType,
        url: initialData.url,
        caption: initialData.caption ?? "",
        language_id: initialData.language_id ?? "",
        sort_order: initialData.sort_order ?? 0,
      })
    } else {
      setFormData(defaultFormState)
    }

    setError("")
  }, [initialData])

  const handleChange = (
    field: keyof MediaFormState,
    value: string | number,
  ) => {
    setFormData((previous) => ({
      ...previous,
      [field]: value,
    }))
  }

  const validateForm = (): boolean => {
    if (!formData.url.trim()) {
      setError("Please enter a media URL.")
      return false
    }

    try {
      const parsedUrl = new URL(formData.url.trim())

      if (
        parsedUrl.protocol !== "http:" &&
        parsedUrl.protocol !== "https:"
      ) {
        setError("The URL must use HTTP or HTTPS.")
        return false
      }
    } catch {
      setError("Invalid URL. Please check the URL and try again.")
      return false
    }

    if (formData.url.trim().length > 500) {
      setError("The URL must not exceed 500 characters.")
      return false
    }

    if (
      !Number.isInteger(formData.sort_order) ||
      formData.sort_order < 0
    ) {
      setError("Sort order must be a non-negative integer.")
      return false
    }

    setError("")
    return true
  }

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()

    if (!validateForm()) return

    const payload: MediaCreate = {
      media_type: formData.media_type,
      url: formData.url.trim(),
      caption: formData.caption.trim() || null,
      language_id: formData.language_id || null,
      sort_order: formData.sort_order,
    }

    try {
      await onSubmit(payload)
    } catch {
      // The parent component handles and displays API errors.
    }
  }

  const activeLanguages = languages.filter(
    (language) => language.is_active !== false,
  )

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      {/* Media Type */}
      <div className="space-y-2">
        <label
          htmlFor="media_type"
          className="block text-sm font-medium"
        >
          Media Type
        </label>

        <select
          id="media_type"
          value={formData.media_type}
          onChange={(event) =>
            handleChange("media_type", event.target.value)
          }
          disabled={isSubmitting}
          className="w-full rounded-md border px-3 py-2 text-sm"
        >
          <option value="image">Image</option>
          <option value="video">Video</option>
          <option value="audio">Audio</option>
        </select>
      </div>

      {/* URL */}
      <div className="space-y-2">
        <label
          htmlFor="media_url"
          className="block text-sm font-medium"
        >
          Media URL <span className="text-red-500">*</span>
        </label>

        <input
          id="media_url"
          type="url"
          value={formData.url}
          onChange={(event) =>
            handleChange("url", event.target.value)
          }
          placeholder="https://example.com/image.jpg"
          maxLength={500}
          required
          disabled={isSubmitting}
          className="w-full rounded-md border px-3 py-2 text-sm"
        />

        <p className="text-xs text-muted-foreground">
          Enter an HTTP or HTTPS URL pointing to an image, video, or audio file.
        </p>
      </div>

      {/* Caption */}
      <div className="space-y-2">
        <label
          htmlFor="media_caption"
          className="block text-sm font-medium"
        >
          Caption
        </label>

        <textarea
          id="media_caption"
          value={formData.caption}
          onChange={(event) =>
            handleChange("caption", event.target.value)
          }
          placeholder="Enter a description for this media..."
          rows={3}
          disabled={isSubmitting}
          className="w-full resize-y rounded-md border px-3 py-2 text-sm"
        />
      </div>

      {/* Language */}
      <div className="space-y-2">
        <label
          htmlFor="language_id"
          className="block text-sm font-medium"
        >
          Language
        </label>

        <select
          id="language_id"
          value={formData.language_id}
          onChange={(event) =>
            handleChange("language_id", event.target.value)
          }
          disabled={isSubmitting}
          className="w-full rounded-md border px-3 py-2 text-sm"
        >
          <option value="">Shared (All Languages)</option>

          {activeLanguages.map((language) => (
            <option key={language.id} value={language.id}>
              {language.name} ({language.code})
            </option>
          ))}
        </select>

        <p className="text-xs text-muted-foreground">
          Select Shared if this media is available in all languages.
        </p>
      </div>

      {/* Sort Order */}
      <div className="space-y-2">
        <label
          htmlFor="sort_order"
          className="block text-sm font-medium"
        >
          Sort Order
        </label>

        <input
          id="sort_order"
          type="number"
          min={0}
          step={1}
          value={formData.sort_order}
          onChange={(event) =>
            handleChange(
              "sort_order",
              event.target.value === ""
                ? 0
                : Number(event.target.value),
            )
          }
          disabled={isSubmitting}
          className="w-full rounded-md border px-3 py-2 text-sm"
        />
      </div>

      {/* Error */}
      {error && (
        <div
          role="alert"
          className="rounded-md bg-red-50 p-3 text-sm text-red-600"
        >
          {error}
        </div>
      )}

      {/* Actions */}
      <div className="flex justify-end gap-2">
        {onCancel && (
          <button
            type="button"
            onClick={onCancel}
            disabled={isSubmitting}
            className="rounded-md border px-4 py-2 text-sm hover:bg-muted disabled:opacity-50"
          >
            Cancel
          </button>
        )}

        <button
          type="submit"
          disabled={isSubmitting}
          className="rounded-md bg-primary px-4 py-2 text-sm text-primary-foreground hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {isSubmitting
            ? "Saving..."
            : initialData
              ? "Update Media"
              : "Add Media"}
        </button>
      </div>
    </form>
  )
}
