import { useQuery } from "@tanstack/react-query"
import { createFileRoute } from "@tanstack/react-router"
import { Archive, MapPin, MessageSquare, Radio } from "lucide-react"

import {
  EmptyState,
  ErrorState,
  MetricCard,
} from "@/components/Common/AdminPrimitives"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Skeleton } from "@/components/ui/skeleton"
import useAuth from "@/hooks/useAuth"
import { artifactsService } from "@/services/artifacts"
import { beaconsService } from "@/services/beacon"
import { feedbackService } from "@/services/feedback"
import { sitesService } from "@/services/sites"
import { DashboardService } from "@/client"
import { unwrapApi } from "@/services/api-errors"

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
      throw new Error("Records changed while loading statistics. Please retry.")
    }

    if (page.data.length === 0) {
      throw new Error("An API page returned no records unexpectedly.")
    }

    records.push(...page.data)
  }

  if (records.length !== total) {
    throw new Error("The statistics are incomplete. Please retry.")
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
  valueMode = "total",
}: {
  label: string
  icon: typeof Archive
  query: StatsQuery
  valueMode?: "total" | "active"
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
  const displayValue =
    valueMode === "active" ? (stats?.active ?? 0) : (stats?.total ?? 0)
  return (
    <div className="relative">
      <MetricCard
        label={label}
        value={displayValue}
        detail={
          valueMode === "active"
            ? "Currently active sites"
            : stats?.total === 0
              ? "No records available"
              : "Total records (including inactive)"
        }
        icon={icon}
      />
      <div className="mt-1 flex flex-wrap gap-3 px-2 text-xs">
        <span className="text-emerald-500">Active: {stats?.active ?? 0}</span>
        <span className="text-muted-foreground">
          Inactive: {stats?.inactive ?? 0}
        </span>
      </div>
    </div>
  )
}

