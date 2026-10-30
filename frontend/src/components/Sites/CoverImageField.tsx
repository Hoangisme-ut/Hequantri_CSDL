import { ImageOff, ImagePlus } from "lucide-react"
import { useState } from "react"

import { Input } from "@/components/ui/input"
import { isValidCoverImageUrl } from "@/services/site-validation"

export function CoverImageField({
  value,
  onChange,
}: {
  value: string
  onChange: (value: string) => void
}) {
  const [failedUrl, setFailedUrl] = useState("")
  const imageUrl = value.trim()
  const validUrl = imageUrl && isValidCoverImageUrl(imageUrl)
  const loadFailed = Boolean(imageUrl) && failedUrl === imageUrl

  return (
    <div className="grid gap-2">
      <label
        htmlFor="site-cover-image"
        className="grid gap-1.5 text-sm font-medium"
      >
        Cover image URL (optional)
        <Input
          id="site-cover-image"
          type="text"
          inputMode="url"
          maxLength={500}
          value={value}
          onChange={(event) => onChange(event.target.value)}
          placeholder="https://example.com/image.jpg"
          aria-describedby="site-cover-image-help"
        />
      </label>
      <p id="site-cover-image-help" className="text-xs text-muted-foreground">
        Optional. Enter a direct image URL. The image file is not uploaded.
      </p>
      <div
        className="flex min-h-28 items-center justify-center overflow-hidden rounded-lg border border-border/70 bg-muted/30"
        aria-live="polite"
      >
        {validUrl && !loadFailed ? (
          <img
            src={imageUrl}
            alt="Site cover preview"
            className="max-h-48 w-full object-cover"
            onError={() => setFailedUrl(imageUrl)}
          />
        ) : (
          <div className="flex flex-col items-center gap-2 p-4 text-center text-xs text-muted-foreground">
            {loadFailed ? (
              <ImageOff className="size-5" aria-hidden="true" />
            ) : (
              <ImagePlus className="size-5" aria-hidden="true" />
            )}
            <span>
              {loadFailed
                ? "Image could not be loaded. The rest of the form is still available."
                : value.trim()
                  ? "Enter a valid HTTP or HTTPS image URL to preview."
                  : "Image preview will appear here."}
            </span>
          </div>
        )}
      </div>
    </div>
  )
}
