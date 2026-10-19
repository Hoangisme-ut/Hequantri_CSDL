import { useQuery } from "@tanstack/react-query"
import { createFileRoute } from "@tanstack/react-router"
import { Archive, MapPin, MessageSquare, Radio } from "lucide-react"

import { ItemsService } from "@/client"
import { ApiPendingCard, ErrorState, MetricCard } from "@/components/Common/AdminPrimitives"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Skeleton } from "@/components/ui/skeleton"
import useAuth from "@/hooks/useAuth"

export const Route = createFileRoute("/_layout/")({
  component: Dashboard,
  head: () => ({ meta: [{ title: "Overview - Smart Heritage" }] }),
})

function Dashboard() {
  const { user } = useAuth()
  const artifactsQuery = useQuery({
    queryKey: ["items"],
    queryFn: async () => (await ItemsService.readItems({ query: { skip: 0, limit: 100 } })).data,
  })
  const artifactCount = artifactsQuery.data?.data.length

  return (
    <div className="flex flex-col gap-4 md:gap-5">
      <div className="flex flex-wrap items-end justify-between gap-2">
        <p className="text-sm text-muted-foreground">
          Welcome back{user?.full_name ? `, ${user.full_name}` : ""}. Here's your administration overview.
        </p>
        <span className="text-xs text-muted-foreground">Live values are shown only where an API is available.</span>
      </div>

      <section className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4" aria-label="Overview metrics">
        {artifactsQuery.isLoading ? (
          <Skeleton className="h-28 rounded-xl" />
        ) : (
          <MetricCard label="Artifacts" value={artifactsQuery.isError ? "—" : artifactCount ?? 0} detail={artifactsQuery.isError ? "Unable to load records" : "Current API records"} icon={Archive} />
        )}
        <MetricCard label="Active sites" value="—" detail="Waiting for sites API" icon={MapPin} />
        <MetricCard label="Beacons" value="—" detail="Waiting for beacon API" icon={Radio} />
        <MetricCard label="Feedback" value="—" detail="Waiting for feedback API" icon={MessageSquare} />
      </section>

      <section className="grid gap-4 xl:grid-cols-[1.25fr_0.75fr]">
        <ApiPendingCard title="Site Overview" description="Site inventory and lifecycle details will appear here when the project has a confirmed sites API." />
        {artifactsQuery.isError ? (
          <Card className="gap-0 border-border/70 bg-card shadow-sm">
            <CardHeader className="border-b border-border/70 px-5 py-3"><CardTitle className="text-sm">Artifact records</CardTitle></CardHeader>
            <CardContent className="p-0"><ErrorState description="The existing Items API could not be reached." onRetry={() => void artifactsQuery.refetch()} /></CardContent>
          </Card>
        ) : (
          <ApiPendingCard title="Beacon status" description="Connectivity and assignment status need a confirmed beacon data source." />
        )}
      </section>

      <section className="grid gap-4 xl:grid-cols-3">
        <ApiPendingCard title="Analytics snapshot" description="Visit and content metrics are not available from the current API." />
        <ApiPendingCard title="Recent alerts" description="System alerts will appear when a notification source is connected." />
        <ApiPendingCard title="Feedback review" description="Moderation totals and submissions need a confirmed feedback API." />
      </section>
    </div>
  )
}
