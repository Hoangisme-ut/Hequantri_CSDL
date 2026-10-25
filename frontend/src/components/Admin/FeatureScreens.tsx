import {
  Archive,
  Bell,
  CalendarDays,
  ChartNoAxesColumnIncreasing,
  CircleAlert,
  FileText,
  Filter,
  Link2Off,
  MessageSquare,
  Radio,
  Search,
  UsersRound,
} from "lucide-react"
import { useState } from "react"

import { ApiPendingCard, EmptyState, MetricCard } from "@/components/Common/AdminPrimitives"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Table, TableBody, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { demoBeacons } from "@/services/beacons.mock"

function ScreenCard({
  title,
  icon: Icon,
  badge,
  children,
}: {
  title: string
  icon: typeof Archive
  badge?: string
  children: React.ReactNode
}) {
  return (
    <Card className="gap-0 overflow-hidden border-border/70 bg-card shadow-sm">
      <CardHeader className="flex flex-row items-center justify-between gap-3 border-b border-border/70 px-4 py-3 md:px-5">
        <CardTitle className="flex items-center gap-2 text-sm"><Icon className="size-4 text-primary" />{title}</CardTitle>
        {badge && <Badge variant="secondary">{badge}</Badge>}
      </CardHeader>
      <CardContent className="p-0">{children}</CardContent>
    </Card>
  )
}

function DisabledFilter({ label }: { label: string }) {
  return <Button variant="outline" disabled><Filter />{label}</Button>
}

export function BeaconManagementScreen() {
  const [search, setSearch] = useState("")
  const [filter, setFilter] = useState("All")
  const beacons = demoBeacons.filter((beacon) => {
    const matchesFilter = filter === "All" || (filter === "Active" ? beacon.active : filter === "Inactive" ? !beacon.active : !beacon.artifact)
    const term = search.trim().toLocaleLowerCase()
    return matchesFilter && (!term || `${beacon.proximityUuid} ${beacon.major} ${beacon.minor} ${beacon.site} ${beacon.artifact ?? ""}`.toLocaleLowerCase().includes(term))
  })
  return (
    <div className="flex flex-col gap-4 md:gap-5">
      <div className="flex flex-wrap items-center gap-2">
        <div className="relative min-w-[210px] flex-1 sm:max-w-xs"><Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" /><Input className="pl-9" placeholder="Search UUID, site or artifact…" aria-label="Search beacons" value={search} onChange={(event) => setSearch(event.target.value)} /></div>
        <Badge variant="outline">Demo data</Badge>
      </div>
      <section className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <MetricCard label="Total beacons" value={demoBeacons.length} detail="Sample inventory" icon={Radio} />
        <MetricCard label="Active" value={demoBeacons.filter((item) => item.active).length} detail="Configured as active" icon={Radio} />
        <MetricCard label="Inactive" value={demoBeacons.filter((item) => !item.active).length} detail="Configured as inactive" icon={CircleAlert} />
        <MetricCard label="Unassigned" value={demoBeacons.filter((item) => !item.artifact).length} detail="No artifact linked" icon={Link2Off} />
      </section>
      <div>
        <ScreenCard title="Beacon Inventory" icon={Radio} badge="Sample data">
          <div className="flex flex-wrap gap-2 border-b border-border/70 p-3">{["All", "Active", "Inactive", "Unassigned"].map((option) => <Button key={option} variant={filter === option ? "default" : "outline"} size="sm" onClick={() => setFilter(option)}>{option}</Button>)}</div>
          <div className="overflow-x-auto">
            <Table>
              <TableHeader><TableRow><TableHead>Proximity UUID</TableHead><TableHead>Major / Minor</TableHead><TableHead>Site</TableHead><TableHead>Artifact</TableHead><TableHead>Battery</TableHead><TableHead>Last seen</TableHead><TableHead>Status</TableHead></TableRow></TableHeader>
              <TableBody>{beacons.map((beacon) => <tr key={beacon.id} className="border-b border-border/60 last:border-0"><td className="max-w-[230px] truncate px-4 py-3 font-mono text-xs">{beacon.proximityUuid}</td><td className="px-4 py-3 text-sm">{beacon.major} / {beacon.minor}</td><td className="px-4 py-3 text-sm">{beacon.site}</td><td className="px-4 py-3 text-sm">{beacon.artifact ?? <span className="text-muted-foreground">Unassigned</span>}</td><td className="px-4 py-3 text-sm">{beacon.battery == null ? "Unknown" : `${beacon.battery}%`}</td><td className="px-4 py-3 text-sm text-muted-foreground">{beacon.lastSeen ?? "Never"}</td><td className="px-4 py-3"><Badge variant={beacon.active ? "default" : "secondary"}>{beacon.active ? "Active" : "Inactive"}</Badge></td></tr>)}</TableBody>
            </Table>
          </div>
          {beacons.length === 0 && <EmptyState title="No matching beacons" description="Adjust your search or status filter." icon={Radio} />}
        </ScreenCard>
        <p className="mt-3 text-xs text-muted-foreground">This inventory uses sample data for interface review. Beacon changes are not sent to the API.</p>
      </div>
    </div>
  )
}

