import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import {
  Archive,
  Bell,
  CalendarDays,
  ChartNoAxesColumnIncreasing,
  ChevronLeft,
  ChevronRight,
  CircleAlert,
  FileSpreadsheet,
  FileText,
  Filter,
  LoaderCircle,
  MessageSquare,
  Search,
  Star,
  UsersRound,
} from "lucide-react"
import { useState } from "react"
import { toast } from "sonner"
import type { FeedbackAdminStatus, FeedbackReviewPublic } from "@/client"
import { BeaconManagement } from "@/components/Beacons/BeaconManagement"
import {
  ApiPendingCard,
  EmptyState,
  MetricCard,
} from "@/components/Common/AdminPrimitives"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { analyticsService } from "@/services/analytics"
import { feedbackKeys, feedbackService } from "@/services/feedback"

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
        <CardTitle className="flex items-center gap-2 text-sm">
          <Icon className="size-4 text-primary" />
          {title}
        </CardTitle>
        {badge && <Badge variant="secondary">{badge}</Badge>}
      </CardHeader>
      <CardContent className="p-0">{children}</CardContent>
    </Card>
  )
}

function DisabledFilter({ label }: { label: string }) {
  return (
    <Button variant="outline" disabled>
      <Filter />
      {label}
    </Button>
  )
}

export function BeaconManagementScreen() {
  return <BeaconManagement />
}

function getDateString(date: Date) {
  return date.toISOString().slice(0, 10)
}

function getDefaultDateRange() {
  const today = new Date()
  const thirtyDaysAgo = new Date(today)

  thirtyDaysAgo.setUTCDate(thirtyDaysAgo.getUTCDate() - 29)

  return {
    from: getDateString(thirtyDaysAgo),
    to: getDateString(today),
  }
}

