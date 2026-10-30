import { Link as RouterLink, useRouterState } from "@tanstack/react-router"
import type { LucideIcon } from "lucide-react"

import {
  SidebarGroup,
  SidebarGroupContent,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  useSidebar,
} from "@/components/ui/sidebar"

export type Item = {
  icon: LucideIcon
  title: string
  path: string
  section?: string
  disabled?: boolean
}

interface MainProps {
  items: Item[]
}

export function Main({ items }: MainProps) {
  const { isMobile, setOpenMobile } = useSidebar()
  const router = useRouterState()
  const currentPath = router.location.pathname

  const handleMenuClick = () => {
    if (isMobile) {
      setOpenMobile(false)
    }
  }

  const sections = [
    ...new Set(items.map((item) => item.section ?? "Navigation")),
  ]

  return sections.map((section) => (
    <SidebarGroup key={section} className="px-3 py-2">
      <p className="px-2 pb-2 text-[10px] font-semibold uppercase tracking-[0.16em] text-sidebar-foreground/55 group-data-[collapsible=icon]:hidden">
        {section}
      </p>
      <SidebarGroupContent>
        <SidebarMenu>
          {items
            .filter((item) => (item.section ?? "Navigation") === section)
            .map((item) => {
              const isActive =
                currentPath === item.path ||
                (item.path !== "/" &&
                  item.path !== "/preview" &&
                  currentPath.startsWith(item.path))
              return (
                <SidebarMenuItem key={item.title}>
                  <SidebarMenuButton
                    tooltip={item.title}
                    isActive={isActive}
                    disabled={item.disabled}
                    className="h-9 rounded-lg px-3 text-[13px] text-sidebar-foreground/80 data-[active=true]:bg-sidebar-primary data-[active=true]:text-sidebar-primary-foreground data-[active=true]:shadow-sm hover:bg-sidebar-accent hover:text-sidebar-accent-foreground"
                    asChild={!item.disabled}
                  >
                    {item.disabled ? (
                      <span>
                        <item.icon />
                        <span>{item.title}</span>
                      </span>
                    ) : (
                      <RouterLink
                        to={item.path as never}
                        onClick={handleMenuClick}
                      >
                        <item.icon />
                        <span>{item.title}</span>
                      </RouterLink>
                    )}
                  </SidebarMenuButton>
                </SidebarMenuItem>
              )
            })}
        </SidebarMenu>
      </SidebarGroupContent>
    </SidebarGroup>
  ))
}
