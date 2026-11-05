import { useQuery } from "@tanstack/react-query"
import { createFileRoute } from "@tanstack/react-router"
import { Archive, MapPin, MessageSquare, Radio } from "lucide-react"

import {
  ApiPendingCard,
  EmptyState,
  ErrorState,
  MetricCard,
} from "@/components/Common/AdminPrimitives"
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import { Skeleton } from "@/components/ui/skeleton"
import useAuth from "@/hooks/useAuth"
import { artifactsService } from "@/services/artifacts"
import { beaconsService } from "@/services/beacon"
import { sitesService } from "@/services/sites"

export const Route = createFileRoute("/_layout/")({
  component: Dashboard,
  head: () => ({
    meta: [{ title: "Overview - Smart Heritage" }],
  }),
})

const PAGE_SIZE = 200

type StatusRecord = {
  is_active?: boolean | null
}

type StatusStats = {
  total: number
  active: number
  inactive: number
}

type PageResponse<T> = {
  data: T[]
  count: number
}

async function fetchAllPages<T>(
  fetchPage: (skip: number, limit: number) => Promise<PageResponse<T>>,
): Promise<PageResponse<T>> {
  const firstPage = await fetchPage(0, PAGE_SIZE)

  if (firstPage.data.length > firstPage.count) {
    throw new Error("Invalid API pagination response.")
  }

  const records = [...firstPage.data]
  const total = firstPage.count

  for (let skip = PAGE_SIZE; skip < total; skip += PAGE_SIZE) {
    const page = await fetchPage(skip, PAGE_SIZE)

    if (page.count !== total) {
      throw new Error(
        "Records changed while loading statistics. Please retry.",
      )
    }

    if (page.data.length === 0) {
      throw new Error("An API page returned no records unexpectedly.")
    }

    records.push(...page.data)
  }

  if (records.length !== total) {
    throw new Error(
      "The statistics are incomplete. Please retry.",
    )
  }

  return { data: records, count: total }
}

function calculateStats<T extends StatusRecord>(
  response: PageResponse<T>,
): StatusStats {
  const active = response.data.filter(
    (record) => record.is_active === true,
  ).length

  const inactive = response.data.filter(
    (record) => record.is_active === false,
  ).length

  if (active + inactive !== response.count) {
    throw new Error("Some records have an unknown activity status.")
  }

  return {
    total: response.count,
    active,
    inactive,
  }
}

async function getSiteStats(): Promise<StatusStats> {
  const response = await fetchAllPages((skip, limit) =>
    sitesService.list({ skip, limit }),
  )
  return calculateStats(response)
}

async function getArtifactStats(): Promise<StatusStats> {
  const response = await fetchAllPages((skip, limit) =>
    artifactsService.list({
      skip,
      limit,
      include_inactive: true,
    }),
  )
  return calculateStats(response)
}

async function getBeaconStats(): Promise<StatusStats> {
  const response = await fetchAllPages((skip, limit) =>
    beaconsService.list({ skip, limit }),
  )
  return calculateStats(response)
}

type StatsQuery = {
  data?: StatusStats
  isPending: boolean
  isError: boolean
  refetch: () => unknown
}

function StatusMetric({
  label,
  icon,
  query,
}: {
  label: string
  icon: typeof Archive
  query: StatsQuery
}) {
  if (query.isPending && !query.isError) {
    return <Skeleton className="h-28 rounded-xl" />
  }

  if (query.isError) {
    return (
      <Card className="border-border/70 bg-card shadow-sm">
        <CardContent className="p-4">
          <p className="text-sm font-semibold">{label}</p>
          <p className="mt-2 text-xs text-destructive">
            Unable to load statistics.
          </p>
          <button
            type="button"
            className="mt-2 text-xs font-medium underline"
            onClick={() => void query.refetch()}
          >
            Try again
          </button>
        </CardContent>
      </Card>
    )
  }

  const stats = query.data

  return (
    <div className="relative">
      <MetricCard
        label={label}
        value={stats?.total ?? 0}
        detail={
          stats?.total === 0
            ? "No records available"
            : "Total records (including inactive)"
        }
        icon={icon}
      />
      <div className="mt-1 flex flex-wrap gap-3 px-2 text-xs">
        <span className="text-emerald-500">
          Active: {stats?.active ?? 0}
        </span>
        <span className="text-muted-foreground">
          Inactive: {stats?.inactive ?? 0}
        </span>
      </div>
    </div>
  )
}