export function AnalyticsScreen() {
  const defaultRange = getDefaultDateRange()

  const [fromDate, setFromDate] = useState(defaultRange.from)
  const [toDate, setToDate] = useState(defaultRange.to)
  const [selectedSiteId, setSelectedSiteId] = useState("")
  const [isExportingPdf, setIsExportingPdf] = useState(false)
  
  const [isExportingExcel, setIsExportingExcel] = useState(false)

  // Chỉ tạo bộ lọc khi cả hai ngày đều hợp lệ.
  const isDateRangeValid =
    Boolean(fromDate && toDate) && fromDate <= toDate

  // Analytics API sử dụng khoảng thời gian UTC [from, to).
  // Ngày kết thúc được chuyển thành 00:00 UTC của ngày kế tiếp.
  const exclusiveEndDate = isDateRangeValid
    ? new Date(`${toDate}T00:00:00Z`)
    : null

  exclusiveEndDate?.setUTCDate(exclusiveEndDate.getUTCDate() + 1)

  const analyticsFilters = {
    from: isDateRangeValid ? `${fromDate}T00:00:00Z` : undefined,
    to: exclusiveEndDate
      ? `${getDateString(exclusiveEndDate)}T00:00:00Z`
      : undefined,
    site_id: selectedSiteId || undefined,
  }

  // Dashboard API sử dụng ngày bắt đầu và kết thúc inclusive.
  const dashboardFilters = {
    from_date: fromDate || undefined,
    to_date: toDate || undefined,
  }

  // Danh sách Site cho bộ lọc, không phụ thuộc Site đang chọn.
  const siteOptionsFilters = {
    from: analyticsFilters.from,
    to: analyticsFilters.to,
    limit: 100,
  }

  const siteOptionsQuery = useQuery({
    queryKey: ["analytics", "site-options", siteOptionsFilters],
    queryFn: () => analyticsService.sites(siteOptionsFilters),
    enabled: isDateRangeValid,
  })

  // Analytics API
  const overviewQuery = useQuery({
    queryKey: ["analytics", "overview", analyticsFilters],
    queryFn: () => analyticsService.overview(analyticsFilters),
    enabled: isDateRangeValid,
  })

  const visitsQuery = useQuery({
    queryKey: ["analytics", "visits", analyticsFilters],
    queryFn: () => analyticsService.visits(analyticsFilters),
    enabled: isDateRangeValid,
  })

  const sitesQuery = useQuery({
    queryKey: ["analytics", "sites", analyticsFilters],
    queryFn: () => analyticsService.sites(analyticsFilters),
    enabled: isDateRangeValid,
  })

  const topArtifactsQuery = useQuery({
    queryKey: ["analytics", "top-artifacts", analyticsFilters],
    queryFn: () =>
      analyticsService.topArtifacts({
        ...analyticsFilters,
        limit: 10,
      }),
    enabled: isDateRangeValid,
  })

  // Dashboard API
  const summaryQuery = useQuery({
    queryKey: ["analytics", "dashboard-summary", dashboardFilters],
    queryFn: () => analyticsService.summary(dashboardFilters),
    enabled: isDateRangeValid,
  })

  const languageQuery = useQuery({
    queryKey: ["analytics", "visits-by-language", dashboardFilters],
    queryFn: () => analyticsService.visitsByLanguage(dashboardFilters),
    enabled: isDateRangeValid,
  })

  const dailyVisits = visitsQuery.data ?? []
  const siteStats = sitesQuery.data ?? []
  const topArtifacts = topArtifactsQuery.data ?? []
  const siteOptions = siteOptionsQuery.data ?? []
  const languages = languageQuery.data?.data ?? []

  const maxDailyViews = Math.max(1, ...dailyVisits.map((item) => item.views))

  const numberFormat = new Intl.NumberFormat("vi-VN")

  const isDateRangeInvalid = !isDateRangeValid

  const handleExportPdf = async () => {
    if (isDateRangeInvalid) return

    setIsExportingPdf(true)

    try {
      await analyticsService.exportPdf(analyticsFilters)
      toast.success("PDF report exported successfully.")
    } catch (error) {
      toast.error(
        error instanceof Error ? error.message : "Unable to export PDF report.",
      )
    } finally {
      setIsExportingPdf(false)
    }
  }

  const handleExportExcel = async () => {
    if (isDateRangeInvalid) return

    setIsExportingExcel(true)

    try {
      await analyticsService.exportExcel(analyticsFilters)
      toast.success("Excel report exported successfully.")
    } catch (error) {
      toast.error(
        error instanceof Error
          ? error.message
          : "Unable to export Excel report.",
      )
    } finally {
      setIsExportingExcel(false)
    }
  }

  return (
    <div className="flex flex-col gap-4 md:gap-5">
      {/* Date and Site filters */}
      <Card className="border-border/70 bg-card shadow-sm">
        <CardContent className="flex flex-wrap items-end gap-3 p-4">
          <div className="flex flex-col gap-1.5">
            <label
              htmlFor="analytics-from"
              className="text-xs font-medium text-muted-foreground"
            >
              From date
            </label>
            <Input
              id="analytics-from"
              type="date"
              value={fromDate}
              max={toDate}
              onChange={(event) => setFromDate(event.target.value)}
              className="w-[170px]"
            />
          </div>

          <div className="flex flex-col gap-1.5">
            <label
              htmlFor="analytics-to"
              className="text-xs font-medium text-muted-foreground"
            >
              To date
            </label>
            <Input
              id="analytics-to"
              type="date"
              value={toDate}
              min={fromDate}
              onChange={(event) => setToDate(event.target.value)}
              className="w-[170px]"
            />
          </div>

          <div className="flex min-w-[190px] flex-col gap-1.5">
            <label
              htmlFor="analytics-site"
              className="text-xs font-medium text-muted-foreground"
            >
              Site
            </label>
            <select
              id="analytics-site"
              value={selectedSiteId}
              onChange={(event) => setSelectedSiteId(event.target.value)}
              className="h-9 rounded-md border border-input bg-background px-3 text-sm shadow-sm outline-none focus-visible:ring-2 focus-visible:ring-ring"
            >
              <option value="">All sites</option>
              {siteOptions.map((site) => (
                <option key={site.site_id} value={site.site_id}>
                  {site.name}
                </option>
              ))}
            </select>
          </div>

          <Button
            variant="outline"
            onClick={() => {
              setFromDate(defaultRange.from)
              setToDate(defaultRange.to)
              setSelectedSiteId("")
            }}
          >
            Reset filters
          </Button>

          <Button
            variant="outline"
            disabled={isDateRangeInvalid || isExportingPdf || isExportingExcel}
            onClick={handleExportPdf}
            className="border-blue-500/40 text-blue-600 hover:bg-blue-500/10 dark:text-blue-400"
          >
            {isExportingPdf ? (
              <LoaderCircle className="animate-spin" />
            ) : (
              <FileText />
            )}
            {isExportingPdf ? "Exporting PDF..." : "Export PDF"}
          </Button>

          <Button
            variant="outline"
            disabled={isDateRangeInvalid || isExportingExcel || isExportingPdf}
            onClick={handleExportExcel}
            className="border-emerald-500/40 text-emerald-600 hover:bg-emerald-500/10 dark:text-emerald-400"
          >
            {isExportingExcel ? (
              <LoaderCircle className="animate-spin" />
            ) : (
              <FileSpreadsheet />
            )}
            {isExportingExcel ? "Exporting Excel..." : "Export Excel"}
          </Button>

          {siteOptionsQuery.isError && (
            <p className="w-full text-xs text-destructive">
              Unable to load Site options: {siteOptionsQuery.error.message}
            </p>
          )}

          {isDateRangeInvalid && (
            <p className="w-full text-xs text-destructive">
              {!fromDate || !toDate
                ? "Please select both start and end dates."
                : "The start date must not be later than the end date."}
            </p>
          )}
        </CardContent>
      </Card>

      {/* Overview metrics */}
      <section className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <MetricCard
          label="Content views"
          value={
            overviewQuery.isPending
              ? "..."
              : overviewQuery.isError
                ? "Error"
                : numberFormat.format(overviewQuery.data?.views ?? 0)
          }
          detail="Total recorded content views"
          icon={UsersRound}
        />

        <MetricCard
          label="Unique users"
          value={
            overviewQuery.isPending
              ? "..."
              : overviewQuery.isError
                ? "Error"
                : numberFormat.format(overviewQuery.data?.unique_users ?? 0)
          }
          detail="Unique users in the selected period"
          icon={UsersRound}
        />

        <MetricCard
          label="Artifacts viewed"
          value={
            overviewQuery.isPending
              ? "..."
              : overviewQuery.isError
                ? "Error"
                : numberFormat.format(overviewQuery.data?.artifacts_viewed ?? 0)
          }
          detail="Artifacts with recorded views"
          icon={Archive}
        />

        <MetricCard
          label="Average rating"
          value={
            summaryQuery.isPending
              ? "..."
              : summaryQuery.isError
                ? "Error"
                : typeof summaryQuery.data?.ratings.average === "number"
                  ? `${summaryQuery.data.ratings.average.toFixed(1)}/5`
                  : "—"
          }
          detail="Overall rating, not date-filtered"
          icon={Star}
        />
      </section>

      {/* Daily visits and language */}
      <div className="grid gap-4 xl:grid-cols-[1.35fr_0.85fr]">
        <ScreenCard
          title="Daily content views"
          icon={ChartNoAxesColumnIncreasing}
          badge={`${dailyVisits.length} days`}
        >
          {visitsQuery.isPending ? (
            <div className="p-6 text-center text-sm text-muted-foreground">
              Loading daily analytics...
            </div>
          ) : visitsQuery.isError ? (
            <EmptyState
              title="Unable to load daily analytics"
              description={visitsQuery.error.message}
              icon={CircleAlert}
            />
          ) : dailyVisits.length === 0 ? (
            <EmptyState
              title="No daily views"
              description="There are no recorded content views in this date range."
              icon={ChartNoAxesColumnIncreasing}
            />
          ) : (
            <div className="space-y-4 p-4">
              <div className="flex items-center justify-between text-xs text-muted-foreground">
                <span>Daily views</span>
                <span>
                  {numberFormat.format(
                    dailyVisits.reduce((total, item) => total + item.views, 0),
                  )}{" "}
                  total views
                </span>
              </div>

              <div className="flex h-48 items-end gap-1 overflow-x-auto border-b border-border/70 pb-1">
                {dailyVisits.map((item) => (
                  <div
                    key={item.date}
                    className="group flex h-full min-w-5 flex-1 flex-col items-center justify-end gap-1"
                    title={`${item.date}: ${numberFormat.format(item.views)} views, ${numberFormat.format(item.unique_users)} unique users`}
                  >
                    <div
                      className="w-full rounded-t-sm bg-primary/80 transition-colors group-hover:bg-primary"
                      style={{
                        height: `${Math.max(
                          3,
                          (item.views / maxDailyViews) * 100,
                        )}%`,
                      }}
                    />
                  </div>
                ))}
              </div>

              <div className="flex justify-between gap-2 text-[10px] text-muted-foreground">
                <span>{dailyVisits[0]?.date}</span>
                <span>{dailyVisits[dailyVisits.length - 1]?.date}</span>
              </div>

              <div className="overflow-x-auto">
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Date</TableHead>
                      <TableHead className="text-right">Views</TableHead>
                      <TableHead className="text-right">Unique users</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {dailyVisits.map((item) => (
                      <TableRow key={item.date}>
                        <TableCell className="whitespace-nowrap">
                          {item.date}
                        </TableCell>
                        <TableCell className="text-right">
                          {numberFormat.format(item.views)}
                        </TableCell>
                        <TableCell className="text-right">
                          {numberFormat.format(item.unique_users)}
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </div>
            </div>
          )}
        </ScreenCard>

        <ScreenCard title="Visits by language" icon={FileText}>
          {languageQuery.isPending ? (
            <div className="p-6 text-center text-sm text-muted-foreground">
              Loading language statistics...
            </div>
          ) : languageQuery.isError ? (
            <EmptyState
              title="Unable to load language statistics"
              description={languageQuery.error.message}
              icon={CircleAlert}
            />
          ) : languages.length === 0 ? (
            <EmptyState
              title="No language data"
              description="No language statistics are available for this period."
              icon={FileText}
            />
          ) : (
            <div className="divide-y divide-border/70">
              {languages.map((item, index) => (
                <div
                  key={item.language_id ?? item.code ?? `language-${index}`}
                  className="flex items-center justify-between gap-3 px-4 py-3"
                >
                  <div className="min-w-0">
                    <p className="truncate text-sm font-medium">
                      {item.name || item.code || "Unknown language"}
                    </p>
                    {item.code && (
                      <p className="text-xs text-muted-foreground">
                        {item.code}
                      </p>
                    )}
                  </div>
                  <span className="whitespace-nowrap text-sm font-semibold tabular-nums">
                    {numberFormat.format(item.count)}
                  </span>
                </div>
              ))}
            </div>
          )}
        </ScreenCard>
      </div>

      {/* Site performance and inventory */}
      <div className="grid items-start gap-4 xl:grid-cols-[1.5fr_0.7fr]">
        <ScreenCard
          title="Performance by Site"
          icon={CalendarDays}
          badge={`${siteStats.length} sites`}
        >
          {sitesQuery.isPending ? (
            <div className="p-6 text-center text-sm text-muted-foreground">
              Loading Site analytics...
            </div>
          ) : sitesQuery.isError ? (
            <EmptyState
              title="Unable to load Site analytics"
              description={sitesQuery.error.message}
              icon={CircleAlert}
            />
          ) : siteStats.length === 0 ? (
            <EmptyState
              title="No Site analytics available"
              description="There are no recorded views for the selected filters."
              icon={CalendarDays}
            />
          ) : (
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Site name</TableHead>
                    <TableHead className="text-right">Views</TableHead>
                    <TableHead className="text-right">Unique users</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {siteStats.map((site) => (
                    <TableRow key={site.site_id}>
                      <TableCell>
                        <div className="min-w-[140px]">
                          <p className="font-medium">{site.name}</p>
                          <p className="text-xs text-muted-foreground">
                            {site.site_id}
                          </p>
                        </div>
                      </TableCell>
                      <TableCell className="text-right tabular-nums">
                        {numberFormat.format(site.views)}
                      </TableCell>
                      <TableCell className="text-right tabular-nums">
                        {numberFormat.format(site.unique_users)}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          )}
        </ScreenCard>

        <ScreenCard title="Inventory Summary" icon={Archive}>
          {summaryQuery.isPending ? (
            <div className="p-6 text-center text-sm text-muted-foreground">
              Loading inventory summary...
            </div>
          ) : summaryQuery.isError ? (
            <EmptyState
              title="Unable to load inventory"
              description={summaryQuery.error.message}
              icon={CircleAlert}
            />
          ) : (
            <div className="divide-y divide-border/70">
              {(
                [
                  ["Sites", summaryQuery.data.sites],
                  ["Artifacts", summaryQuery.data.artifacts],
                  ["Beacons", summaryQuery.data.beacons],
                ] as const
              ).map(([label, item]) => (
                <div
                  key={label}
                  className="flex items-center justify-between gap-3 px-4 py-3"
                >
                  <div>
                    <p className="text-sm font-medium">{label}</p>
                    <p className="text-xs text-muted-foreground">
                      {numberFormat.format(item.active)} active
                    </p>
                  </div>
                  <p className="text-lg font-semibold tabular-nums">
                    {numberFormat.format(item.total)}
                  </p>
                </div>
              ))}
            </div>
          )}
        </ScreenCard>
      </div>

      {/* Top artifacts */}
      <ScreenCard title="Top Artifacts" icon={Archive} badge="Top 10">
        {topArtifactsQuery.isPending ? (
          <div className="p-6 text-center text-sm text-muted-foreground">
            Loading top artifacts...
          </div>
        ) : topArtifactsQuery.isError ? (
          <EmptyState
            title="Unable to load top artifacts"
            description={topArtifactsQuery.error.message}
            icon={CircleAlert}
          />
        ) : topArtifacts.length === 0 ? (
          <EmptyState
            title="No artifact views"
            description="No artifacts have recorded views in the selected period."
            icon={Archive}
          />
        ) : (
          <div className="overflow-x-auto">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Artifact code</TableHead>
                  <TableHead>Artifact ID</TableHead>
                  <TableHead className="text-right">Views</TableHead>
                  <TableHead className="text-right">Unique users</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {topArtifacts.map((artifact) => (
                  <TableRow key={artifact.artifact_id}>
                    <TableCell className="font-medium">
                      {artifact.code}
                    </TableCell>
                    <TableCell className="max-w-[180px] truncate text-xs text-muted-foreground">
                      {artifact.artifact_id}
                    </TableCell>
                    <TableCell className="text-right tabular-nums">
                      {numberFormat.format(artifact.views)}
                    </TableCell>
                    <TableCell className="text-right tabular-nums">
                      {numberFormat.format(artifact.unique_users)}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
        )}
      </ScreenCard>

      <p className="text-xs text-muted-foreground">
        Analytics views represent recorded content-view events. They should not
        be interpreted as physical visitor counts. Average rating and inventory
        summary are provided by the Dashboard API; average rating is not
        filtered by the selected date range or Site.
      </p>
    </div>
  )
}

type ModerationStatus = "pending" | "approved" | "hidden"

const PAGE_SIZE = 10

function formatFeedbackDate(value?: string | null) {
  if (!value) return "—"

  const date = new Date(value)

  if (Number.isNaN(date.getTime())) return "—"

  return date.toLocaleString("vi-VN", {
    dateStyle: "short",
    timeStyle: "short",
  })
}

function getStatusLabel(status?: string | null) {
  switch (status) {
    case "pending":
      return "Pending"
    case "approved":
      return "Approved"
    case "hidden":
      return "Hidden"
    default:
      return "Unknown"
  }
}

function FeedbackStatusBadge({ status }: { status?: string | null }) {
  return (
    <Badge
      variant={
        status === "approved"
          ? "default"
          : status === "hidden"
            ? "destructive"
            : "secondary"
      }
    >
      {getStatusLabel(status)}
    </Badge>
  )
}

export function FeedbackScreen() {
  const queryClient = useQueryClient()

  const [search, setSearch] = useState("")
  const [statusFilter, setStatusFilter] = useState<"all" | FeedbackAdminStatus>(
    "all",
  )
  const [page, setPage] = useState(0)
  const [selectedId, setSelectedId] = useState<string | null>(null)

  const filters = {
    q: search.trim() || undefined,
    status: statusFilter === "all" ? undefined : statusFilter,
    skip: page * PAGE_SIZE,
    limit: PAGE_SIZE,
  }

  // Lấy danh sách phản hồi
  const feedbackQuery = useQuery({
    queryKey: feedbackKeys.list(filters),
    queryFn: () => feedbackService.list(filters),
  })

  // Duyệt hoặc từ chối phản hồi
  const moderationMutation = useMutation({
  mutationFn: ({
    id,
    status,
    expectedUpdatedAt,
  }: {
    id: string
    status: ModerationStatus
    expectedUpdatedAt: string | null
  }) =>
    feedbackService.updateStatus(id, {
      status,
      expected_updated_at: expectedUpdatedAt,
    }),

  onSuccess: async () => {
    await queryClient.invalidateQueries({
      queryKey: feedbackKeys.all,
    })

    toast.success("Feedback status updated successfully.")
  },

  onError: async (error) => {
    await queryClient.invalidateQueries({
      queryKey: feedbackKeys.all,
    })

    if (
      error instanceof Error &&
      error.message.includes("Feedback changed; reload before moderating")
    ) {
      toast.warning(
        "Feedback has changed. The latest data has been reloaded. Please review it again.",
      )
      return
    }

    toast.error(
      error instanceof Error
        ? error.message
        : "Unable to update feedback status.",
    )
  },
})

  const feedbacks = feedbackQuery.data?.data ?? []
  const totalCount = feedbackQuery.data?.count ?? 0
  const totalPages = Math.ceil(totalCount / PAGE_SIZE)

  const selectedFeedback: FeedbackReviewPublic | null =
    feedbacks.find((item) => item.id === selectedId) ?? feedbacks[0] ?? null

  const pendingCount = feedbacks.filter(
    (item) => item.status === "pending",
  ).length

  const approvedCount = feedbacks.filter(
    (item) => item.status === "approved",
  ).length

  const hiddenCount = feedbacks.filter(
    (item) => item.status === "hidden",
  ).length

  function handleFilterChange(value: "all" | FeedbackAdminStatus) {
    setStatusFilter(value)
    setPage(0)
    setSelectedId(null)
    moderationMutation.reset()
  }

  function handleSearchChange(value: string) {
    setSearch(value)
    setPage(0)
    setSelectedId(null)
  }

  function handleModeration(status: ModerationStatus) {
    if (!selectedFeedback) return

    moderationMutation.mutate({
      id: selectedFeedback.id,
      status,
      expectedUpdatedAt: selectedFeedback.updated_at ?? null,
    })
  }

  return (
    <div className="flex flex-col gap-4 md:gap-5">
      {/* Search and filters */}
      <div className="flex flex-wrap items-center gap-2">
        <div className="relative min-w-[210px] flex-1 sm:max-w-xs">
          <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />

          <Input
            className="pl-9"
            placeholder="Search feedback..."
            aria-label="Search feedback"
            value={search}
            onChange={(event) => handleSearchChange(event.target.value)}
          />
        </div>

        <div className="flex flex-wrap gap-1 sm:ml-auto">
          {(
            [
              ["all", "All"],
              ["pending", "Pending"],
              ["approved", "Approved"],
              ["hidden", "Hidden"],
            ] as const
          ).map(([value, label]) => (
            <Button
              key={value}
              variant={statusFilter === value ? "default" : "outline"}
              size="sm"
              onClick={() => handleFilterChange(value)}
            >
              {label}
            </Button>
          ))}
        </div>
      </div>

      {/* Summary */}
      <div className="flex flex-wrap items-center gap-2 text-sm">
        <Badge variant="secondary">{pendingCount} Pending</Badge>

        <Badge variant="secondary">{approvedCount} Approved</Badge>

        <Badge variant="secondary">{hiddenCount} Hidden</Badge>

        <span className="text-xs text-muted-foreground">
          Showing {feedbacks.length} of {totalCount} matching submissions on
          this page
        </span>
      </div>

      {/* Main content */}
      <div className="grid items-start gap-4 xl:grid-cols-[1.05fr_0.95fr]">
        {/* Feedback table */}
        <ScreenCard
          title="Visitor Feedback"
          icon={MessageSquare}
          badge={`${totalCount} submissions`}
        >
          {feedbackQuery.isPending ? (
            <div className="p-6 text-center text-sm text-muted-foreground">
              Loading feedback...
            </div>
          ) : feedbackQuery.isError ? (
            <EmptyState
              title="Unable to load feedback"
              description={feedbackQuery.error.message}
              icon={CircleAlert}
            />
          ) : feedbacks.length === 0 ? (
            <EmptyState
              title="No feedback submissions"
              description="There are no feedback records matching your search or filter."
              icon={MessageSquare}
            />
          ) : (
            <>
              <div className="overflow-x-auto">
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Visitor</TableHead>
                      <TableHead>Artifact / Site</TableHead>
                      <TableHead>Rating</TableHead>
                      <TableHead>Status</TableHead>
                      <TableHead>Date</TableHead>
                    </TableRow>
                  </TableHeader>

                  <TableBody>
                    {feedbacks.map((feedback) => (
                      <TableRow
                        key={feedback.id}
                        onClick={() => setSelectedId(feedback.id)}
                        className={`cursor-pointer ${
                          selectedFeedback?.id === feedback.id ? "bg-muted" : ""
                        }`}
                      >
                        <TableCell>
                          <div className="min-w-[130px]">
                            <p className="font-medium">
                              {feedback.visitor_name || "Anonymous"}
                            </p>
                            <p className="max-w-[160px] truncate text-xs text-muted-foreground">
                              {feedback.visitor_email}
                            </p>
                          </div>
                        </TableCell>

                        <TableCell>
                          <div className="min-w-[130px]">
                            <p className="font-medium">
                              {feedback.artifact_title ||
                                feedback.artifact_code}
                            </p>
                            <p className="text-xs text-muted-foreground">
                              {feedback.site_name}
                            </p>
                          </div>
                        </TableCell>

                        <TableCell>
                          <span className="whitespace-nowrap">
                            {feedback.rating}/5
                          </span>
                        </TableCell>

                        <TableCell>
                          <FeedbackStatusBadge status={feedback.status} />
                        </TableCell>

                        <TableCell className="whitespace-nowrap text-xs">
                          {formatFeedbackDate(feedback.created_at)}
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </div>

              {/* Pagination */}
              <div className="flex items-center justify-between border-t border-border/70 px-4 py-3">
                <span className="text-xs text-muted-foreground">
                  Page {page + 1} of {Math.max(totalPages, 1)}
                </span>

                <div className="flex gap-2">
                  <Button
                    variant="outline"
                    size="sm"
                    disabled={page === 0 || feedbackQuery.isFetching}
                    onClick={() => {
                      setPage((current) => current - 1)
                      setSelectedId(null)
                    }}
                  >
                    <ChevronLeft />
                    Previous
                  </Button>

                  <Button
                    variant="outline"
                    size="sm"
                    disabled={
                      page + 1 >= totalPages || feedbackQuery.isFetching
                    }
                    onClick={() => {
                      setPage((current) => current + 1)
                      setSelectedId(null)
                    }}
                  >
                    Next
                    <ChevronRight />
                  </Button>
                </div>
              </div>
            </>
          )}
        </ScreenCard>

        {/* Detail and moderation */}
        <div className="flex flex-col gap-4">
          <ScreenCard
            title="Submission Detail"
            icon={FileText}
            badge={selectedFeedback ? "Selected" : "No selection"}
          >
            {!selectedFeedback ? (
              <EmptyState
                title="Select a submission"
                description="Choose a feedback record to review its details."
                icon={FileText}
              />
            ) : (
              <div className="flex flex-col gap-4 p-4">
                <div className="flex flex-wrap items-start justify-between gap-2">
                  <div>
                    <p className="font-semibold">
                      {selectedFeedback.visitor_name || "Anonymous"}
                    </p>
                    <p className="text-sm text-muted-foreground">
                      {selectedFeedback.visitor_email}
                    </p>
                  </div>

                  <FeedbackStatusBadge status={selectedFeedback.status} />
                </div>

                <div className="grid gap-3 rounded-lg border border-border/70 p-3 sm:grid-cols-2">
                  <div>
                    <p className="text-xs text-muted-foreground">Artifact</p>
                    <p className="text-sm font-medium">
                      {selectedFeedback.artifact_title ||
                        selectedFeedback.artifact_code}
                    </p>
                    <p className="text-xs text-muted-foreground">
                      {selectedFeedback.artifact_code}
                    </p>
                  </div>

                  <div>
                    <p className="text-xs text-muted-foreground">Site</p>
                    <p className="text-sm font-medium">
                      {selectedFeedback.site_name}
                    </p>
                  </div>

                  <div>
                    <p className="text-xs text-muted-foreground">
                      Submitted at
                    </p>
                    <p className="text-sm">
                      {formatFeedbackDate(selectedFeedback.created_at)}
                    </p>
                  </div>

                  <div>
                    <p className="text-xs text-muted-foreground">Feedback ID</p>
                    <p className="break-all text-xs">{selectedFeedback.id}</p>
                  </div>
                </div>

                <div>
                  <p className="mb-2 text-xs font-medium text-muted-foreground">
                    Rating
                  </p>

                  <div className="flex items-center gap-1">
                    {Array.from({ length: 5 }).map((_, index) => (
                      <Star
                        key={index}
                        className={`size-5 ${
                          index < selectedFeedback.rating
                            ? "fill-yellow-400 text-yellow-400"
                            : "text-muted-foreground"
                        }`}
                      />
                    ))}

                    <span className="ml-2 text-sm font-medium">
                      {selectedFeedback.rating}/5
                    </span>
                  </div>
                </div>

                <div>
                  <p className="mb-2 text-xs font-medium text-muted-foreground">
                    Comment
                  </p>

                  <div className="min-h-20 whitespace-pre-wrap rounded-lg bg-muted/50 p-3 text-sm">
                    {selectedFeedback.comment || "No comment provided."}
                  </div>
                </div>
              </div>
            )}
          </ScreenCard>

          <Card className="gap-0 border-border/70 bg-card shadow-sm">
            <CardHeader className="border-b border-border/70 px-5 py-3">
              <CardTitle className="text-sm">Moderation actions</CardTitle>
            </CardHeader>

            <CardContent className="flex flex-wrap gap-2 p-4">
              <Button
                disabled={
                  selectedFeedback?.status === "approved" ||
                  !selectedFeedback ||
                  moderationMutation.isPending
                }
                onClick={() => handleModeration("approved")}
              >
                {moderationMutation.isPending &&
                moderationMutation.variables?.status === "approved"
                  ? "Approving..."
                  : "Approve"}
              </Button>

              <Button
                variant="destructive"
                disabled={
                  selectedFeedback?.status === "hidden" ||
                  !selectedFeedback ||
                  moderationMutation.isPending
                }
                onClick={() => handleModeration("hidden")}
              >
                {moderationMutation.isPending &&
                moderationMutation.variables?.status === "hidden"
                  ? "Hiding..."
                  : "Hide"}
              </Button>

              <Button
                variant="outline"
                disabled={
                  selectedFeedback?.status === "pending" ||
                  !selectedFeedback ||
                  moderationMutation.isPending
                }
                onClick={() => handleModeration("pending")}
              >
                {moderationMutation.isPending &&
                moderationMutation.variables?.status === "pending"
                  ? "Updating..."
                  : "Set as Pending"}
              </Button>
            </CardContent>
          </Card>

          {moderationMutation.isError && (
            <p className="text-sm text-destructive">
              {moderationMutation.error.message}
            </p>
          )}

          {moderationMutation.isSuccess && (
            <p className="text-sm text-muted-foreground">
              Feedback status updated successfully.
            </p>
          )}

          <p className="text-xs text-muted-foreground">
            Admin can change feedback status between Pending, Approved and
            Hidden. Only approved feedback is displayed publicly.
          </p>
        </div>
      </div>
    </div>
  )
}

export function VisitorsScreen() {
  return (
    <div className="flex flex-col gap-4 md:gap-5">
      <div className="flex flex-wrap items-center gap-2">
        <div className="relative min-w-[210px] flex-1 sm:max-w-xs">
          <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            className="pl-9"
            placeholder="Search visitors..."
            aria-label="Search visitors"
            disabled
          />
        </div>
        <DisabledFilter label="All sites" />
        <Badge variant="secondary">API pending</Badge>
      </div>
      <Card className="border-border/70 bg-card shadow-sm">
        <CardContent className="flex items-start gap-3 p-4">
          <CircleAlert className="mt-0.5 size-4 shrink-0 text-primary" />
          <div>
            <p className="text-sm font-semibold">
              Visitor records are not available
            </p>
            <p className="mt-1 text-xs text-muted-foreground">
              The current API does not expose visitor profiles, individual
              visits or interaction history.
            </p>
          </div>
        </CardContent>
      </Card>
      <div className="grid items-start gap-4 xl:grid-cols-[1.1fr_0.9fr]">
        <div className="flex flex-col gap-4">
          <ScreenCard
            title="Visitor Directory"
            icon={UsersRound}
            badge="No records"
          >
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Visitor</TableHead>
                    <TableHead>Feedback site</TableHead>
                    <TableHead>Submission</TableHead>
                    <TableHead>Date</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody />
              </Table>
            </div>
            <EmptyState
              title="No visitor records"
              description="Visitor data will appear when an approved visitor data source is connected."
              icon={UsersRound}
            />
          </ScreenCard>
          <ApiPendingCard
            title="Privacy & data context"
            description="Contact details and individual visit history require a defined data source and privacy scope."
          />
        </div>
        <div className="flex flex-col gap-4">
          <ScreenCard
            title="Visitor details"
            icon={UsersRound}
            badge="No selection"
          >
            <EmptyState
              title="Select a visitor"
              description="Visitor details are shown after a record is available."
              icon={UsersRound}
            />
          </ScreenCard>
          <ApiPendingCard
            title="Visit history & interactions"
            description="Visit timelines and content interactions are not available from the current API."
          />
        </div>
      </div>
    </div>
  )
}

export function NotificationsScreen() {
  const [filter, setFilter] = useState("All")
  return (
    <div className="flex flex-col gap-4 md:gap-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex gap-2">
          {["All", "Unread", "Read"].map((option) => (
            <Button
              key={option}
              variant={filter === option ? "default" : "outline"}
              size="sm"
              onClick={() => setFilter(option)}
            >
              {option}
            </Button>
          ))}
        </div>
        <Button
          variant="outline"
          disabled
          title="There are no notifications to update"
        >
          <Bell /> Mark all as read
        </Button>
      </div>
      <div className="grid items-start gap-4 xl:grid-cols-[1.4fr_0.7fr]">
        <ScreenCard title="Activity Inbox" icon={Bell} badge="0 unread">
          <EmptyState
            title={
              filter === "All"
                ? "No notifications available"
                : `No ${filter.toLocaleLowerCase()} notifications`
            }
            description="System alerts and read state are not available from the current API."
            icon={Bell}
          />
          <div className="border-t border-border/70 px-5 py-3 text-xs text-muted-foreground">
            Notification delivery and personal read state are waiting for an
            API.
          </div>
        </ScreenCard>
        <div className="flex flex-col gap-4">
          <ApiPendingCard
            title="At a glance"
            description="Connectivity, moderation and publication summaries are not available."
          />
          <Card className="gap-0 border-border/70 bg-card shadow-sm">
            <CardHeader className="border-b border-border/70 px-5 py-3">
              <CardTitle className="text-sm">Delivery preferences</CardTitle>
            </CardHeader>
            <CardContent className="p-5">
              <p className="text-sm text-muted-foreground">
                Choose which alerts and digests you receive in Account
                preferences.
              </p>
              <Button className="mt-4" variant="outline" disabled>
                Manage preferences
              </Button>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  )
}
