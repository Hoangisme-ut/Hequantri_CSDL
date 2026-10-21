import { useQuery } from "@tanstack/react-query"
import { createFileRoute, redirect } from "@tanstack/react-router"
import { Shield, Users } from "lucide-react"
import { useMemo, useState } from "react"

import { type UserPublic, UsersService } from "@/client"
import AddUser from "@/components/Admin/AddUser"
import { columns, type UserTableData } from "@/components/Admin/columns"
import { ApiPendingCard, EmptyState, ErrorState } from "@/components/Common/AdminPrimitives"
import { DataTable } from "@/components/Common/DataTable"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Skeleton } from "@/components/ui/skeleton"
import useAuth from "@/hooks/useAuth"

export const Route = createFileRoute("/_layout/admin")({
  component: Admin,
  beforeLoad: async () => {
    const { data: user } = await UsersService.readUserMe()
    if (!user.is_superuser) throw redirect({ to: "/" })
  },
  head: () => ({ meta: [{ title: "Team & Roles - Smart Heritage" }] }),
})

function Admin() {
  const [search, setSearch] = useState("")
  const { user: currentUser } = useAuth()
  const usersQuery = useQuery({
    queryKey: ["users"],
    queryFn: async () => (await UsersService.readUsers({ query: { skip: 0, limit: 100 } })).data,
  })
  const users = usersQuery.data?.data ?? []
  const filteredUsers = useMemo(() => {
    const term = search.trim().toLocaleLowerCase()
    if (!term) return users
    return users.filter((user) => `${user.full_name ?? ""} ${user.email}`.toLocaleLowerCase().includes(term))
  }, [users, search])
  const tableData: UserTableData[] = filteredUsers.map((user: UserPublic) => ({
    ...user,
    isCurrentUser: currentUser?.id === user.id,
  }))

  return (
    <div className="flex flex-col gap-4 md:gap-5">
      <Card className="border-border/70 bg-card shadow-sm"><CardContent className="flex items-start gap-3 p-4"><Shield className="mt-0.5 size-4 shrink-0 text-primary" /><div><p className="text-sm font-semibold">Access fields supported by this API</p><p className="mt-1 text-xs text-muted-foreground">The current user model exposes only administrator and active flags. Site scope, invitations and granular roles are not available.</p></div></CardContent></Card>
      <Card className="gap-0 overflow-hidden border-border/70 bg-card shadow-sm">
        <CardHeader className="flex flex-col gap-3 border-b border-border/70 px-4 py-3 sm:flex-row sm:items-center sm:justify-between md:px-5">
          <CardTitle className="flex items-center gap-2 text-sm"><Users className="size-4 text-primary" />Staff directory {usersQuery.isSuccess && <span className="rounded-full bg-primary/15 px-2 py-0.5 text-[10px] text-primary">{users.length} accounts</span>}</CardTitle>
          <AddUser />
        </CardHeader>
        <CardContent className="grid gap-4 p-4 md:p-5">
          <div className="flex flex-wrap items-center gap-2"><Input value={search} onChange={(event) => setSearch(event.target.value)} className="h-9 max-w-xs" placeholder="Search staff..." aria-label="Search staff" /><span className="text-xs text-muted-foreground">Roles available: Administrator and User</span></div>
          <div className="overflow-x-auto">
            {usersQuery.isLoading ? <div className="space-y-3">{Array.from({ length: 4 }).map((_, index) => <Skeleton key={index} className="h-10 w-full" />)}</div> : usersQuery.isError ? <ErrorState description="The existing Users API could not be reached." onRetry={() => void usersQuery.refetch()} /> : users.length === 0 ? <EmptyState title="No user accounts" description="Create a user with the existing Users API." icon={Users} /> : <DataTable columns={columns} data={tableData} />}
          </div>
        </CardContent>
      </Card>
      <ApiPendingCard title="Role permission matrix" description="Editor/viewer roles, site scope, invitation lifecycle and permission policies are not represented by the current API." />
    </div>
  )
}