function Dashboard() {
  const { user } = useAuth()

  const sitesQuery = useQuery({
    queryKey: ["dashboard", "sites", "status-counts"],
    queryFn: getSiteStats,
    retry: 1,
  })

  const artifactsQuery = useQuery({
    queryKey: ["dashboard", "artifacts", "status-counts"],
    queryFn: getArtifactStats,
    retry: 1,
  })

  const beaconsQuery = useQuery({
    queryKey: ["dashboard", "beacons", "status-counts"],
    queryFn: getBeaconStats,
    retry: 1,
  })

  return (
    <div className="flex flex-col gap-4 md:gap-5">
      <div className="flex flex-wrap items-end justify-between gap-2">
        <p className="text-sm text-muted-foreground">
          Welcome back
          {user?.full_name ? `, ${user.full_name}` : ""}.
          {" "}Here's your administration overview.
        </p>
        <span className="text-xs text-muted-foreground">
          Live values are shown only where an API is available.
        </span>
      </div>

      <section
        className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4"
        aria-label="Overview metrics"
      >
        <StatusMetric
          label="Artifacts"
          icon={Archive}
          query={artifactsQuery}
        />
        <StatusMetric
          label="Sites"
          icon={MapPin}
          query={sitesQuery}
        />
        <StatusMetric
          label="Beacons"
          icon={Radio}
          query={beaconsQuery}
        />
        <MetricCard
          label="Feedback"
          value="—"
          detail="Waiting for feedback API"
          icon={MessageSquare}
        />
      </section>

      <section className="grid gap-4 xl:grid-cols-[1.25fr_0.75fr]">
        <Card className="gap-0 border-border/70 bg-card shadow-sm">
          <CardHeader className="border-b border-border/70 px-5 py-3">
            <CardTitle className="text-sm">
              Site Overview
            </CardTitle>
          </CardHeader>
          <CardContent className="p-0">
            {sitesQuery.isPending && !sitesQuery.isError ? (
              <Skeleton className="h-44" />
            ) : sitesQuery.isError ? (
              <ErrorState
                description="The Site API could not be reached."
                onRetry={() => void sitesQuery.refetch()}
              />
            ) : sitesQuery.data?.total === 0 ? (
              <EmptyState
                title="No sites available"
                description="There are no Site records yet."
              />
            ) : (
              <div className="space-y-2 p-5 text-sm">
                <p>Total Sites: {sitesQuery.data?.total}</p>
                <p>Active: {sitesQuery.data?.active}</p>
                <p>Inactive: {sitesQuery.data?.inactive}</p>
              </div>
            )}
          </CardContent>
        </Card>

        <Card className="gap-0 border-border/70 bg-card shadow-sm">
          <CardHeader className="border-b border-border/70 px-5 py-3">
            <CardTitle className="text-sm">
              Beacon status
            </CardTitle>
          </CardHeader>
          <CardContent className="p-0">
            {beaconsQuery.isPending && !beaconsQuery.isError ? (
              <Skeleton className="h-44" />
            ) : beaconsQuery.isError ? (
              <ErrorState
                description="The Beacon API could not be reached."
                onRetry={() => void beaconsQuery.refetch()}
              />
            ) : beaconsQuery.data?.total === 0 ? (
              <EmptyState
                title="No beacons available"
                description="There are no Beacon records yet."
              />
            ) : (
              <div className="space-y-2 p-5 text-sm">
                <p>Total Beacons: {beaconsQuery.data?.total}</p>
                <p>Active: {beaconsQuery.data?.active}</p>
                <p>Inactive: {beaconsQuery.data?.inactive}</p>
              </div>
            )}
          </CardContent>
        </Card>
      </section>

      <section className="grid gap-4 xl:grid-cols-3">
        <ApiPendingCard
          title="Analytics snapshot"
          description="Visit and content metrics are not available from the current API."
        />
        <ApiPendingCard
          title="Recent alerts"
          description="System alerts will appear when a notification source is connected."
        />
        <ApiPendingCard
          title="Feedback review"
          description="Moderation totals and submissions need a confirmed feedback API."
        />
      </section>
    </div>
  )
}
