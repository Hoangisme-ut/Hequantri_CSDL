import type { LucideIcon } from "lucide-react"
import { CircleHelp, Database, Inbox } from "lucide-react"

import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"

export function MetricCard({
  label,
  value,
  detail,
  icon: Icon,
}: {
  label: string
  value: React.ReactNode
  detail?: string
  icon: LucideIcon
}) {
  return (
    <Card className="gap-3 border-border/70 bg-card shadow-sm">
      <CardContent className="flex items-start justify-between gap-3 p-4 md:p-5">
        <div className="min-w-0">
          <p className="text-[10px] font-semibold uppercase tracking-[0.12em] text-muted-foreground">{label}</p>
          <p className="mt-1 text-2xl font-bold tracking-tight">{value}</p>
          {detail && <p className="mt-1 truncate text-xs text-muted-foreground">{detail}</p>}
        </div>
        <span className="flex size-9 shrink-0 items-center justify-center rounded-lg bg-primary/15 text-primary"><Icon className="size-[18px]" /></span>
      </CardContent>
    </Card>
  )
}

export function EmptyState({
  title,
  description,
  icon: Icon = Inbox,
  action,
}: {
  title: string
  description: string
  icon?: LucideIcon
  action?: React.ReactNode
}) {
  return (
    <div className="flex min-h-52 flex-col items-center justify-center px-6 py-10 text-center">
      <span className="mb-3 flex size-11 items-center justify-center rounded-full bg-muted text-muted-foreground"><Icon className="size-5" /></span>
      <h3 className="font-semibold">{title}</h3>
      <p className="mt-1 max-w-md text-sm text-muted-foreground">{description}</p>
      {action && <div className="mt-4">{action}</div>}
    </div>
  )
}

export function ApiPendingCard({
  title,
  description,
}: {
  title: string
  description: string
}) {
  return (
    <Card className="gap-0 border-border/70 bg-card shadow-sm">
      <CardHeader className="flex flex-row items-center justify-between gap-3 border-b border-border/70 px-5 py-3">
        <CardTitle className="text-sm font-semibold">{title}</CardTitle>
        <Badge variant="secondary" className="gap-1 text-[10px]"><CircleHelp className="size-3" /> API pending</Badge>
      </CardHeader>
      <CardContent className="p-0">
        <EmptyState title="Waiting for a confirmed data source" description={description} icon={Database} />
      </CardContent>
    </Card>
  )
}

export function ErrorState({
  title = "Couldn't load this information",
  description = "Check your connection and try again.",
  onRetry,
}: {
  title?: string
  description?: string
  onRetry?: () => void
}) {
  return (
    <div className="flex min-h-44 flex-col items-center justify-center px-6 py-8 text-center">
      <p className="font-semibold">{title}</p>
      <p className="mt-1 text-sm text-muted-foreground">{description}</p>
      {onRetry && <Button className="mt-4" variant="outline" onClick={onRetry}>Try again</Button>}
    </div>
  )
}
