import { createFileRoute, Link as RouterLink } from "@tanstack/react-router"
import { ArrowLeft, Building2, Image, Save } from "lucide-react"
import { useState } from "react"

import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"

export const Route = createFileRoute("/_layout/sites/$siteId")({
  component: EditSite,
  head: () => ({ meta: [{ title: "Edit Site - Smart Heritage" }] }),
})

type SiteDraft = {
  name: string
  address: string
  city: string
  region: string
  postcode: string
  country: string
  latitude: string
  longitude: string
  description: string
  type: string
  openingHours: string
}

const blankDraft: SiteDraft = {
  name: "",
  address: "",
  city: "",
  region: "",
  postcode: "",
  country: "",
  latitude: "",
  longitude: "",
  description: "",
  type: "",
  openingHours: "",
}

function SiteField({
  label,
  name,
  value,
  onChange,
  placeholder = "",
}: {
  label: string
  name: keyof SiteDraft
  value: string
  onChange: (name: keyof SiteDraft, value: string) => void
  placeholder?: string
}) {
  return (
    <label className="grid gap-1.5 text-xs font-medium">
      {label}
      <Input value={value} placeholder={placeholder} onChange={(event) => onChange(name, event.target.value)} />
    </label>
  )
}

function EditSite() {
  const { siteId } = Route.useParams()
  const [draft, setDraft] = useState(blankDraft)
  const update = (key: keyof SiteDraft, value: string) => setDraft((current) => ({ ...current, [key]: value }))

  return (
    <div className="flex flex-col gap-4 md:gap-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <span className="flex size-10 items-center justify-center rounded-lg bg-primary/15 text-primary"><Building2 className="size-5" /></span>
          <div><h2 className="font-semibold">Site record</h2><p className="text-xs text-muted-foreground">Reference: {siteId}</p></div>
        </div>
        <Badge variant="secondary">API pending</Badge>
      </div>

      <div className="grid items-start gap-4 xl:grid-cols-[1.35fr_0.85fr]">
        <div className="flex flex-col gap-4">
          <Card className="gap-0 border-border/70 bg-card shadow-sm">
            <CardHeader className="border-b border-border/70 px-5 py-3"><CardTitle className="text-sm">Basic Information</CardTitle></CardHeader>
            <CardContent className="grid gap-4 p-5">
              <SiteField label="Site name" name="name" value={draft.name} onChange={update} />
              <div className="grid gap-4 sm:grid-cols-2"><SiteField label="Address line" name="address" value={draft.address} onChange={update} /><SiteField label="City" name="city" value={draft.city} onChange={update} /></div>
              <div className="grid gap-4 sm:grid-cols-2"><SiteField label="County / region" name="region" value={draft.region} onChange={update} /><SiteField label="Postcode" name="postcode" value={draft.postcode} onChange={update} /></div>
              <SiteField label="Country" name="country" value={draft.country} onChange={update} />
              <div className="grid gap-4 sm:grid-cols-2"><SiteField label="Latitude" name="latitude" value={draft.latitude} onChange={update} placeholder="Optional" /><SiteField label="Longitude" name="longitude" value={draft.longitude} onChange={update} placeholder="Optional" /></div>
              <label className="grid gap-1.5 text-xs font-medium">Description<textarea value={draft.description} onChange={(event) => update("description", event.target.value)} rows={4} className="resize-y rounded-md border border-input bg-background/30 px-3 py-2 text-sm font-normal outline-none focus-visible:ring-2 focus-visible:ring-ring" /></label>
              <div className="grid gap-4 sm:grid-cols-2"><SiteField label="Site type" name="type" value={draft.type} onChange={update} /><SiteField label="Opening hours" name="openingHours" value={draft.openingHours} onChange={update} /></div>
            </CardContent>
          </Card>
          <Card className="gap-0 border-border/70 bg-card shadow-sm">
            <CardHeader className="border-b border-border/70 px-5 py-3"><CardTitle className="text-sm">Artifacts at this site</CardTitle></CardHeader>
            <CardContent className="flex min-h-24 items-center justify-center p-5 text-sm text-muted-foreground">Site-to-artifact relationships are not available from the current API.</CardContent>
          </Card>
        </div>

        <div className="flex flex-col gap-4">
          <Card className="gap-0 border-border/70 bg-card shadow-sm">
            <CardHeader className="border-b border-border/70 px-5 py-3"><CardTitle className="flex items-center gap-2 text-sm"><Image className="size-4 text-primary" />Site Image</CardTitle></CardHeader>
            <CardContent className="p-5">
              <div className="flex min-h-40 flex-col items-center justify-center gap-2 rounded-lg border border-dashed border-border bg-background/20 text-center text-sm text-muted-foreground"><Image className="size-7" /><span>No site image available</span></div>
              <p className="mt-2 text-xs text-muted-foreground">Image upload is not connected.</p>
            </CardContent>
          </Card>
          <Card className="gap-0 border-border/70 bg-card shadow-sm">
            <CardHeader className="border-b border-border/70 px-5 py-3"><CardTitle className="text-sm">Site lifecycle</CardTitle></CardHeader>
            <CardContent className="p-5 text-sm text-muted-foreground">Lifecycle data is not available until the sites API is confirmed.</CardContent>
          </Card>
          <div className="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
            <Button variant="outline" asChild><RouterLink to="/sites"><ArrowLeft /> Back to sites</RouterLink></Button>
            <Button disabled title="Waiting for the sites API"><Save /> Save changes</Button>
          </div>
          <p className="text-right text-xs text-muted-foreground">Fields are an unsaved UI preview. Changes are not persisted.</p>
          <Button variant="ghost" className="self-end" onClick={() => setDraft(blankDraft)}>Discard local edits</Button>
        </div>
      </div>
    </div>
  )
}