export function AnalyticsScreen() {
  return (
    <div className="flex flex-col gap-4 md:gap-5">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div className="flex flex-wrap items-center gap-2">
          <Button variant="outline" disabled><CalendarDays /> Date range unavailable</Button>
          <DisabledFilter label="All sites" />
          <Button disabled>Apply</Button>
          <Button variant="outline" disabled>Reset</Button>
        </div>
        <div className="flex gap-2"><Button variant="outline" disabled>Export PDF</Button><Button variant="outline" disabled>Export Excel</Button></div>
      </div>
      <section className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <MetricCard label="Total visits" value="—" detail="Waiting for analytics API" icon={UsersRound} />
        <MetricCard label="Artifact views" value="—" detail="Waiting for analytics API" icon={Archive} />
        <MetricCard label="Interactions" value="—" detail="Waiting for analytics API" icon={ChartNoAxesColumnIncreasing} />
        <MetricCard label="Content views" value="—" detail="Waiting for analytics API" icon={FileText} />
      </section>
      <div className="grid gap-4 xl:grid-cols-[1.35fr_0.85fr]">
        <ScreenCard title="Daily visits" icon={ChartNoAxesColumnIncreasing} badge="No data source">
          <EmptyState title="Analytics are not available" description="No visits, daily values or reporting period can be loaded from the current API." icon={ChartNoAxesColumnIncreasing} />
        </ScreenCard>
        <ApiPendingCard title="Content views by category" description="Category totals require confirmed analytics events and content categories." />
      </div>
      <div className="grid gap-4 xl:grid-cols-[1.5fr_0.7fr]">
        <ScreenCard title="Performance by Site" icon={CalendarDays} badge="API pending">
          <div className="overflow-x-auto"><Table><TableHeader><TableRow><TableHead>Site name</TableHead><TableHead>Visits</TableHead><TableHead>Content views</TableHead><TableHead>Interactions</TableHead><TableHead>Artifact views</TableHead><TableHead>Visit share</TableHead></TableRow></TableHeader><TableBody /></Table></div>
          <EmptyState title="No site analytics available" description="Site-level metrics will appear when an analytics API is available." icon={CalendarDays} />
        </ScreenCard>
        <ApiPendingCard title="Inventory Summary" description="Verified site, artifact and beacon totals are not available for reporting." />
      </div>
    </div>
  )
}

export function FeedbackScreen() {
  return (
    <div className="flex flex-col gap-4 md:gap-5">
      <div className="flex flex-wrap items-center gap-2">
        <div className="relative min-w-[210px] flex-1 sm:max-w-xs"><Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" /><Input className="pl-9" placeholder="Search feedback..." aria-label="Search feedback" disabled /></div>
        <DisabledFilter label="All sites" />
        <div className="flex flex-wrap gap-1 sm:ml-auto">{["All", "Pending", "Approved", "Rejected"].map((label) => <Button key={label} variant="outline" size="sm" disabled>{label}</Button>)}</div>
      </div>
      <div className="flex flex-wrap items-center gap-2 text-sm"><Badge variant="secondary">— Pending</Badge><Badge variant="secondary">— Approved</Badge><Badge variant="secondary">— Rejected</Badge><span className="text-muted-foreground">No submission data connected</span></div>
      <div className="grid items-start gap-4 xl:grid-cols-[1.05fr_0.95fr]">
        <ScreenCard title="Visitor Feedback" icon={MessageSquare} badge="API pending">
          <div className="overflow-x-auto"><Table><TableHeader><TableRow><TableHead>ID</TableHead><TableHead>Visitor</TableHead><TableHead>Artifact / Site</TableHead><TableHead>Status</TableHead><TableHead>Date</TableHead></TableRow></TableHeader><TableBody /></Table></div>
          <EmptyState title="No feedback submissions" description="Submissions will appear here after a feedback data source is confirmed." icon={MessageSquare} />
        </ScreenCard>
        <div className="flex flex-col gap-4">
          <ScreenCard title="Submission Detail" icon={FileText} badge="No selection"><EmptyState title="Select a submission" description="Choose a feedback record to review its details and moderation options." icon={FileText} /></ScreenCard>
          <Card className="gap-0 border-border/70 bg-card shadow-sm"><CardHeader className="border-b border-border/70 px-5 py-3"><CardTitle className="text-sm">Moderation actions</CardTitle></CardHeader><CardContent className="flex flex-wrap gap-2 p-4"><Input className="min-w-[180px] flex-1" placeholder="Rejection reason" disabled /><Button disabled>Approve</Button><Button variant="destructive" disabled>Reject</Button></CardContent></Card>
          <p className="text-xs text-muted-foreground">Moderation actions are disabled until a feedback API is confirmed.</p>
        </div>
      </div>
    </div>
  )
}