function formatDashboardDate(value?: string | null) {
  if (!value) return "—"

  const date = new Date(value)

  if (Number.isNaN(date.getTime())) return "—"

  return new Intl.DateTimeFormat("vi-VN", {
    dateStyle: "short",
    timeStyle: "short",
  }).format(date)
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

  const summaryQuery = useQuery({
    queryKey: ["dashboard", "summary"],
    queryFn: () =>
      unwrapApi(
        DashboardService.readSummary(),
        "Dashboard summary",
      ),
    retry: 1,
  })

  const topArtifactsQuery = useQuery({
    queryKey: ["dashboard", "top-artifacts", 5],
    queryFn: () =>
      unwrapApi(
        DashboardService.readTopArtifacts({
          query: { limit: 5 },
        }),
        "Top artifacts",
      ),
    retry: 1,
  })

  const visitsByLanguageQuery = useQuery({
    queryKey: ["dashboard", "visits-by-language"],
    queryFn: () =>
      unwrapApi(
        DashboardService.readVisitsByLanguage(),
        "Visits by language",
      ),
    retry: 1,
  })

  const feedbackQuery = useQuery({
    queryKey: ["dashboard", "feedback", "recent", 5],
    queryFn: () =>
      feedbackService.list({
        skip: 0,
        limit: 5,
      }),
    retry: 1,
  })

  const pendingFeedbackQuery = useQuery({
    queryKey: ["dashboard", "feedback", "pending-count"],
    queryFn: async () => {
      const response = await feedbackService.list({
        status: "pending",
        limit: 1,
      })

      return response.count
    },
    retry: 1,
  })

  const recentAlerts = [
    ...(sitesQuery.data?.inactive
      ? [{
          id: "inactive-sites",
          title: "Inactive sites detected",
          description: `${sitesQuery.data.inactive} sites are currently inactive.`,
          type: "warning",
        }]
      : []),

    ...(artifactsQuery.data?.inactive
      ? [{
          id: "inactive-artifacts",
          title: "Inactive artifacts detected",
          description: `${artifactsQuery.data.inactive} artifacts are currently inactive.`,
          type: "warning",
        }]
      : []),

    ...(beaconsQuery.data?.inactive
      ? [{
          id: "inactive-beacons",
          title: "Inactive beacons detected",
          description: `${beaconsQuery.data.inactive} beacons are currently inactive.`,
          type: "warning",
        }]
      : []),

    ...(pendingFeedbackQuery.data
      ? [{
          id: "pending-feedback",
          title: "Feedback awaiting moderation",
          description: `${pendingFeedbackQuery.data} feedback submissions need review.`,
          type: "info",
        }]
      : []),
  ]

  return (
    <div className="flex flex-col gap-4 md:gap-5">
      <div className="flex flex-wrap items-end justify-between gap-2">
        <p className="text-sm text-muted-foreground">
          Welcome back
          {user?.full_name ? `, ${user.full_name}` : ""}. Here's your
          administration overview.
        </p>
        <span className="text-xs text-muted-foreground">
          Live values are shown only where an API is available.
        </span>
      </div>

      <section
        className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4"
        aria-label="Overview metrics"
      >
        <StatusMetric label="Artifacts" icon={Archive} query={artifactsQuery} />
        <StatusMetric
          label="Active Sites"
          icon={MapPin}
          query={sitesQuery}
          valueMode="active"
        />
        <StatusMetric label="Beacons" icon={Radio} query={beaconsQuery} />
        {feedbackQuery.isPending && !feedbackQuery.isError ? (
          <Skeleton className="h-28 rounded-xl" />
        ) : feedbackQuery.isError ? (
          <Card className="border-border/70 bg-card shadow-sm">
            <CardContent className="p-4">
              <p className="text-sm font-semibold">Feedback</p>
              <p className="mt-2 text-xs text-destructive">
                Unable to load feedback statistics.
              </p>
              <button
                type="button"
                className="mt-2 text-xs font-medium underline"
                onClick={() => void feedbackQuery.refetch()}
              >
                Try again
              </button>
            </CardContent>
          </Card>
        ) : (
          <MetricCard
            label="Feedback"
            value={feedbackQuery.data?.count ?? 0}
            detail="Total feedback submissions"
            icon={MessageSquare}
          />
        )}
      </section>

      <section className="grid gap-4 xl:grid-cols-[1.25fr_0.75fr]">
        <Card className="gap-0 border-border/70 bg-card shadow-sm">
          <CardHeader className="border-b border-border/70 px-5 py-3">
            <CardTitle className="text-sm">Site Overview</CardTitle>
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
            <CardTitle className="text-sm">Beacon status</CardTitle>
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
        {/* Analytics Snapshot */}
        <Card className="gap-0 border-border/70 bg-card shadow-sm">
          <CardHeader className="border-b border-border/70 px-5 py-3">
            <CardTitle className="text-sm">Analytics Snapshot</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4 p-5">
            {summaryQuery.isPending && !summaryQuery.isError ? (
              <Skeleton className="h-28" />
            ) : summaryQuery.isError ? (
              <ErrorState
                description="The Dashboard Summary API could not be reached."
                onRetry={() => void summaryQuery.refetch()}
              />
            ) : (
              <>
                <div>
                  <p className="text-xs text-muted-foreground">
                    Total visits
                  </p>
                  <p className="text-2xl font-semibold tabular-nums">
                    {summaryQuery.data?.visits.total.toLocaleString("vi-VN") ?? 0}
                  </p>
                </div>
                <div>
                  <p className="text-xs text-muted-foreground">
                    Unique visitors
                  </p>
                  <p className="text-xl font-semibold tabular-nums">
                    {summaryQuery.data?.visits.unique_visitors.toLocaleString("vi-VN") ?? 0}
                  </p>
                </div>
              </>
            )}

            <div className="border-t border-border/70 pt-3">
              <p className="mb-2 text-xs font-semibold text-muted-foreground">
                TOP 5 ARTIFACTS
              </p>
              {topArtifactsQuery.isPending && !topArtifactsQuery.isError ? (
                <Skeleton className="h-24" />
              ) : topArtifactsQuery.isError ? (
                <ErrorState
                  description="Unable to load top artifacts."
                  onRetry={() => void topArtifactsQuery.refetch()}
                />
              ) : topArtifactsQuery.data?.data.length ? (
                <div className="space-y-3">
                  {topArtifactsQuery.data.data.map((artifact, index) => (
                    <div
                      key={artifact.artifact_id}
                      className="flex items-start justify-between gap-3 text-sm"
                    >
                      <div className="min-w-0">
                        <p className="font-medium">
                          {index + 1}. {artifact.title || artifact.code}
                        </p>
                        <p className="truncate text-xs text-muted-foreground">
                          {artifact.code}
                        </p>
                      </div>
                      <span className="shrink-0 font-semibold tabular-nums">
                        {artifact.visit_count.toLocaleString("vi-VN")}
                      </span>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-sm text-muted-foreground">
                  No artifact views available.
                </p>
              )}
            </div>

            <div className="border-t border-border/70 pt-3">
              <p className="mb-2 text-xs font-semibold text-muted-foreground">
                VISITS BY LANGUAGE
              </p>
              {visitsByLanguageQuery.isPending &&
              !visitsByLanguageQuery.isError ? (
                <Skeleton className="h-16" />
              ) : visitsByLanguageQuery.isError ? (
                <ErrorState
                  description="Unable to load language statistics."
                  onRetry={() => void visitsByLanguageQuery.refetch()}
                />
              ) : visitsByLanguageQuery.data?.data.length ? (
                <div className="space-y-2">
                  {visitsByLanguageQuery.data.data.map((language, index) => (
                    <div
                      key={language.language_id ?? language.code ?? `unknown-${index}`}
                      className="flex justify-between gap-3 text-sm"
                    >
                      <span className="truncate text-muted-foreground">
                        {language.name || language.code || "Unknown language"}
                      </span>
                      <span className="font-medium tabular-nums">
                        {language.count.toLocaleString("vi-VN")}
                      </span>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-sm text-muted-foreground">
                  No language statistics available.
                </p>
              )}
            </div>
          </CardContent>
        </Card>

        {/* Recent Alerts: giữ trạng thái chờ API */}
        
        <Card className="gap-0 border-border/70 bg-card shadow-sm">
          <CardHeader className="border-b border-border/70 px-5 py-3">
            <CardTitle className="text-sm">
              Recent Alerts
            </CardTitle>
          </CardHeader>

          <CardContent className="p-5">
            {sitesQuery.isPending ||
            artifactsQuery.isPending ||
            beaconsQuery.isPending ||
            pendingFeedbackQuery.isPending ? (
              <Skeleton className="h-32" />
            ) : sitesQuery.isError ||
              artifactsQuery.isError ||
              beaconsQuery.isError ||
              pendingFeedbackQuery.isError ? (
              <ErrorState
                description="Unable to load system alerts."
                onRetry={() => {
                  void sitesQuery.refetch()
                  void artifactsQuery.refetch()
                  void beaconsQuery.refetch()
                  void pendingFeedbackQuery.refetch()
                }}
              />
            ) : recentAlerts.length > 0 ? (
              <div className="space-y-4">
                {recentAlerts.map((alert) => (
                  <div
                    key={alert.id}
                    className="flex gap-3 border-b border-border/70 pb-3 last:border-0 last:pb-0"
                  >
                    <div className="mt-1 h-2 w-2 shrink-0 rounded-full bg-amber-500" />

                    <div className="min-w-0">
                      <p className="text-sm font-semibold">
                        {alert.title}
                      </p>
                      <p className="mt-1 text-xs text-muted-foreground">
                        {alert.description}
                      </p>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <EmptyState
                title="All systems look good"
                description="No inactive resources or pending feedback were detected."
              />
            )}
          </CardContent>
        </Card>


        {/* Recent Feedback */}
        <Card className="gap-0 border-border/70 bg-card shadow-sm">
          <CardHeader className="border-b border-border/70 px-5 py-3">
            <CardTitle className="text-sm">Recent Feedback</CardTitle>
          </CardHeader>
          <CardContent className="p-5">
            {feedbackQuery.isPending && !feedbackQuery.isError ? (
              <Skeleton className="h-36" />
            ) : feedbackQuery.isError ? (
              <ErrorState
                description="The Feedback API could not be reached."
                onRetry={() => void feedbackQuery.refetch()}
              />
            ) : feedbackQuery.data?.data.length ? (
              <div className="space-y-4">
                {feedbackQuery.data.data.map((feedback) => (
                  <div
                    key={feedback.id}
                    className="space-y-1 border-b border-border/70 pb-3 last:border-0 last:pb-0"
                  >
                    <div className="flex items-start justify-between gap-2">
                      <p className="text-sm font-medium">
                        {feedback.visitor_name || feedback.visitor_email}
                      </p>
                      <span className="shrink-0 text-xs text-muted-foreground">
                        {formatDashboardDate(feedback.created_at)}
                      </span>
                    </div>

                    <p className="text-xs text-muted-foreground">
                      {feedback.artifact_title || feedback.artifact_code}
                      {" · "}
                      {feedback.site_name}
                    </p>

                    <p className="text-sm">
                      {"★".repeat(feedback.rating)}
                      {"☆".repeat(5 - feedback.rating)}
                    </p>

                    <p className="line-clamp-2 text-sm text-muted-foreground">
                      {feedback.comment || "No comment"}
                    </p>

                    <span className="text-xs capitalize text-muted-foreground">
                      {feedback.status}
                    </span>
                  </div>
                ))}
              </div>
            ) : (
              <EmptyState
                title="No feedback yet"
                description="Visitor feedback will appear here."
              />
            )}
          </CardContent>
        </Card>
      </section>
    </div>
  )
}
