import { createFileRoute, Outlet, redirect } from "@tanstack/react-router"

import AppSidebar from "@/components/Sidebar/AppSidebar"
import { Topbar } from "@/components/Sidebar/Topbar"
import { Badge } from "@/components/ui/badge"
import { SidebarInset, SidebarProvider } from "@/components/ui/sidebar"

export const Route = createFileRoute("/preview")({
  beforeLoad: () => {
    if (!import.meta.env.DEV) throw redirect({ to: "/login" })
  },
  component: PreviewLayout,
})

function PreviewLayout() {
  return (
    <SidebarProvider>
      <AppSidebar preview />
      <SidebarInset className="min-w-0 bg-background">
        <Topbar preview />
        <main className="min-w-0 flex-1 space-y-4 p-4 md:p-6">
          <div className="flex items-center justify-between rounded-lg border border-amber-500/30 bg-amber-500/10 px-4 py-2 text-sm">
            <span className="text-muted-foreground">Preview workspace · all records below are illustrative and are not connected to the backend.</span>
            <Badge className="bg-amber-500 text-slate-950 hover:bg-amber-500">DEMO</Badge>
          </div>
          <Outlet />
        </main>
      </SidebarInset>
    </SidebarProvider>
  )
}