export function VisitorsScreen() {
  return (
    <div className="flex flex-col gap-4 md:gap-5">
      <div className="flex flex-wrap items-center gap-2">
        <div className="relative min-w-[210px] flex-1 sm:max-w-xs"><Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" /><Input className="pl-9" placeholder="Search visitors..." aria-label="Search visitors" disabled /></div>
        <DisabledFilter label="All sites" />
        <Badge variant="secondary">API pending</Badge>
      </div>
      <Card className="border-border/70 bg-card shadow-sm"><CardContent className="flex items-start gap-3 p-4"><CircleAlert className="mt-0.5 size-4 shrink-0 text-primary" /><div><p className="text-sm font-semibold">Visitor records are not available</p><p className="mt-1 text-xs text-muted-foreground">The current API does not expose visitor profiles, individual visits or interaction history.</p></div></CardContent></Card>
      <div className="grid items-start gap-4 xl:grid-cols-[1.1fr_0.9fr]">
        <div className="flex flex-col gap-4">
          <ScreenCard title="Visitor Directory" icon={UsersRound} badge="No records">
            <div className="overflow-x-auto"><Table><TableHeader><TableRow><TableHead>Visitor</TableHead><TableHead>Feedback site</TableHead><TableHead>Submission</TableHead><TableHead>Date</TableHead></TableRow></TableHeader><TableBody /></Table></div>
            <EmptyState title="No visitor records" description="Visitor data will appear when an approved visitor data source is connected." icon={UsersRound} />
          </ScreenCard>
          <ApiPendingCard title="Privacy & data context" description="Contact details and individual visit history require a defined data source and privacy scope." />
        </div>
        <div className="flex flex-col gap-4"><ScreenCard title="Visitor details" icon={UsersRound} badge="No selection"><EmptyState title="Select a visitor" description="Visitor details are shown after a record is available." icon={UsersRound} /></ScreenCard><ApiPendingCard title="Visit history & interactions" description="Visit timelines and content interactions are not available from the current API." /></div>
      </div>
    </div>
  )
}

export function NotificationsScreen() {
  const [filter, setFilter] = useState("All")
  return (
    <div className="flex flex-col gap-4 md:gap-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex gap-2">{["All", "Unread", "Read"].map((option) => <Button key={option} variant={filter === option ? "default" : "outline"} size="sm" onClick={() => setFilter(option)}>{option}</Button>)}</div>
        <Button variant="outline" disabled title="There are no notifications to update"><Bell /> Mark all as read</Button>
      </div>
      <div className="grid items-start gap-4 xl:grid-cols-[1.4fr_0.7fr]">
        <ScreenCard title="Activity Inbox" icon={Bell} badge="0 unread">
          <EmptyState title={filter === "All" ? "No notifications available" : `No ${filter.toLocaleLowerCase()} notifications`} description="System alerts and read state are not available from the current API." icon={Bell} />
          <div className="border-t border-border/70 px-5 py-3 text-xs text-muted-foreground">Notification delivery and personal read state are waiting for an API.</div>
        </ScreenCard>
        <div className="flex flex-col gap-4">
          <ApiPendingCard title="At a glance" description="Connectivity, moderation and publication summaries are not available." />
          <Card className="gap-0 border-border/70 bg-card shadow-sm"><CardHeader className="border-b border-border/70 px-5 py-3"><CardTitle className="text-sm">Delivery preferences</CardTitle></CardHeader><CardContent className="p-5"><p className="text-sm text-muted-foreground">Choose which alerts and digests you receive in Account preferences.</p><Button className="mt-4" variant="outline" disabled>Manage preferences</Button></CardContent></Card>
        </div>
      </div>
    </div>
  )
}
