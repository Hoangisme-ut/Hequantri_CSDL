import { Archive, BarChart3, Bell, MapPin, MessageSquare, Radio, Shield, UsersRound } from "lucide-react"

import { MetricCard } from "@/components/Common/AdminPrimitives"
import { Badge } from "@/components/ui/badge"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"

export type PreviewScreenName = "sites" | "edit-site" | "artifacts" | "beacons" | "analytics" | "feedback" | "visitors" | "notifications" | "account" | "settings" | "team"

const sites = [
  ["Yorkshire Museum", "York, North Yorkshire", "2", "BCN-001, BCN-002", "Active"],
  ["St Mary's Abbey", "York, North Yorkshire", "2", "BCN-003, BCN-004", "Active"],
  ["Clifford's Tower", "York, North Yorkshire", "2", "BCN-005, BCN-006", "Active"],
]
const artifacts = [
  ["ART-001", "Roman oil lamp", "Yorkshire Museum", "Published", "BCN-001"],
  ["ART-002", "Viking brooch", "Yorkshire Museum", "Published", "BCN-002"],
  ["ART-003", "Stone capital", "St Mary's Abbey", "Published", "BCN-003"],
  ["ART-004", "Abbey floor tile", "St Mary's Abbey", "Published", "BCN-004"],
  ["ART-005", "Silver penny", "Clifford's Tower", "Draft", "BCN-005"],
]
const beacons = [
  ["BCN-001", "Yorkshire Museum", "ART-001 · Roman oil lamp", "Assigned", "Online"],
  ["BCN-002", "Yorkshire Museum", "ART-002 · Viking brooch", "Assigned", "Online"],
  ["BCN-003", "St Mary's Abbey", "ART-003 · Stone capital", "Assigned", "Online"],
  ["BCN-004", "St Mary's Abbey", "ART-004 · Abbey floor tile", "Assigned", "Offline"],
  ["BCN-007", "— No site —", "Unassigned", "Unassigned", "Unknown"],
]
const feedback = [
  ["FB-026", "Mila Patel", "ART-001 · Yorkshire Museum", "Pending", "15 Sep 2026"],
  ["FB-025", "James Wright", "ART-003 · St Mary's Abbey", "Pending", "14 Sep 2026"],
  ["FB-023", "Oliver Chen", "ART-002 · Yorkshire Museum", "Approved", "11 Sep 2026"],
]
const visitors = [
  ["Mila Patel", "Yorkshire Museum", "FB-026", "15 Sep 2026"],
  ["James Wright", "St Mary's Abbey", "FB-025", "14 Sep 2026"],
  ["Emma Wilson", "Clifford's Tower", "FB-024", "13 Sep 2026"],
]
const staff = [
  ["Alex Morgan · DEMO", "Administrator", "All 3 sites", "Active"],
  ["Priya Shah · DEMO", "Editor", "Yorkshire Museum", "Active"],
  ["Ben Carter · DEMO", "Viewer", "St Mary's Abbey", "Active"],
  ["Nora Ellis · DEMO", "Editor", "Clifford's Tower", "Invited"],
]

