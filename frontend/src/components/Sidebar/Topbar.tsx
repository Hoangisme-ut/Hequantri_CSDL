import { useQueryClient } from "@tanstack/react-query"
import { Link as RouterLink, useRouterState } from "@tanstack/react-router"
import { Bell, Moon, RefreshCw, Sun } from "lucide-react"

import { useTheme } from "@/components/theme-provider"
import { Avatar, AvatarFallback } from "@/components/ui/avatar"
import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { SidebarTrigger } from "@/components/ui/sidebar"
import useAuth from "@/hooks/useAuth"
import { getInitials } from "@/utils"

const pageDetails: Record<string, { title: string; subtitle: string }> = {
  "/": { title: "Overview", subtitle: "Smart Heritage administration" },
  "/sites": { title: "Site Management", subtitle: "Manage heritage sites" },
  "/items": {
    title: "Artifact Management",
    subtitle: "Manage the artifact catalog",
  },
  "/beacons": {
    title: "Beacon Management",
    subtitle: "Monitor and assign beacons",
  },
  "/analytics": {
    title: "Analytics & Reports",
    subtitle: "Explore visitor and content activity",
  },
  "/feedback": {
    title: "Feedback Review",
    subtitle: "Review visitor submissions",
  },
  "/visitors": {
    title: "Visitors",
    subtitle: "Visitor records and heritage interactions",
  },
  "/notifications": {
    title: "Notifications",
    subtitle: "System alerts and updates",
  },
  "/account": {
    title: "Account",
    subtitle: "Your profile, security and personal preferences",
  },
  "/settings": { title: "Settings", subtitle: "Organisation settings" },
  "/admin": {
    title: "Team & Roles",
    subtitle: "Manage staff access and role permissions",
  },
}

export function Topbar({ preview = false }: { preview?: boolean }) {
  const pathname = useRouterState({
    select: (state) => state.location.pathname,
  })
  const queryClient = useQueryClient()
  const { user: authenticatedUser, logout } = useAuth({ enabled: !preview })
  const user = preview
    ? { full_name: "Alex Morgan", email: "alex.morgan@example.org · DEMO" }
    : authenticatedUser
  const { resolvedTheme, setTheme } = useTheme()
  const normalisedPath = preview
    ? pathname.replace(/^\/preview/, "") || "/"
    : pathname
  const previewAliases: Record<string, string> = {
    "/artifacts": "/items",
    "/team": "/admin",
  }
  const page =
    pageDetails[previewAliases[normalisedPath] ?? normalisedPath] ??
    (normalisedPath.startsWith("/sites/") || normalisedPath === "/edit-site"
      ? { title: "Site Details", subtitle: "Manage heritage site information" }
      : pageDetails["/"])
  const initials = getInitials(user?.full_name || user?.email || "Admin")

  return (
    <header className="sticky top-0 z-20 flex min-h-16 items-center justify-between gap-4 border-b border-border/70 bg-background/95 px-3 backdrop-blur supports-[backdrop-filter]:bg-background/85 md:px-6">
      <div className="flex min-w-0 items-center gap-3">
        <SidebarTrigger className="size-8 shrink-0 text-muted-foreground" />
        <div className="min-w-0">
          <h1 className="truncate text-lg font-semibold leading-tight md:text-xl">
            {page.title}
          </h1>
          <p className="truncate text-xs text-muted-foreground md:text-[13px]">
            {page.subtitle}
          </p>
        </div>
      </div>
      <div className="flex shrink-0 items-center gap-2">
        <Button
          asChild
          variant="ghost"
          size="icon"
          className="size-9 rounded-lg bg-sidebar-accent/70 text-muted-foreground hover:text-foreground"
          aria-label="Notifications"
        >
          <RouterLink
            to={
              (preview ? "/preview/notifications" : "/notifications") as never
            }
          >
            <Bell className="size-[18px]" />
          </RouterLink>
        </Button>
        <Button
          type="button"
          variant="ghost"
          size="icon"
          className="size-9 rounded-lg bg-sidebar-accent/70 text-muted-foreground hover:text-foreground"
          aria-label="Refresh data"
          onClick={() => void queryClient.invalidateQueries()}
        >
          <RefreshCw className="size-[17px]" />
        </Button>
        <Button
          type="button"
          variant="ghost"
          size="icon"
          className="size-9 rounded-lg bg-sidebar-accent/70 text-muted-foreground hover:text-foreground"
          aria-label="Toggle appearance"
          onClick={() => setTheme(resolvedTheme === "dark" ? "light" : "dark")}
        >
          {resolvedTheme === "dark" ? (
            <Sun className="size-[17px]" />
          ) : (
            <Moon className="size-[17px]" />
          )}
        </Button>
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button
              variant="ghost"
              className="size-9 rounded-full bg-primary p-0 text-sm font-semibold text-primary-foreground hover:bg-primary/90"
              aria-label="Open account menu"
            >
              <Avatar className="size-9">
                <AvatarFallback className="bg-primary text-primary-foreground">
                  {initials}
                </AvatarFallback>
              </Avatar>
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end" className="w-56">
            <div className="px-2 py-1.5">
              <p className="truncate text-sm font-medium">
                {user?.full_name || "Administrator"}
              </p>
              <p className="truncate text-xs text-muted-foreground">
                {user?.email}
              </p>
            </div>
            <DropdownMenuSeparator />
            <DropdownMenuItem asChild>
              <RouterLink
                to={(preview ? "/preview/account" : "/account") as never}
              >
                Account settings
              </RouterLink>
            </DropdownMenuItem>
            {preview ? (
              <DropdownMenuItem disabled>DEMO preview</DropdownMenuItem>
            ) : (
              <DropdownMenuItem onClick={logout}>Log out</DropdownMenuItem>
            )}
          </DropdownMenuContent>
        </DropdownMenu>
      </div>
    </header>
  )
}
