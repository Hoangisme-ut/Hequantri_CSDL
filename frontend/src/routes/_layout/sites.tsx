import { createFileRoute, Outlet, useRouterState } from "@tanstack/react-router"
import { Filter, MapPin, Plus, Search } from "lucide-react"

import { EmptyState } from "@/components/Common/AdminPrimitives"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Table, TableBody, TableHead, TableHeader, TableRow } from "@/components/ui/table"

export const Route = createFileRoute("/_layout/sites")({
  component: SiteManagement,
  head: () => ({ meta: [{ title: "Site Management - Smart Heritage" }] }),
})

function SiteManagement() {
  const pathname = useRouterState({ select: (state) => state.location.pathname })
  if (pathname !== "/sites") return <Outlet />

  return (
    <div className="flex flex-col gap-4 md:gap-5">
      <div className="flex flex-wrap items-center gap-2">
        <div className="relative min-w-[210px] flex-1 sm:max-w-xs">
          <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
          <Input className="pl-9" placeholder="Search sites..." aria-label="Search sites" disabled />
        </div>
        <Button variant="outline" disabled><Filter /> Lifecycle: All</Button>
        <Button variant="outline" disabled><Filter /> Health: All</Button>
        <Button disabled><Plus /> Add Site</Button>
      </div>

      <Card className="gap-0 overflow-hidden border-border/70 bg-card shadow-sm">
        <CardHeader className="flex flex-row items-center justify-between gap-3 border-b border-border/70 px-5 py-3">
          <CardTitle className="flex items-center gap-2 text-sm"><MapPin className="size-4 text-primary" />Site Inventory</CardTitle>
          <Badge variant="secondary">API pending</Badge>
        </CardHeader>
        <CardContent className="p-0">
          <div className="overflow-x-auto">
            <Table>
              <TableHeader><TableRow><TableHead>Site name</TableHead><TableHead>Location</TableHead><TableHead>Artifacts</TableHead><TableHead>Beacons</TableHead><TableHead>Lifecycle</TableHead><TableHead>Health</TableHead><TableHead className="text-right">Actions</TableHead></TableRow></TableHeader>
              <TableBody />
            </Table>
          </div>
          <EmptyState title="No site records available" description="The current backend does not expose a sites API. This inventory will populate after a site data source is confirmed." icon={MapPin} />
        </CardContent>
      </Card>

    </div>
  )
}