const catalog: Record<PreviewScreenName, { title: string; subtitle: string; headers: string[]; rows: string[][] }> = {
  sites: { title: "Site Inventory", subtitle: "Three heritage sites · demo records", headers: ["Site name", "Location", "Artifacts", "Beacons", "Lifecycle"], rows: sites },
  artifacts: { title: "Artifacts", subtitle: "Artifact catalog · demo records", headers: ["ID", "Artifact name", "Site", "Status", "Beacon"], rows: artifacts },
  beacons: { title: "Beacon Inventory", subtitle: "Connectivity and assignments · demo records", headers: ["Beacon ID", "Site", "Artifact", "Assignment", "Connectivity"], rows: beacons },
  feedback: { title: "Visitor Feedback", subtitle: "Moderation queue · demo records", headers: ["ID", "Visitor", "Artifact / Site", "Status", "Date"], rows: feedback },
  visitors: { title: "Visitor Directory", subtitle: "Sample visitor records · demo only", headers: ["Visitor", "Feedback site", "Submission", "Date"], rows: visitors },
  team: { title: "Staff Directory", subtitle: "Example team configuration · demo only", headers: ["Name", "Role", "Site scope", "Status"], rows: staff },
  "edit-site": { title: "Edit Site · Yorkshire Museum", subtitle: "Site details · demo values", headers: ["Field", "Value"], rows: [["Site ID", "YM-001"], ["Address", "Museum Gardens, York"], ["County / region", "North Yorkshire"], ["Country", "United Kingdom"], ["Lifecycle", "Active"], ["Description", "A museum in the heart of York with Roman, Viking and medieval collections."]] },
  analytics: { title: "Analytics & Reports", subtitle: "September 2026 · demo metrics", headers: ["Site name", "Visits", "Content views", "Interactions", "Visit share"], rows: [["Yorkshire Museum", "6,240", "8,232", "2,160", "50%"], ["St Mary's Abbey", "3,820", "5,660", "1,340", "31%"], ["Clifford's Tower", "2,420", "4,748", "820", "19%"]] },
  notifications: { title: "Activity Inbox", subtitle: "System alerts · demo only", headers: ["Alert", "Context", "Date", "State"], rows: [["Beacon BCN-004 offline", "St Mary's Abbey · ART-004", "15 Sep 2026", "Unread"], ["3 feedback submissions pending", "FB-026, FB-025, FB-024", "15 Sep 2026", "Unread"], ["2 artifacts in draft", "ART-005 and ART-006", "10 Sep 2026", "Unread"]] },
  account: { title: "Account", subtitle: "Profile and preferences · demo only", headers: ["Preference", "Value"], rows: [["Name", "Alex Morgan"], ["Email", "alex.morgan@example.org · DEMO"], ["Role", "Administrator"], ["Site access", "All 3 sites · DEMO"], ["Language", "English (United Kingdom)"], ["Time zone", "Europe/London"]] },
  settings: { title: "Settings", subtitle: "Organisation preferences · demo only", headers: ["Category", "Preview values"], rows: [["General", "Smart Heritage · Europe/London"], ["Languages", "English · French · German"], ["Reports", "Monthly · All sites"], ["Notifications", "Beacon alerts · Feedback moderation"], ["Security", "Two-step verification policy"]] },
}

function Panel({ title, children }: { title: string; children: React.ReactNode }) {
  return <Card className="gap-0 overflow-hidden border-border/70 bg-card shadow-sm"><CardHeader className="flex flex-row items-center justify-between border-b border-border/70 px-4 py-3 md:px-5"><CardTitle className="text-sm">{title}</CardTitle><Badge variant="secondary">DEMO</Badge></CardHeader><CardContent className="p-4 md:p-5">{children}</CardContent></Card>
}

function DemoTable({ headers, rows }: { headers: string[]; rows: string[][] }) {
  return <div className="overflow-x-auto"><Table><TableHeader><TableRow>{headers.map((header) => <TableHead key={header}>{header}</TableHead>)}</TableRow></TableHeader><TableBody>{rows.map((row) => <TableRow key={row[0]}>{row.map((cell, index) => <TableCell key={`${row[0]}-${index}`} className={index === 0 ? "font-medium" : "text-muted-foreground"}>{cell}</TableCell>)}</TableRow>)}</TableBody></Table></div>
}

