import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { createFileRoute, Link } from "@tanstack/react-router"
import { ArrowLeft, MapPin, Save } from "lucide-react"
import { useEffect, useState } from "react"
import { toast } from "sonner"
import { ErrorState } from "@/components/Common/AdminPrimitives"
import { CoverImageField } from "@/components/Sites/CoverImageField"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Skeleton } from "@/components/ui/skeleton"
import { validateSiteInput } from "@/services/site-validation"
import { type SiteInput, sitesService } from "@/services/sites"

export const Route = createFileRoute("/_layout/sites/$siteId")({
  component: EditSite,
  head: () => ({ meta: [{ title: "Site Details - Smart Heritage" }] }),
})

function EditSite() {
  const { siteId } = Route.useParams()
  const queryClient = useQueryClient()
  const query = useQuery({
    queryKey: ["sites", siteId],
    queryFn: () => sitesService.get(siteId),
  })
  const [draft, setDraft] = useState<SiteInput | null>(null)
  const [errors, setErrors] = useState<string[]>([])
  useEffect(() => {
    if (query.data)
      setDraft({
        name: query.data.name,
        address: query.data.address ?? "",
        description: query.data.description ?? "",
        latitude: query.data.latitude,
        longitude: query.data.longitude,
        cover_image_url: query.data.cover_image_url ?? "",
        is_active: query.data.is_active,
      })
  }, [query.data])
  const mutation = useMutation({
    mutationFn: () => {
      if (!draft) throw new Error("Site details are not ready to save.")
      return sitesService.update(siteId, {
        ...draft,
        name: draft.name.trim(),
        cover_image_url: draft.cover_image_url?.trim() || null,
      })
    },
    onSuccess: async (site) => {
      await queryClient.invalidateQueries({ queryKey: ["sites"] })
      queryClient.setQueryData(["sites", siteId], site)
      toast.success("Site updated")
    },
    onError: (error) =>
      toast.error(error.message || "Could not save this site"),
  })
  if (query.isLoading)
    return (
      <div className="space-y-4">
        <Skeleton className="h-12 w-64" />
        <Skeleton className="h-96 w-full" />
      </div>
    )
  if (query.isError)
    return (
      <ErrorState
        title="Could not load this site"
        description={query.error.message}
        onRetry={() => void query.refetch()}
      />
    )
  if (!draft || !query.data) return null
  const update = (key: keyof SiteInput, value: SiteInput[keyof SiteInput]) =>
    setDraft((current) => (current ? { ...current, [key]: value } : current))
  const save = () => {
    const validationErrors = validateSiteInput(draft)
    setErrors(validationErrors)
    if (validationErrors.length === 0) mutation.mutate()
  }

  return (
    <div className="mx-auto flex max-w-3xl flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <span className="flex size-10 items-center justify-center rounded-lg bg-primary/15 text-primary">
            <MapPin className="size-5" />
          </span>
          <div>
            <h2 className="font-semibold">{query.data.name}</h2>
            <p className="text-xs text-muted-foreground">Site details</p>
          </div>
        </div>
        <Badge variant={draft.is_active ? "default" : "secondary"}>
          {draft.is_active ? "Active" : "Inactive"}
        </Badge>
      </div>
      <Card className="gap-0 border-border/70 bg-card shadow-sm">
        <CardHeader className="border-b border-border/70 px-5 py-3">
          <CardTitle className="text-sm">Site information</CardTitle>
        </CardHeader>
        <CardContent className="grid gap-4 p-5">
          <label
            htmlFor="site-name"
            className="grid gap-1.5 text-sm font-medium"
          >
            Site name{" "}
            <Input
              id="site-name"
              required
              maxLength={255}
              value={draft.name}
              onChange={(event) => update("name", event.target.value)}
            />
          </label>
          <label
            htmlFor="site-address"
            className="grid gap-1.5 text-sm font-medium"
          >
            Address{" "}
            <Input
              id="site-address"
              maxLength={500}
              value={draft.address ?? ""}
              onChange={(event) => update("address", event.target.value)}
            />
          </label>
          <label
            htmlFor="site-description"
            className="grid gap-1.5 text-sm font-medium"
          >
            Description{" "}
            <textarea
              id="site-description"
              maxLength={2000}
              rows={4}
              value={draft.description ?? ""}
              onChange={(event) => update("description", event.target.value)}
              className="resize-y rounded-md border border-input bg-background px-3 py-2 text-sm font-normal outline-none focus-visible:ring-2 focus-visible:ring-ring"
            />
          </label>
          <div className="grid gap-4 sm:grid-cols-2">
            <label
              htmlFor="site-latitude"
              className="grid gap-1.5 text-sm font-medium"
            >
              Latitude{" "}
              <Input
                id="site-latitude"
                type="number"
                min="-90"
                max="90"
                step="any"
                value={draft.latitude ?? ""}
                onChange={(event) =>
                  update(
                    "latitude",
                    event.target.value === ""
                      ? null
                      : Number(event.target.value),
                  )
                }
              />
            </label>
            <label
              htmlFor="site-longitude"
              className="grid gap-1.5 text-sm font-medium"
            >
              Longitude{" "}
              <Input
                id="site-longitude"
                type="number"
                min="-180"
                max="180"
                step="any"
                value={draft.longitude ?? ""}
                onChange={(event) =>
                  update(
                    "longitude",
                    event.target.value === ""
                      ? null
                      : Number(event.target.value),
                  )
                }
              />
            </label>
          </div>
          <CoverImageField
            value={draft.cover_image_url ?? ""}
            onChange={(value) => update("cover_image_url", value || null)}
          />
          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={draft.is_active}
              onChange={(event) => update("is_active", event.target.checked)}
            />{" "}
            Active site
          </label>
          {mutation.isError && (
            <p role="alert" className="text-sm text-destructive">
              {mutation.error.message}
            </p>
          )}
          {errors.length > 0 && (
            <ul className="list-inside list-disc text-sm text-destructive">
              {errors.map((error) => (
                <li key={error}>{error}</li>
              ))}
            </ul>
          )}
          <div className="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
            <Button variant="outline" asChild>
              <Link to="/sites">
                <ArrowLeft /> Back to sites
              </Link>
            </Button>
            <Button disabled={mutation.isPending} onClick={save}>
              <Save /> {mutation.isPending ? "Saving…" : "Save changes"}
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
