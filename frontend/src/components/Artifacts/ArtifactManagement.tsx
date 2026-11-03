import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import ArtifactMediaManager from "./ArtifactMediaManager"
import {
  Archive,
  Eye,
  Languages,
  Pencil,
  Plus,
  Search,
  Trash2,
} from "lucide-react"
import { useEffect, useMemo, useState } from "react"
import { toast } from "sonner"

import type {
  ArtifactCreate,
  ArtifactSummary,
  ArtifactUpdate,
  LanguagePublic,
} from "@/client"
import { EmptyState, ErrorState } from "@/components/Common/AdminPrimitives"
import { Badge } from "@/components/ui/badge"
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
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { artifactKeys, artifactsService } from "@/services/artifacts"
import { sitesService } from "@/services/sites"
import {
  languageKeys,
  translationKeys,
  translationsService,
} from "@/services/translations"

type ArtifactDraft = {
  code: string
  site_id: string
  era: string
  latitude: string
  longitude: string
  cover_image_url: string
  is_active: boolean
}

type TranslationDraft = {
  title: string
  description: string
  history_content: string
}

const emptyArtifact: ArtifactDraft = {
  code: "",
  site_id: "",
  era: "",
  latitude: "",
  longitude: "",
  cover_image_url: "",
  is_active: true,
}

const toOptionalNumber = (value: string) =>
  value.trim() === "" ? null : Number(value)

function artifactPayload(draft: ArtifactDraft) {
  return {
    code: draft.code.trim(),
    site_id: draft.site_id,
    era: draft.era.trim() || null,
    latitude: toOptionalNumber(draft.latitude),
    longitude: toOptionalNumber(draft.longitude),
    cover_image_url: draft.cover_image_url.trim() || null,
    is_active: draft.is_active,
  }
}

function siteName(siteId: string, sites: Array<{ id: string; name: string }>) {
  return sites.find((site) => site.id === siteId)?.name ?? "Unknown site"
}

