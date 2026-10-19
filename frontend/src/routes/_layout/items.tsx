import { useQuery } from "@tanstack/react-query"
import { createFileRoute } from "@tanstack/react-router"
import { Archive, Filter, Search } from "lucide-react"
import { useMemo, useState } from "react"

import { ItemsService } from "@/client"
import { EmptyState, ErrorState, MetricCard } from "@/components/Common/AdminPrimitives"
import { DataTable } from "@/components/Common/DataTable"
import { columns } from "@/components/Items/columns"
import AddItem from "@/components/Items/AddItem"
import { Input } from "@/components/ui/input"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Skeleton } from "@/components/ui/skeleton"

export const Route = createFileRoute("/_layout/items")({
  component: Items,
  head: () => ({ meta: [{ title: "Artifact Management - Smart Heritage" }] }),
})

function Items() {
  const [search, setSearch] = useState("")
  const itemsQuery = useQuery({
    queryKey: ["items"],
    queryFn: async () => (await ItemsService.readItems({ query: { skip: 0, limit: 100 } })).data,
  })
  const items = itemsQuery.data?.data ?? []
  const filteredItems = useMemo(() => {
    const term = search.trim().toLocaleLowerCase()
    if (!term) return items
    return items.filter((item) => `${item.title} ${item.description ?? ""} ${item.id}`.toLocaleLowerCase().includes(term))
  }, [items, search])

  return (
    <div className="flex flex-col gap-4 md:gap-5">
      <section className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4" aria-label="Artifact metrics">
        {itemsQuery.isLoading ? <Skeleton className="h-28 rounded-xl" /> : <MetricCard label="Total" value={itemsQuery.isError ? "—" : items.length} detail="Records from Items API" icon={Archive} />}
        <MetricCard label="Published" value="—" detail="Not in current Item schema" icon={Archive} />
        <MetricCard label="Draft" value="—" detail="Not in current Item schema" icon={Archive} />
        <MetricCard label="Sites" value="—" detail="Waiting for sites API" icon={Archive} />
      </section>

      <Card className="gap-0 overflow-hidden border-border/70 bg-card shadow-sm">
        <CardHeader className="flex flex-col gap-3 border-b border-border/70 px-4 py-3 sm:flex-row sm:items-center sm:justify-between md:px-5">
          <CardTitle className="flex items-center gap-2 text-sm"><Archive className="size-4 text-primary" />Artifacts <span className="rounded-full bg-primary/15 px-2 py-0.5 text-[10px] font-medium text-primary">{itemsQuery.isSuccess ? `${items.length} records` : ""}</span></CardTitle>
          <div className="flex flex-wrap items-center gap-2">
            <div className="relative min-w-[180px] flex-1 sm:max-w-[230px]">
              <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
              <Input value={search} onChange={(event) => setSearch(event.target.value)} className="h-9 pl-9" placeholder="Search artifacts..." aria-label="Search artifacts" />
            </div>
            <Button variant="outline" disabled title="Site data is not available"><Filter /> All sites</Button>
            <Button variant="outline" disabled title="Publication status is not part of the current Item schema"><Filter /> All status</Button>
            <AddItem />
          </div>
        </CardHeader>
        <CardContent className="overflow-x-auto p-0">
          {itemsQuery.isLoading ? (
            <div className="space-y-3 p-5">{Array.from({ length: 5 }).map((_, index) => <Skeleton key={index} className="h-10 w-full" />)}</div>
          ) : itemsQuery.isError ? (
            <ErrorState description="The existing Items API could not be reached." onRetry={() => void itemsQuery.refetch()} />
          ) : items.length === 0 ? (
            <EmptyState title="No artifacts yet" description="Add an artifact using the existing Items API to get started." icon={Archive} />
          ) : (
            <DataTable columns={columns} data={filteredItems} />
          )}
        </CardContent>
      </Card>
      <p className="text-xs text-muted-foreground">The current API supports only an item ID, title and description. Site, beacon, media, publication and translation fields are not connected.</p>
    </div>
  )
}
