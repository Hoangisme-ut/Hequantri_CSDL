import { createFileRoute } from "@tanstack/react-router"
import { Bell, FileBarChart, Languages, LockKeyhole, Settings2 } from "lucide-react"
import { useState } from "react"

import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Checkbox } from "@/components/ui/checkbox"
import { Input } from "@/components/ui/input"

export const Route = createFileRoute("/_layout/settings")({
  component: SettingsPage,
  head: () => ({ meta: [{ title: "Settings - Smart Heritage" }] }),
})

type Draft = {
  organisation: string
  timezone: string
  dateFormat: string
  language: string
  defaultPeriod: string
  digestFrequency: string
  emailDigest: boolean
  beaconAlerts: boolean
  feedbackAlerts: boolean
  contentReminders: boolean
  requireTwoStep: boolean
  minPassword: boolean
  complexPassword: boolean
  useFallbackLanguage: boolean
  illustrativeData: boolean
  pdfSummary: boolean
  excelWorkbook: boolean
}

const initialDraft: Draft = {
  organisation: "",
  timezone: "",
  dateFormat: "",
  language: "",
  defaultPeriod: "",
  digestFrequency: "",
  emailDigest: false,
  beaconAlerts: false,
  feedbackAlerts: false,
  contentReminders: false,
  requireTwoStep: false,
  minPassword: false,
  complexPassword: false,
  useFallbackLanguage: false,
  illustrativeData: false,
  pdfSummary: false,
  excelWorkbook: false,
}

function DraftToggle({ label, description, checked, onCheckedChange }: { label: string; description?: string; checked: boolean; onCheckedChange: (checked: boolean) => void }) {
  return (
    <label className="flex items-start gap-3 text-sm">
      <Checkbox checked={checked} onCheckedChange={(value) => onCheckedChange(value === true)} className="mt-0.5" />
      <span><span className="block font-medium">{label}</span>{description && <span className="text-xs text-muted-foreground">{description}</span>}</span>
    </label>
  )
}