export function ArtifactManagement() {
  const queryClient = useQueryClient()
  const [search, setSearch] = useState("")
  const [siteFilter, setSiteFilter] = useState("")
  const [languageCode, setLanguageCode] = useState("")
  const [artifactDialogOpen, setArtifactDialogOpen] = useState(false)
  const [editing, setEditing] = useState<ArtifactSummary | null>(null)
  const [viewOnly, setViewOnly] = useState(false)
  const [artifactDraft, setArtifactDraft] =
    useState<ArtifactDraft>(emptyArtifact)
  const [translationArtifact, setTranslationArtifact] =
    useState<ArtifactSummary | null>(null)

  const sitesQuery = useQuery({
    queryKey: ["sites", "artifact-selector"],
    queryFn: () => sitesService.list(),
  })
  const languagesQuery = useQuery({
    queryKey: languageKeys.active(),
    queryFn: () => translationsService.languages(),
  })

  useEffect(() => {
    if (languageCode || !languagesQuery.data?.length) return
    const preferred = languagesQuery.data.find(
      (language) => language.is_default,
    )
    setLanguageCode(preferred?.code ?? languagesQuery.data[0].code)
  }, [languageCode, languagesQuery.data])

  const filters = useMemo(
    () => ({
      ...(siteFilter ? { site_id: siteFilter } : {}),
      ...(languageCode ? { lang: languageCode } : {}),
      ...(search.trim() ? { q: search.trim() } : {}),
      skip: 0,
      limit: 200,
      include_inactive: true,
    }),
    [languageCode, search, siteFilter],
  )
  const artifactsQuery = useQuery({
    queryKey: artifactKeys.list(filters),
    queryFn: () => artifactsService.list(filters),
  })
  const detailQuery = useQuery({
    queryKey: artifactKeys.detail(editing?.id ?? "", languageCode),
    queryFn: () => artifactsService.get(editing!.id, languageCode || undefined),
    enabled: artifactDialogOpen && editing !== null,
  })

  useEffect(() => {
    if (!detailQuery.data || !editing) return
    setArtifactDraft({
      code: detailQuery.data.code,
      site_id: detailQuery.data.site_id,
      era: detailQuery.data.era ?? "",
      latitude: detailQuery.data.latitude?.toString() ?? "",
      longitude: detailQuery.data.longitude?.toString() ?? "",
      cover_image_url: detailQuery.data.cover_image_url ?? "",
      is_active: detailQuery.data.is_active ?? true,
    })
  }, [detailQuery.data, editing])

  const saveArtifact = useMutation({
    mutationFn: () => {
      const payload = artifactPayload(artifactDraft)
      if (!payload.code) throw new Error("Artifact code is required.")
      if (!payload.site_id) throw new Error("Select a site.")
      if (
        payload.latitude !== null &&
        (payload.latitude < -90 || payload.latitude > 90)
      ) {
        throw new Error("Latitude must be between -90 and 90.")
      }
      if (
        payload.longitude !== null &&
        (payload.longitude < -180 || payload.longitude > 180)
      ) {
        throw new Error("Longitude must be between -180 and 180.")
      }
      return editing
        ? artifactsService.update(editing.id, payload satisfies ArtifactUpdate)
        : artifactsService.create(payload satisfies ArtifactCreate)
    },
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: artifactKeys.all })
      toast.success(editing ? "Artifact updated" : "Artifact created")
      closeArtifactDialog()
    },
    onError: (error) => toast.error(error.message || "Could not save artifact"),
  })

  const deactivateArtifact = useMutation({
    mutationFn: (artifact: ArtifactSummary) =>
      artifactsService.deactivate(artifact.id),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: artifactKeys.all })
      toast.success("Artifact deactivated")
    },
    onError: (error) =>
      toast.error(error.message || "Could not deactivate artifact"),
  })

  function closeArtifactDialog() {
    setArtifactDialogOpen(false)
    setEditing(null)
    setViewOnly(false)
    setArtifactDraft(emptyArtifact)
    saveArtifact.reset()
  }

  function openCreate() {
    setEditing(null)
    setViewOnly(false)
    setArtifactDraft({
      ...emptyArtifact,
      site_id: sitesQuery.data?.data.find((site) => site.is_active)?.id ?? "",
    })
    saveArtifact.reset()
    setArtifactDialogOpen(true)
  }

  function openEdit(artifact: ArtifactSummary) {
    setEditing(artifact)
    setViewOnly(false)
    setArtifactDraft(emptyArtifact)
    saveArtifact.reset()
    setArtifactDialogOpen(true)
  }

  function openDetails(artifact: ArtifactSummary) {
    setEditing(artifact)
    setViewOnly(true)
    setArtifactDraft(emptyArtifact)
    setArtifactDialogOpen(true)
  }

  const sites = sitesQuery.data?.data ?? []
  const artifacts = artifactsQuery.data?.data ?? []

  return (
    <div className="flex flex-col gap-4 md:gap-5">
      <section className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h2 className="text-xl font-semibold">Artifact Management</h2>
          <p className="text-sm text-muted-foreground">
            Manage artifact records and their language content.
          </p>
        </div>
        <Button
          onClick={openCreate}
          disabled={
            sitesQuery.isLoading || !sites.some((site) => site.is_active)
          }
        >
          <Plus /> Add artifact
        </Button>
      </section>

      <div className="flex flex-wrap gap-2">
        <div className="relative min-w-[210px] flex-1 sm:max-w-xs">
          <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            className="pl-9"
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder="Search artifact code"
            aria-label="Search artifact code"
          />
        </div>
        <select
          className="h-9 rounded-md border border-input bg-background px-3 text-sm"
          value={siteFilter}
          onChange={(event) => setSiteFilter(event.target.value)}
          aria-label="Filter by site"
        >
          <option value="">All sites</option>
          {sites
            .filter((site) => site.is_active)
            .map((site) => (
              <option key={site.id} value={site.id}>
                {site.name}
              </option>
            ))}
        </select>
        <select
          className="h-9 rounded-md border border-input bg-background px-3 text-sm"
          value={languageCode}
          onChange={(event) => setLanguageCode(event.target.value)}
          aria-label="Artifact title language"
          disabled={!languagesQuery.data?.length}
        >
          {languagesQuery.data?.map((language) => (
            <option key={language.id} value={language.code}>
              {language.name}
            </option>
          ))}
        </select>
      </div>

      {sitesQuery.isError && (
        <ErrorState
          title="Could not load sites"
          description={sitesQuery.error.message}
          onRetry={() => void sitesQuery.refetch()}
        />
      )}
      {languagesQuery.isError && (
        <ErrorState
          title="Could not load languages"
          description={languagesQuery.error.message}
          onRetry={() => void languagesQuery.refetch()}
        />
      )}

      <div className="overflow-x-auto rounded-xl border border-border/70 bg-card">
        {artifactsQuery.isLoading ? (
          <div className="space-y-3 p-5">
            {Array.from({ length: 5 }, (_, index) => (
              <Skeleton key={index} className="h-10 w-full" />
            ))}
          </div>
        ) : artifactsQuery.isError ? (
          <ErrorState
            description={artifactsQuery.error.message}
            onRetry={() => void artifactsQuery.refetch()}
          />
        ) : artifacts.length === 0 ? (
          <EmptyState
            title="No artifacts found"
            description="Create an artifact or adjust the selected site and search."
            icon={Archive}
            action={
              <Button
                onClick={openCreate}
                disabled={!sites.some((site) => site.is_active)}
              >
                <Plus /> Add artifact
              </Button>
            }
          />
        ) : (
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Code</TableHead>
                <TableHead>Title ({languageCode || "language"})</TableHead>
                <TableHead>Site</TableHead>
                <TableHead>Era</TableHead>
                <TableHead>Status</TableHead>
                <TableHead className="text-right">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {artifacts.map((artifact) => (
                <TableRow key={artifact.id}>
                  <TableCell className="font-medium">{artifact.code}</TableCell>
                  <TableCell>
                    {artifact.title || (
                      <span className="text-muted-foreground">
                        No translation
                      </span>
                    )}
                  </TableCell>
                  <TableCell>{siteName(artifact.site_id, sites)}</TableCell>
                  <TableCell>{artifact.era || "—"}</TableCell>
                  <TableCell>
                    <Badge
                      variant={artifact.is_active ? "default" : "secondary"}
                    >
                      {artifact.is_active ? "Active" : "Inactive"}
                    </Badge>
                  </TableCell>
                  <TableCell>
                    <div className="flex justify-end gap-1">
                      <Button
                        variant="ghost"
                        size="icon"
                        aria-label={`View ${artifact.code}`}
                        onClick={() => openDetails(artifact)}
                      >
                        <Eye />
                      </Button>
                      <Button
                        variant="ghost"
                        size="icon"
                        aria-label={`Edit ${artifact.code}`}
                        onClick={() => openEdit(artifact)}
                      >
                        <Pencil />
                      </Button>
                      <Button
                        variant="ghost"
                        size="icon"
                        aria-label={`Manage translations for ${artifact.code}`}
                        onClick={() => setTranslationArtifact(artifact)}
                      >
                        <Languages />
                      </Button>
                      {artifact.is_active && (
                        <Button
                          variant="ghost"
                          size="icon"
                          aria-label={`Deactivate ${artifact.code}`}
                          disabled={deactivateArtifact.isPending}
                          onClick={() => {
                            if (
                              window.confirm(
                                `Deactivate artifact ${artifact.code}? The backend will also unassign its linked beacon.`,
                              )
                            )
                              deactivateArtifact.mutate(artifact)
                          }}
                        >
                          <Trash2 className="text-destructive" />
                        </Button>
                      )}
                    </div>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        )}
      </div>

      <Dialog
        open={artifactDialogOpen}
        onOpenChange={(open) =>
          open ? setArtifactDialogOpen(true) : closeArtifactDialog()
        }
      >
        <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-2xl">
          <DialogHeader>
            <DialogTitle>
              {viewOnly
                ? `Artifact details · ${editing?.code}`
                : editing
                  ? `Edit ${editing.code}`
                  : "Add artifact"}
            </DialogTitle>
            <DialogDescription>
              Artifact identity and location fields. Language content is managed
              separately.
            </DialogDescription>
          </DialogHeader>
          {editing && detailQuery.isLoading ? (
            <div className="space-y-3">
              <Skeleton className="h-10 w-full" />
              <Skeleton className="h-10 w-full" />
            </div>
          ) : editing && detailQuery.isError ? (
            <ErrorState
              title="Could not load artifact"
              description={detailQuery.error.message}
              onRetry={() => void detailQuery.refetch()}
            />
          ) : (
            <div className="grid gap-4 sm:grid-cols-2">
              <label
                htmlFor="artifact-code"
                className="grid gap-1.5 text-sm font-medium"
              >
                Artifact code
                <Input
                  id="artifact-code"
                  required
                  maxLength={50}
                  value={artifactDraft.code}
                  onChange={(event) =>
                    setArtifactDraft({
                      ...artifactDraft,
                      code: event.target.value,
                    })
                  }
                  disabled={viewOnly}
                />
              </label>
              <label
                htmlFor="artifact-site"
                className="grid gap-1.5 text-sm font-medium"
              >
                Site
                <select
                  id="artifact-site"
                  className="h-9 rounded-md border border-input bg-background px-3"
                  value={artifactDraft.site_id}
                  onChange={(event) =>
                    setArtifactDraft({
                      ...artifactDraft,
                      site_id: event.target.value,
                    })
                  }
                  disabled={
                    viewOnly || sitesQuery.isLoading || sitesQuery.isError
                  }
                >
                  <option value="" disabled>
                    Select a site
                  </option>
                  {sites
                    .filter(
                      (site) =>
                        site.is_active || site.id === artifactDraft.site_id,
                    )
                    .map((site) => (
                      <option key={site.id} value={site.id}>
                        {site.name}
                        {site.is_active ? "" : " (inactive — current site)"}
                      </option>
                    ))}
                </select>
                {sitesQuery.isError && (
                  <span className="text-xs text-destructive">
                    {sitesQuery.error.message}
                  </span>
                )}
              </label>
              <label
                htmlFor="artifact-era"
                className="grid gap-1.5 text-sm font-medium"
              >
                Era
                <Input
                  id="artifact-era"
                  maxLength={100}
                  value={artifactDraft.era}
                  onChange={(event) =>
                    setArtifactDraft({
                      ...artifactDraft,
                      era: event.target.value,
                    })
                  }
                  disabled={viewOnly}
                />
              </label>
              <label
                htmlFor="artifact-cover"
                className="grid gap-1.5 text-sm font-medium"
              >
                Cover image URL
                <Input
                  id="artifact-cover"
                  maxLength={500}
                  type="url"
                  value={artifactDraft.cover_image_url}
                  onChange={(event) =>
                    setArtifactDraft({
                      ...artifactDraft,
                      cover_image_url: event.target.value,
                    })
                  }
                  disabled={viewOnly}
                />
              </label>
              <label
                htmlFor="artifact-latitude"
                className="grid gap-1.5 text-sm font-medium"
              >
                Latitude
                <Input
                  id="artifact-latitude"
                  type="number"
                  min={-90}
                  max={90}
                  step="any"
                  value={artifactDraft.latitude}
                  onChange={(event) =>
                    setArtifactDraft({
                      ...artifactDraft,
                      latitude: event.target.value,
                    })
                  }
                  disabled={viewOnly}
                />
              </label>
              <label
                htmlFor="artifact-longitude"
                className="grid gap-1.5 text-sm font-medium"
              >
                Longitude
                <Input
                  id="artifact-longitude"
                  type="number"
                  min={-180}
                  max={180}
                  step="any"
                  value={artifactDraft.longitude}
                  onChange={(event) =>
                    setArtifactDraft({
                      ...artifactDraft,
                      longitude: event.target.value,
                    })
                  }
                  disabled={viewOnly}
                />
              </label>
              <label className="flex items-center gap-2 text-sm sm:col-span-2">
                <input
                  type="checkbox"
                  checked={artifactDraft.is_active}
                  onChange={(event) =>
                    setArtifactDraft({
                      ...artifactDraft,
                      is_active: event.target.checked,
                    })
                  }
                  disabled={viewOnly}
                />{" "}
                Active
              </label>
              {saveArtifact.isError && (
                <p
                  role="alert"
                  className="text-sm text-destructive sm:col-span-2"
                >
                  {saveArtifact.error.message}
                </p>
              )}
            </div>
          )}
          {/* Media Management */}
          {editing && detailQuery.data && (
            <>
              <div className="my-5 border-t" />

              <ArtifactMediaManager artifactId={editing.id} />
            </>
          )}
          <DialogFooter>
            <Button variant="outline" onClick={closeArtifactDialog}>
              {viewOnly ? "Close" : "Cancel"}
            </Button>
            {!viewOnly && (
              <Button
                onClick={() => saveArtifact.mutate()}
                disabled={
                  saveArtifact.isPending ||
                  sitesQuery.isLoading ||
                  sitesQuery.isError ||
                  (editing !== null && !detailQuery.data)
                }
              >
                {saveArtifact.isPending ? "Saving…" : "Save artifact"}
              </Button>
            )}
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {translationArtifact && (
        <TranslationDialog
          artifact={translationArtifact}
          languages={languagesQuery.data ?? []}
          languagesLoading={languagesQuery.isLoading}
          languagesError={languagesQuery.error}
          onClose={() => setTranslationArtifact(null)}
        />
      )}
    </div>
  )
}

function TranslationDialog({
  artifact,
  languages,
  languagesLoading,
  languagesError,
  onClose,
}: {
  artifact: ArtifactSummary
  languages: LanguagePublic[]
  languagesLoading: boolean
  languagesError: Error | null
  onClose: () => void
}) {
  const queryClient = useQueryClient()
  const [languageId, setLanguageId] = useState("")
  const [drafts, setDrafts] = useState<Record<string, TranslationDraft>>({})
  const translationsQuery = useQuery({
    queryKey: translationKeys.byArtifact(artifact.id),
    queryFn: () => translationsService.list(artifact.id),
  })

  useEffect(() => {
    if (languageId || !languages.length) return
    setLanguageId(
      languages.find((language) => language.is_default)?.id ?? languages[0].id,
    )
  }, [languageId, languages])

  const savedTranslation = translationsQuery.data?.find(
    (item) => item.language_id === languageId,
  )
  const currentDraft = drafts[languageId] ?? {
    title: savedTranslation?.title ?? "",
    description: savedTranslation?.description ?? "",
    history_content: savedTranslation?.history_content ?? "",
  }
  const saveTranslation = useMutation({
    mutationFn: () => {
      if (!languageId) throw new Error("Select a language.")
      if (!currentDraft.title.trim())
        throw new Error("Translation title is required.")
      return translationsService.upsert(artifact.id, languageId, {
        title: currentDraft.title.trim(),
        description: currentDraft.description.trim() || null,
        history_content: currentDraft.history_content.trim() || null,
      })
    },
    onSuccess: async () => {
      await Promise.all([
        queryClient.invalidateQueries({
          queryKey: translationKeys.byArtifact(artifact.id),
        }),
        queryClient.invalidateQueries({ queryKey: artifactKeys.all }),
      ])
      setDrafts((current) => {
        const next = { ...current }
        delete next[languageId]
        return next
      })
      toast.success("Translation saved")
    },
    onError: (error) =>
      toast.error(error.message || "Could not save translation"),
  })
  const deleteTranslation = useMutation({
    mutationFn: () => translationsService.remove(artifact.id, languageId),
    onSuccess: async () => {
      await Promise.all([
        queryClient.invalidateQueries({
          queryKey: translationKeys.byArtifact(artifact.id),
        }),
        queryClient.invalidateQueries({ queryKey: artifactKeys.all }),
      ])
      setDrafts((current) => {
        const next = { ...current }
        delete next[languageId]
        return next
      })
      toast.success("Translation deleted")
    },
    onError: (error) =>
      toast.error(error.message || "Could not delete translation"),
  })

  function setField(field: keyof TranslationDraft, value: string) {
    setDrafts((current) => ({
      ...current,
      [languageId]: { ...currentDraft, [field]: value },
    }))
  }

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-2xl">
        <DialogHeader>
          <DialogTitle>Translations · {artifact.code}</DialogTitle>
          <DialogDescription>
            Each language is stored as a translation for this artifact. Nothing
            is created until you save.
          </DialogDescription>
        </DialogHeader>
        {languagesLoading ? (
          <Skeleton className="h-10 w-full" />
        ) : languagesError ? (
          <ErrorState
            title="Could not load languages"
            description={languagesError.message}
          />
        ) : languages.length === 0 ? (
          <EmptyState
            title="No active languages"
            description="Add an active language before creating translations."
            icon={Languages}
          />
        ) : (
          <>
            <div className="flex flex-wrap gap-2">
              {languages.map((language) => (
                <Button
                  key={language.id}
                  size="sm"
                  variant={language.id === languageId ? "default" : "outline"}
                  onClick={() => setLanguageId(language.id)}
                >
                  {language.name}
                </Button>
              ))}
            </div>
            {translationsQuery.isLoading ? (
              <div className="space-y-3">
                <Skeleton className="h-10 w-full" />
                <Skeleton className="h-24 w-full" />
              </div>
            ) : translationsQuery.isError ? (
              <ErrorState
                title="Could not load translations"
                description={translationsQuery.error.message}
                onRetry={() => void translationsQuery.refetch()}
              />
            ) : (
              <>
                <p className="text-sm text-muted-foreground">
                  {savedTranslation
                    ? "Translation exists; saving updates it."
                    : "No translation for this language yet."}
                </p>
                <label
                  htmlFor="translation-title"
                  className="grid gap-1.5 text-sm font-medium"
                >
                  Title
                  <Input
                    id="translation-title"
                    required
                    maxLength={255}
                    value={currentDraft.title}
                    onChange={(event) => setField("title", event.target.value)}
                  />
                </label>
                <label
                  htmlFor="translation-description"
                  className="grid gap-1.5 text-sm font-medium"
                >
                  Description
                  <textarea
                    id="translation-description"
                    maxLength={2000}
                    rows={3}
                    value={currentDraft.description}
                    onChange={(event) =>
                      setField("description", event.target.value)
                    }
                    className="resize-y rounded-md border border-input bg-background px-3 py-2 text-sm font-normal outline-none focus-visible:ring-2 focus-visible:ring-ring"
                  />
                </label>
                <label
                  htmlFor="translation-history"
                  className="grid gap-1.5 text-sm font-medium"
                >
                  History content
                  <textarea
                    id="translation-history"
                    rows={6}
                    value={currentDraft.history_content}
                    onChange={(event) =>
                      setField("history_content", event.target.value)
                    }
                    className="resize-y rounded-md border border-input bg-background px-3 py-2 text-sm font-normal outline-none focus-visible:ring-2 focus-visible:ring-ring"
                  />
                </label>
                {(saveTranslation.isError || deleteTranslation.isError) && (
                  <p role="alert" className="text-sm text-destructive">
                    {saveTranslation.error?.message ??
                      deleteTranslation.error?.message}
                  </p>
                )}
              </>
            )}
          </>
        )}
        <DialogFooter>
          {savedTranslation && (
            <Button
              variant="destructive"
              disabled={
                deleteTranslation.isPending || translationsQuery.isLoading
              }
              onClick={() => {
                if (
                  window.confirm(
                    `Delete the ${languages.find((language) => language.id === languageId)?.name ?? "selected language"} translation?`,
                  )
                )
                  deleteTranslation.mutate()
              }}
            >
              {deleteTranslation.isPending ? "Deleting…" : "Delete translation"}
            </Button>
          )}
          <Button variant="outline" onClick={onClose}>
            Close
          </Button>
          {languages.length > 0 && !translationsQuery.isError && (
            <Button
              onClick={() => saveTranslation.mutate()}
              disabled={
                saveTranslation.isPending ||
                translationsQuery.isLoading ||
                !currentDraft.title.trim()
              }
            >
              {saveTranslation.isPending ? "Saving…" : "Save translation"}
            </Button>
          )}
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
