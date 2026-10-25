import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import {
  createFileRoute,
  Link,
  Outlet,
  useRouterState,
} from "@tanstack/react-router"
import { MapPin, Pencil, Plus, Search, Trash2 } from "lucide-react"
import { useEffect, useMemo, useState } from "react"
import { toast } from "sonner"
import { EmptyState, ErrorState } from "@/components/Common/AdminPrimitives"
import { CoverImageField } from "@/components/Sites/CoverImageField"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
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
import { filterSites, validateSiteInput } from "@/services/site-validation"
import { type Site, type SiteInput, sitesService } from "@/services/sites"

export const Route = createFileRoute("/_layout/sites")({
  component: SiteManagement,
  head: () => ({ meta: [{ title: "Site Management - Smart Heritage" }] }),
})

const emptySite: SiteInput = {
  name: "",
  address: "",
  description: "",
  latitude: null,
  longitude: null,
  cover_image_url: null,
  is_active: true,
}
const siteKey = ["sites"]

function SiteDialog({
  site,
  open,
  onOpenChange,
}: {
  site: Site | null
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const queryClient = useQueryClient()
  const [draft, setDraft] = useState<SiteInput>(emptySite)
  const [errors, setErrors] = useState<string[]>([])
  const mutation = useMutation({
    mutationFn: () => {
      const input = {
        ...draft,
        name: draft.name.trim(),
        cover_image_url: draft.cover_image_url?.trim() || null,
      }
      return site
        ? sitesService.update(site.id, input)
        : sitesService.create(input)
    },
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: siteKey })
      toast.success(site ? "Site updated" : "Site added")
      onOpenChange(false)
    },
    onError: (error) =>
      toast.error(error.message || "Could not save this site"),
  })

  useEffect(() => {
    if (!open) return
    setDraft(
      site
        ? {
            name: site.name,
            address: site.address ?? "",
            description: site.description ?? "",
            latitude: site.latitude,
            longitude: site.longitude,
            cover_image_url: site.cover_image_url ?? "",
            is_active: site.is_active,
          }
        : emptySite,
    )
    setErrors([])
  }, [open, site])
  const handleOpenChange = (next: boolean) => onOpenChange(next)
  const setField = (
    key: keyof SiteInput,
    value: string | number | boolean | null,
  ) => setDraft((current) => ({ ...current, [key]: value }))
  const validate = () => {
    const issues = validateSiteInput(draft)
    setErrors(issues)
    return issues.length === 0
  }
  const submit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    if (validate()) mutation.mutate()
  }

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogContent className="max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>
            {site ? "Edit site" : "Add a heritage site"}
          </DialogTitle>
          <DialogDescription>
            Enter the details used to identify this heritage location.
          </DialogDescription>
        </DialogHeader>
        <form onSubmit={submit} className="grid gap-4">
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
              onChange={(event) => setField("name", event.target.value)}
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
              onChange={(event) => setField("address", event.target.value)}
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
              rows={3}
              value={draft.description ?? ""}
              onChange={(event) => setField("description", event.target.value)}
              className="resize-y rounded-md border border-input bg-background px-3 py-2 text-sm font-normal outline-none focus-visible:ring-2 focus-visible:ring-ring"
            />
          </label>
          <div className="grid grid-cols-2 gap-3">
            <label
              htmlFor="site-latitude"
              className="grid gap-1.5 text-sm font-medium"
            >
              Latitude{" "}
              <Input
                id="site-latitude"
                type="number"
                step="any"
                min="-90"
                max="90"
                value={draft.latitude ?? ""}
                onChange={(event) =>
                  setField(
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
                step="any"
                min="-180"
                max="180"
                value={draft.longitude ?? ""}
                onChange={(event) =>
                  setField(
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
            onChange={(value) => setField("cover_image_url", value || null)}
          />
          {site && (
            <label className="flex items-center gap-2 text-sm">
              <input
                type="checkbox"
                checked={draft.is_active}
                onChange={(event) =>
                  setField("is_active", event.target.checked)
                }
              />{" "}
              Active site
            </label>
          )}
          {errors.length > 0 && (
            <ul className="list-inside list-disc text-sm text-destructive">
              {errors.map((error) => (
                <li key={error}>{error}</li>
              ))}
            </ul>
          )}
          {mutation.isError && (
            <p role="alert" className="text-sm text-destructive">
              {mutation.error.message}
            </p>
          )}
          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => handleOpenChange(false)}
            >
              Cancel
            </Button>
            <Button type="submit" disabled={mutation.isPending}>
              {mutation.isPending
                ? "Saving…"
                : site
                  ? "Save changes"
                  : "Add site"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

function SiteManagement() {
  const pathname = useRouterState({
    select: (state) => state.location.pathname,
  })
  const queryClient = useQueryClient()
  const [search, setSearch] = useState("")
  const [editing, setEditing] = useState<Site | null>(null)
  const [dialogOpen, setDialogOpen] = useState(false)
  const sitesQuery = useQuery({ queryKey: siteKey, queryFn: sitesService.list })
  const deactivateMutation = useMutation({
    mutationFn: sitesService.deactivate,
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: siteKey })
      toast.success("Site deactivated")
    },
    onError: (error) =>
      toast.error(error.message || "Could not deactivate this site"),
  })
  const sites = sitesQuery.data?.data ?? []
  const filteredSites = useMemo(() => {
    return filterSites(sites, search)
  }, [sites, search])
  if (pathname !== "/sites") return <Outlet />

  const editSite = (site: Site) => {
    setEditing(site)
    setDialogOpen(true)
  }
  const addSite = () => {
    setEditing(null)
    setDialogOpen(true)
  }
  const removeSite = (site: Site) => {
    if (
      window.confirm(
        `Deactivate “${site.name}”? It will no longer appear in the public site list.`,
      )
    )
      deactivateMutation.mutate(site.id)
  }

  return (
    <div className="flex flex-col gap-4 md:gap-5">
      <Card className="gap-0 overflow-hidden border-border/70 bg-card shadow-sm">
        <CardHeader className="flex flex-col gap-3 border-b border-border/70 px-4 py-3 sm:flex-row sm:items-center sm:justify-between md:px-5">
          <CardTitle className="flex items-center gap-2 text-sm">
            <MapPin className="size-4 text-primary" />
            Heritage sites{" "}
            <Badge variant="secondary">
              {sitesQuery.isSuccess ? sites.length : "—"}
            </Badge>
            <Badge variant="outline">Live data</Badge>
          </CardTitle>
          <div className="flex flex-wrap items-center gap-2">
            <div className="relative min-w-[190px] flex-1 sm:max-w-xs">
              <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
              <Input
                className="pl-9"
                placeholder="Search name or address…"
                aria-label="Search sites"
                value={search}
                onChange={(event) => setSearch(event.target.value)}
              />
            </div>
            <Button onClick={addSite}>
              <Plus /> Add site
            </Button>
          </div>
        </CardHeader>
        <CardContent className="p-0">
          {sitesQuery.isLoading ? (
            <div className="space-y-3 p-5">
              {Array.from({ length: 4 }, (_, index) => (
                <Skeleton key={index} className="h-10 w-full" />
              ))}
            </div>
          ) : sitesQuery.isError ? (
            <ErrorState
              description={
                sitesQuery.error.message || "The Site data could not be loaded."
              }
              onRetry={() => void sitesQuery.refetch()}
            />
          ) : sites.length === 0 ? (
            <EmptyState
              title="No heritage sites yet"
              description="Add your first site to start organizing artifacts and beacons."
              icon={MapPin}
              action={
                <Button onClick={addSite}>
                  <Plus /> Add site
                </Button>
              }
            />
          ) : filteredSites.length === 0 ? (
            <EmptyState
              title="No matching sites"
              description="Try a different site name or address."
              icon={Search}
            />
          ) : (
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Site</TableHead>
                    <TableHead>Address</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead>Coordinates</TableHead>
                    <TableHead className="text-right">Actions</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filteredSites.map((site) => (
                    <TableRow key={site.id}>
                      <TableCell className="min-w-[180px]">
                        <Link
                          to="/sites/$siteId"
                          params={{ siteId: site.id }}
                          className="font-medium hover:text-primary"
                        >
                          {site.name}
                        </Link>
                        <p className="mt-0.5 max-w-[300px] truncate text-xs text-muted-foreground">
                          {site.description || "No description"}
                        </p>
                      </TableCell>
                      <TableCell className="min-w-[180px] text-muted-foreground">
                        {site.address || "—"}
                      </TableCell>
                      <TableCell>
                        <Badge
                          variant={site.is_active ? "default" : "secondary"}
                        >
                          {site.is_active ? "Active" : "Inactive"}
                        </Badge>
                      </TableCell>
                      <TableCell className="whitespace-nowrap text-xs text-muted-foreground">
                        {site.latitude != null && site.longitude != null
                          ? `${site.latitude}, ${site.longitude}`
                          : "—"}
                      </TableCell>
                      <TableCell>
                        <div className="flex justify-end gap-1">
                          <Button
                            variant="ghost"
                            size="icon"
                            aria-label={`Edit ${site.name}`}
                            onClick={() => editSite(site)}
                          >
                            <Pencil />
                          </Button>
                          <Button
                            variant="ghost"
                            size="icon"
                            aria-label={`Deactivate ${site.name}`}
                            onClick={() => removeSite(site)}
                          >
                            <Trash2 className="text-destructive" />
                          </Button>
                        </div>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          )}
        </CardContent>
      </Card>
      <p className="text-xs text-muted-foreground">
        Site changes are saved to the backend. Deactivation preserves the record
        and hides it from the public site list.
      </p>
      <SiteDialog
        key={editing?.id ?? "new"}
        site={editing}
        open={dialogOpen}
        onOpenChange={setDialogOpen}
      />
    </div>
  )
}