export function PreviewScreen({ screen = "overview" }: { screen?: string }) {
  if (screen === "overview") return <Overview />
  const content = catalog[screen as PreviewScreenName]
  if (!content) return <Panel title="Screen not found"><p className="text-sm text-muted-foreground">Choose a screen from the Preview sidebar.</p></Panel>

  return <div className="flex flex-col gap-4 md:gap-5">
    <div className="flex flex-wrap items-center justify-between gap-3"><div><h2 className="text-xl font-semibold">{content.title}</h2><p className="text-sm text-muted-foreground">{content.subtitle}</p></div><Badge className="bg-amber-500 text-slate-950 hover:bg-amber-500">DEMO DATA</Badge></div>
    {screen === "artifacts" && <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4"><MetricCard label="Total" value="6" detail="Illustrative artifacts" icon={Archive} /><MetricCard label="Published" value="4" detail="Demo state" icon={Archive} /><MetricCard label="Draft" value="2" detail="Demo state" icon={Archive} /><MetricCard label="Sites" value="3" detail="Demo network" icon={MapPin} /></div>}
    {screen === "beacons" && <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4"><MetricCard label="Total beacons" value="8" detail="Demo inventory" icon={Radio} /><MetricCard label="Online" value="5" detail="Illustrative status" icon={Radio} /><MetricCard label="Offline" value="1" detail="BCN-004 · DEMO" icon={Radio} /><MetricCard label="Unassigned" value="2" detail="Demo assignments" icon={Radio} /></div>}
    {screen === "analytics" && <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4"><MetricCard label="Total visits" value="12,480" detail="Demo · Sep 2026" icon={UsersRound} /><MetricCard label="Artifact views" value="13,240" detail="Demo · Sep 2026" icon={Archive} /><MetricCard label="Interactions" value="4,320" detail="Demo · Sep 2026" icon={BarChart3} /><MetricCard label="Content views" value="18,640" detail="Demo · Sep 2026" icon={MessageSquare} /></div>}
    <Panel title={content.title}><DemoTable headers={content.headers} rows={content.rows} /></Panel>
    {screen === "edit-site" && <Panel title="Site image"><div className="flex h-36 items-center justify-center rounded-lg border border-dashed border-border text-sm text-muted-foreground">Image preview unavailable in this demo</div></Panel>}
    {screen === "feedback" && <Panel title="Submission detail"><p className="text-sm text-muted-foreground">Select a demo submission to review the illustrated visitor context. Moderation is disabled in Preview.</p></Panel>}
    {screen === "visitors" && <Panel title="Privacy & data context"><p className="text-sm text-muted-foreground">These illustrative records are not real visitor identities or visit totals.</p></Panel>}
    {screen === "notifications" && <Panel title="At a glance"><div className="flex items-center gap-3 text-sm text-muted-foreground"><Bell className="size-4 text-primary" />Connectivity and moderation summaries use demo data only.</div></Panel>}
    {screen === "team" && <Panel title="Role permission matrix"><div className="flex items-center gap-3 text-sm text-muted-foreground"><Shield className="size-4 text-primary" />Permissions and example staff are illustrative and do not represent account records.</div></Panel>}
    {screen === "account" && <Panel title="Password & security"><p className="text-sm text-muted-foreground">Security changes are disabled in Preview. No account API is called.</p></Panel>}
    {screen === "settings" && <Panel title="Configuration status"><p className="text-sm text-muted-foreground">Preference values are illustrative; saving is disabled in Preview.</p></Panel>}
  </div>
}

function Overview() {
  return <div className="flex flex-col gap-4 md:gap-5">
    <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4"><MetricCard label="Active sites" value="3" detail="All active · DEMO" icon={MapPin} /><MetricCard label="Artifacts" value="6" detail="4 published · 2 draft · DEMO" icon={Archive} /><MetricCard label="Beacons" value="8" detail="5 online · 1 offline · DEMO" icon={Radio} /><MetricCard label="Feedback" value="6" detail="3 pending · DEMO" icon={MessageSquare} /></div>
    <div className="grid gap-4 xl:grid-cols-[1.25fr_0.75fr]"><Panel title="Site Overview"><DemoTable headers={["Site name", "Artifacts", "Beacons", "Lifecycle"]} rows={sites.map(([name,,, beacon, state]) => [name, "2", beacon, state])} /></Panel><Panel title="Beacon Status"><DemoTable headers={["Beacon", "Site", "Status"]} rows={beacons.slice(0, 4).map(([id, site,,, state]) => [id, site, state])} /></Panel></div>
    <div className="grid gap-4 xl:grid-cols-3"><Panel title="Analytics Snapshot"><div className="space-y-3 text-sm">{[["Total visits", "12,480"], ["Artifact views", "13,240"], ["Interactions", "4,320"]].map(([label, value]) => <div className="flex justify-between" key={label}><span className="text-muted-foreground">{label} · DEMO</span><strong>{value}</strong></div>)}</div></Panel><Panel title="Recent Alerts"><p className="text-sm">BCN-004 offline · St Mary's Abbey</p><p className="mt-2 text-xs text-muted-foreground">Illustrative alert · DEMO</p></Panel><Panel title="Feedback Review"><p className="text-sm">3 pending submissions · DEMO</p><p className="mt-2 text-xs text-muted-foreground">Demo summary only</p></Panel></div>
  </div>
}
