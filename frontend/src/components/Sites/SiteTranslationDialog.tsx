import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { Languages } from "lucide-react"
import { useEffect, useState } from "react"
import { toast } from "sonner"
import { ErrorState } from "@/components/Common/AdminPrimitives"
import { Button } from "@/components/ui/button"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Skeleton } from "@/components/ui/skeleton"
import type { Site } from "@/services/sites"
import {
  type SiteTranslationInput,
  siteTranslationsService,
} from "@/services/site-translations"

type LanguageCode = "en" | "vi"

export function SiteTranslationDialog({
  site,
  open,
  onOpenChange,
}: {
  site: Site | null
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const queryClient = useQueryClient()
  const [languageCode, setLanguageCode] = useState<LanguageCode>("vi")
  const [englishDraft, setEnglishDraft] = useState<SiteTranslationInput | null>(
    null,
  )

  useEffect(() => {
    if (open) {
      setLanguageCode("vi")
      setEnglishDraft(null)
    }
  }, [open, site?.id])

  const languagesQuery = useQuery({
    queryKey: ["languages", "active"],
    queryFn: siteTranslationsService.languages,
    enabled: open,
  })
  const translationsQuery = useQuery({
    queryKey: ["site-translations", site?.id],
    queryFn: () => siteTranslationsService.list(site!.id),
    enabled: open && site !== null,
  })
  const english = languagesQuery.data?.find(
    (language) => language.code === "en",
  )
  const saved = translationsQuery.data?.find(
    (translation) => translation.language_code === "en",
  )
  const isEnglish = languageCode === "en"
  const values = isEnglish
    ? (englishDraft ?? {
        name: saved?.name ?? "",
        description: saved?.description ?? "",
        address: saved?.address ?? "",
      })
    : {
        name: site?.name ?? "",
        description: site?.description ?? "",
        address: site?.address ?? "",
      }
  const canManage = isEnglish && translationsQuery.isSuccess

  const afterSave = async (message: string) => {
    await Promise.all([
      queryClient.invalidateQueries({
        queryKey: ["site-translations", site?.id],
      }),
      queryClient.invalidateQueries({ queryKey: ["sites"] }),
    ])
    toast.success(message)
  }

  const saveMutation = useMutation({
    mutationFn: () => {
      if (!english || !site || !values.name.trim())
        throw new Error(
          "An English language and translation name are required.",
        )
      return siteTranslationsService.save(site.id, english.id, {
        name: values.name.trim(),
        description: values.description?.trim() || null,
        address: values.address?.trim() || null,
      })
    },
    onSuccess: async () => {
      setEnglishDraft(null)
      await afterSave("English translation saved and confirmed.")
    },
    onError: (error) => toast.error(error.message),
  })

  const deleteMutation = useMutation({
    mutationFn: () => {
      if (!site || !english)
        throw new Error("English translation is unavailable.")
      return siteTranslationsService.remove(site.id, english.id)
    },
    onSuccess: async () => {
      setEnglishDraft(null)
      await afterSave(
        "English translation deleted. Vietnamese fallback is active.",
      )
    },
    onError: (error) => toast.error(error.message),
  })
  const isPending = saveMutation.isPending || deleteMutation.isPending

  function update(field: keyof SiteTranslationInput, value: string) {
    setEnglishDraft((current) => ({
      name: current?.name ?? saved?.name ?? "",
      description: current?.description ?? saved?.description ?? "",
      address: current?.address ?? saved?.address ?? "",
      [field]: value,
    }))
  }

  function retry() {
    void languagesQuery.refetch()
    void translationsQuery.refetch()
  }

  const availableLanguages = languagesQuery.data ?? []
  const languageDataReady =
    availableLanguages.some((language) => language.code === "vi") &&
    availableLanguages.some((language) => language.code === "en")

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[90dvh] overflow-y-auto sm:max-w-2xl">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2 pr-6">
            <Languages className="size-4 shrink-0" />
            <span className="truncate">Site translation · {site?.name}</span>
          </DialogTitle>
          <DialogDescription>
            Review the source language or edit and confirm the English
            translation.
          </DialogDescription>
        </DialogHeader>

        {languagesQuery.isLoading ? (
          <Skeleton className="h-10 w-full" />
        ) : languagesQuery.isError ? (
          <ErrorState
            title="Could not load languages"
            description={languagesQuery.error.message}
            onRetry={() => void languagesQuery.refetch()}
          />
        ) : !languageDataReady ? (
          <ErrorState
            title="Required languages are unavailable"
            description="Vietnamese and English must both be active to manage Site translations."
            onRetry={() => void languagesQuery.refetch()}
          />
        ) : translationsQuery.isLoading ? (
          <div className="space-y-3">
            <Skeleton className="h-10 w-full" />
            <Skeleton className="h-10 w-full" />
            <Skeleton className="h-24 w-full" />
          </div>
        ) : translationsQuery.isError ? (
          <ErrorState
            title="Could not load Site translations"
            description={translationsQuery.error.message}
            onRetry={retry}
          />
        ) : (
          <>
            <div
              className="flex flex-wrap gap-2"
              role="tablist"
              aria-label="Site translation language"
            >
              {(
                [
                  ["en", "English"],
                  ["vi", "Tiếng Việt"],
                ] as const
              ).map(([code, label]) => (
                <Button
                  key={code}
                  type="button"
                  role="tab"
                  aria-selected={languageCode === code}
                  size="sm"
                  variant={languageCode === code ? "default" : "outline"}
                  onClick={() => setLanguageCode(code)}
                >
                  {label}
                </Button>
              ))}
            </div>

            <p
              className="rounded-md border bg-muted/30 p-3 text-sm text-muted-foreground"
              role="status"
            >
              {isEnglish
                ? saved?.is_stale
                  ? "The Vietnamese source has changed. Update and save this translation to confirm the current version."
                  : saved?.is_confirmed
                    ? "English translation is confirmed. Saving will update it."
                    : saved
                      ? "This English translation is unconfirmed. Review and save it to confirm."
                      : "No English translation exists yet. Public pages will use Vietnamese until a translation is confirmed."
                : "Vietnamese is the original Site content. It is shown here as read-only and is not changed by editing English."}
            </p>

            <div className="grid gap-4" role="tabpanel">
              <label
                htmlFor="site-translation-name"
                className="grid gap-1.5 text-sm font-medium"
              >
                Site Name
                <Input
                  id="site-translation-name"
                  required={isEnglish}
                  maxLength={255}
                  value={values.name}
                  readOnly={!isEnglish}
                  onChange={(event) => update("name", event.target.value)}
                />
              </label>
              <label
                htmlFor="site-translation-description"
                className="grid gap-1.5 text-sm font-medium"
              >
                Description
                <textarea
                  id="site-translation-description"
                  maxLength={2000}
                  rows={4}
                  value={values.description ?? ""}
                  readOnly={!isEnglish}
                  onChange={(event) =>
                    update("description", event.target.value)
                  }
                  className="min-h-24 w-full min-w-0 resize-y rounded-md border border-input bg-transparent px-3 py-2 text-sm outline-none focus-visible:border-ring focus-visible:ring-ring/50 focus-visible:ring-[3px] read-only:cursor-default read-only:bg-muted/30"
                />
              </label>
              <label
                htmlFor="site-translation-address"
                className="grid gap-1.5 text-sm font-medium"
              >
                Address
                <Input
                  id="site-translation-address"
                  maxLength={500}
                  value={values.address ?? ""}
                  readOnly={!isEnglish}
                  onChange={(event) => update("address", event.target.value)}
                />
              </label>
            </div>
            {(saveMutation.isError || deleteMutation.isError) && (
              <p role="alert" className="text-sm text-destructive">
                {saveMutation.error?.message ?? deleteMutation.error?.message}
              </p>
            )}
          </>
        )}

        <DialogFooter className="gap-2 sm:gap-2">
          {canManage && saved && (
            <Button
              type="button"
              variant="destructive"
              className="w-full sm:w-auto"
              disabled={isPending}
              onClick={() => {
                if (
                  window.confirm(
                    "Delete the English Site translation? Public pages will fall back to Vietnamese.",
                  )
                ) {
                  deleteMutation.mutate()
                }
              }}
            >
              {deleteMutation.isPending ? "Deleting…" : "Delete translation"}
            </Button>
          )}
          <Button
            type="button"
            variant="outline"
            className="w-full sm:w-auto"
            onClick={() => onOpenChange(false)}
          >
            Close
          </Button>
          {canManage && isEnglish && (
            <Button
              type="button"
              className="w-full sm:w-auto"
              disabled={!english || !values.name.trim() || isPending}
              onClick={() => saveMutation.mutate()}
            >
              {saveMutation.isPending ? "Saving…" : "Save translation"}
            </Button>
          )}
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