function SettingsPage() {
  const [draft, setDraft] = useState(initialDraft)
  const [availableLanguages, setAvailableLanguages] = useState<string[]>([])
  const update = <K extends keyof Draft>(key: K, value: Draft[K]) => setDraft((current) => ({ ...current, [key]: value }))
  const setLanguageAvailable = (language: string, enabled: boolean) => setAvailableLanguages((current) => enabled ? [...new Set([...current, language])] : current.filter((item) => item !== language))

  return (
    <div className="flex flex-col gap-4 md:gap-5">
      <Card className="border-border/70 bg-card shadow-sm"><CardContent className="flex flex-wrap items-center justify-between gap-3 p-4"><p className="text-sm text-muted-foreground">Organisation preferences are a local UI draft. No settings API is available to load or save these values.</p><Badge variant="secondary">API pending</Badge></CardContent></Card>
      <div className="grid items-start gap-4 xl:grid-cols-2">
        <div className="flex flex-col gap-4">
          <Card className="gap-0 border-border/70 bg-card shadow-sm"><CardHeader className="border-b border-border/70 px-5 py-3"><CardTitle className="flex items-center gap-2 text-sm"><Settings2 className="size-4 text-primary" />General</CardTitle></CardHeader><CardContent className="grid gap-4 p-5">
            <label className="grid gap-1.5 text-sm font-medium">Organisation name<Input value={draft.organisation} onChange={(event) => update("organisation", event.target.value)} /></label>
            <div className="grid gap-4 sm:grid-cols-2"><label className="grid gap-1.5 text-sm font-medium">Time zone<select className="h-9 rounded-md border border-input bg-background/25 px-3 text-sm font-normal" value={draft.timezone} onChange={(event) => update("timezone", event.target.value)}><option value="">Choose time zone</option><option value="utc">UTC</option><option value="local">Device time zone</option></select></label><label className="grid gap-1.5 text-sm font-medium">Default date format<select className="h-9 rounded-md border border-input bg-background/25 px-3 text-sm font-normal" value={draft.dateFormat} onChange={(event) => update("dateFormat", event.target.value)}><option value="">Choose date format</option><option>DD MMM YYYY</option><option>MMM DD, YYYY</option><option>YYYY-MM-DD</option></select></label></div>
            <p className="text-xs text-muted-foreground">Network and site scope are not provided by the current APIs.</p>
          </CardContent></Card>

          <Card className="gap-0 border-border/70 bg-card shadow-sm"><CardHeader className="border-b border-border/70 px-5 py-3"><CardTitle className="flex items-center gap-2 text-sm"><Languages className="size-4 text-primary" />Languages</CardTitle></CardHeader><CardContent className="grid gap-4 p-5">
            <label className="grid gap-1.5 text-sm font-medium">Default content language<select className="h-9 rounded-md border border-input bg-background/25 px-3 text-sm font-normal" value={draft.language} onChange={(event) => update("language", event.target.value)}><option value="">Choose language</option><option value="en">English</option><option value="fr">French</option><option value="de">German</option></select></label>
            <div className="flex flex-wrap gap-5"><DraftToggle label="English" checked={availableLanguages.includes("en")} onCheckedChange={(checked) => setLanguageAvailable("en", checked)} /><DraftToggle label="French" checked={availableLanguages.includes("fr")} onCheckedChange={(checked) => setLanguageAvailable("fr", checked)} /><DraftToggle label="German" checked={availableLanguages.includes("de")} onCheckedChange={(checked) => setLanguageAvailable("de", checked)} /></div>
            <DraftToggle label="Use English when translation is incomplete" checked={draft.useFallbackLanguage} onCheckedChange={(value) => update("useFallbackLanguage", value)} />
            <p className="text-xs text-muted-foreground">Translation availability is not returned by the current APIs.</p>
          </CardContent></Card>

          <Card className="gap-0 border-border/70 bg-card shadow-sm"><CardHeader className="border-b border-border/70 px-5 py-3"><CardTitle className="flex items-center gap-2 text-sm"><FileBarChart className="size-4 text-primary" />Report preferences</CardTitle></CardHeader><CardContent className="grid gap-4 p-5">
            <div className="grid gap-4 sm:grid-cols-2"><label className="grid gap-1.5 text-sm font-medium">Default reporting period<select className="h-9 rounded-md border border-input bg-background/25 px-3 text-sm font-normal" value={draft.defaultPeriod} onChange={(event) => update("defaultPeriod", event.target.value)}><option value="">Choose period</option><option>Weekly</option><option>Monthly</option><option>Quarterly</option></select></label><label className="grid gap-1.5 text-sm font-medium">Default site scope<select className="h-9 rounded-md border border-input bg-background/25 px-3 text-sm font-normal" disabled value=""><option value="">Unavailable</option></select></label></div>
            <div className="grid gap-3 sm:grid-cols-2"><DraftToggle label="PDF summary" checked={draft.pdfSummary} onCheckedChange={(value) => update("pdfSummary", value)} /><DraftToggle label="Excel workbook" checked={draft.excelWorkbook} onCheckedChange={(value) => update("excelWorkbook", value)} /></div>
            <DraftToggle label="Include illustrative data" description="Unverified daily and per-artifact values should be excluded." checked={draft.illustrativeData} onCheckedChange={(value) => update("illustrativeData", value)} />
          </CardContent></Card>
        </div>

        <div className="flex flex-col gap-4">
          <Card className="gap-0 border-border/70 bg-card shadow-sm"><CardHeader className="border-b border-border/70 px-5 py-3"><CardTitle className="flex items-center gap-2 text-sm"><Bell className="size-4 text-primary" />Notifications</CardTitle></CardHeader><CardContent className="grid gap-4 p-5">
            <DraftToggle label="Beacon connectivity alerts" description="In-console alerts for offline devices." checked={draft.beaconAlerts} onCheckedChange={(value) => update("beaconAlerts", value)} />
            <DraftToggle label="Feedback awaiting moderation" description="Summary of pending submissions." checked={draft.feedbackAlerts} onCheckedChange={(value) => update("feedbackAlerts", value)} />
            <DraftToggle label="Incomplete content reminders" checked={draft.contentReminders} onCheckedChange={(value) => update("contentReminders", value)} />
            <DraftToggle label="Email digest" checked={draft.emailDigest} onCheckedChange={(value) => update("emailDigest", value)} />
            <label className="grid gap-1.5 text-sm font-medium">Digest frequency<select className="h-9 rounded-md border border-input bg-background/25 px-3 text-sm font-normal" value={draft.digestFrequency} onChange={(event) => update("digestFrequency", event.target.value)}><option value="">Choose frequency</option><option>Weekly</option><option>Monthly</option></select></label>
          </CardContent></Card>

          <Card className="gap-0 border-border/70 bg-card shadow-sm"><CardHeader className="flex flex-row items-center justify-between border-b border-border/70 px-5 py-3"><CardTitle className="flex items-center gap-2 text-sm"><LockKeyhole className="size-4 text-primary" />Security</CardTitle><Badge variant="secondary">API pending</Badge></CardHeader><CardContent className="grid gap-4 p-5">
            <DraftToggle label="Require two-step verification for staff" checked={draft.requireTwoStep} onCheckedChange={(value) => update("requireTwoStep", value)} />
            <div className="grid gap-4 sm:grid-cols-2"><label className="grid gap-1.5 text-sm font-medium">Idle session timeout<select className="h-9 rounded-md border border-input bg-background/25 px-3 text-sm font-normal" disabled value=""><option value="">Unavailable</option></select></label><label className="grid gap-1.5 text-sm font-medium">Invitation expiry<select className="h-9 rounded-md border border-input bg-background/25 px-3 text-sm font-normal" disabled value=""><option value="">Unavailable</option></select></label></div>
            <DraftToggle label="Require at least 12 password characters" checked={draft.minPassword} onCheckedChange={(value) => update("minPassword", value)} />
            <DraftToggle label="Require uppercase, lowercase and a number" checked={draft.complexPassword} onCheckedChange={(value) => update("complexPassword", value)} />
            <p className="text-xs text-muted-foreground">These policy controls are visual drafts only; the current API does not provide organisation security policies.</p>
          </CardContent></Card>

          <div className="flex flex-wrap justify-end gap-2"><Button variant="outline" onClick={() => { setDraft(initialDraft); setAvailableLanguages([]) }}>Discard local changes</Button><Button disabled title="Settings are not connected to an API">Save settings</Button></div>
        </div>
      </div>
    </div>
  )
}
