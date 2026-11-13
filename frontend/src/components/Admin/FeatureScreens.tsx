import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import {
  Archive,
  Bell,
  CalendarDays,
  ChartNoAxesColumnIncreasing,
  ChevronLeft,
  ChevronRight,
  CircleAlert,
  FileText,
  Filter,
  MessageSquare,
  Search,
  Star,
  UsersRound,
} from "lucide-react"
import { useState } from "react"
import type { FeedbackReviewPublic, FeedbackStatus } from "@/client"
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

export function AnalyticsScreen() {
  return (
    <div className="flex flex-col gap-4 md:gap-5">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div className="flex flex-wrap items-center gap-2">
          <Button variant="outline" disabled>
            <CalendarDays /> Date range unavailable
          </Button>
          <DisabledFilter label="All sites" />
          <Button disabled>Apply</Button>
          <Button variant="outline" disabled>
            Reset
          </Button>
        </div>
        <div className="flex gap-2">
          <Button variant="outline" disabled>
            Export PDF
          </Button>
          <Button variant="outline" disabled>
            Export Excel
          </Button>
        </div>
      </div>
      <section className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <MetricCard
          label="Total visits"
          value="—"
          detail="Waiting for analytics API"
          icon={UsersRound}
        />
        <MetricCard
          label="Artifact views"
          value="—"
          detail="Waiting for analytics API"
          icon={Archive}
        />
        <MetricCard
          label="Interactions"
          value="—"
          detail="Waiting for analytics API"
          icon={ChartNoAxesColumnIncreasing}
        />
        <MetricCard
          label="Content views"
          value="—"
          detail="Waiting for analytics API"
          icon={FileText}
        />
      </section>
      <div className="grid gap-4 xl:grid-cols-[1.35fr_0.85fr]">
        <ScreenCard
          title="Daily visits"
          icon={ChartNoAxesColumnIncreasing}
          badge="No data source"
        >
          <EmptyState
            title="Analytics are not available"
            description="No visits, daily values or reporting period can be loaded from the current API."
            icon={ChartNoAxesColumnIncreasing}
          />
        </ScreenCard>
        <ApiPendingCard
          title="Content views by category"
          description="Category totals require confirmed analytics events and content categories."
        />
      </div>
      <div className="grid gap-4 xl:grid-cols-[1.5fr_0.7fr]">
        <ScreenCard
          title="Performance by Site"
          icon={CalendarDays}
          badge="API pending"
        >
          <div className="overflow-x-auto">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Site name</TableHead>
                  <TableHead>Visits</TableHead>
                  <TableHead>Content views</TableHead>
                  <TableHead>Interactions</TableHead>
                  <TableHead>Artifact views</TableHead>
                  <TableHead>Visit share</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody />
            </Table>
          </div>
          <EmptyState
            title="No site analytics available"
            description="Site-level metrics will appear when an analytics API is available."
            icon={CalendarDays}
          />
        </ScreenCard>
        <ApiPendingCard
          title="Inventory Summary"
          description="Verified site, artifact and beacon totals are not available for reporting."
        />
      </div>
    </div>
  )
}

type ModerationStatus = "approved" | "hidden"

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
  const [statusFilter, setStatusFilter] = useState<
    "all" | FeedbackStatus
  >("all")
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
    mutationFn: ({ id, status }: { id: string; status: ModerationStatus }) =>
      feedbackService.updateStatus(id, { status }),

    onSuccess: async () => {
      await queryClient.invalidateQueries({
        queryKey: feedbackKeys.all,
      })
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

  function handleFilterChange(value: "all" | FeedbackStatus) {
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
                  selectedFeedback?.status !== "pending" ||
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
                  selectedFeedback?.status !== "pending" ||
                  moderationMutation.isPending
                }
                onClick={() => handleModeration("hidden")}
              >
                {moderationMutation.isPending &&
                moderationMutation.variables?.status === "hidden"
                  ? "Hiding..."
                  : "Hide"}
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
              Only pending submissions can be approved or hidden. Hidden
              submissions are not displayed publicly.
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
