import { createFileRoute, Outlet, redirect } from "@tanstack/react-router"
import { AxiosError } from "axios"

import { UsersService } from "@/client"
import AppSidebar from "@/components/Sidebar/AppSidebar"
import { Topbar } from "@/components/Sidebar/Topbar"
import { SidebarInset, SidebarProvider } from "@/components/ui/sidebar"
import { isLoggedIn } from "@/hooks/useAuth"

export const Route = createFileRoute("/_layout")({
  component: Layout,
  beforeLoad: async () => {
    if (!isLoggedIn()) {
      throw redirect({ to: "/login" })
    }

    // A token in localStorage may be expired or rejected. Validate it before
    // rendering any page under the admin layout to avoid flashing protected UI.
    try {
      await UsersService.readUserMe({ throwOnError: true })
    } catch (error) {
      const status =
        error instanceof AxiosError
          ? error.response?.status
          : (error as { response?: { status?: number } }).response?.status
      if ([401, 403].includes(status ?? 0)) {
        localStorage.removeItem("access_token")
        throw redirect({ to: "/login" })
      }
      throw error
    }
  },
})

function Layout() {
  return (
    <SidebarProvider>
      <AppSidebar />
      <SidebarInset className="min-w-0 bg-background">
        <Topbar />
        <main className="min-w-0 flex-1 p-4 md:p-6">
          <Outlet />
        </main>
      </SidebarInset>
    </SidebarProvider>
  )
}
