import {
  Archive,
  Bell,
  ChartNoAxesColumnIncreasing,
  CircleHelp,
  MapPin,
  MessageSquare,
  Radio,
  Settings,
  UsersRound,
  Users,
  UserCircle,
} from "lucide-react"

import { Logo } from "@/components/Common/Logo"
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarHeader,
} from "@/components/ui/sidebar"
import useAuth from "@/hooks/useAuth"
import { type Item, Main } from "./Main"
import { User } from "./User"

const navItems: Item[] = [
  { icon: ChartNoAxesColumnIncreasing, title: "Overview", path: "/", section: "Navigation" },
  { icon: MapPin, title: "Site Management", path: "/sites", section: "Navigation" },
  { icon: Archive, title: "Artifact Management", path: "/items", section: "Navigation" },
  { icon: Radio, title: "Beacon Management", path: "/beacons", section: "Navigation" },
  { icon: ChartNoAxesColumnIncreasing, title: "Analytics & Reports", path: "/analytics", section: "Navigation" },
  { icon: MessageSquare, title: "Feedback Review", path: "/feedback", section: "Navigation" },
  { icon: UsersRound, title: "Visitors", path: "/visitors", section: "Navigation" },
]

const adminItems: Item[] = [
  { icon: Users, title: "Team & Roles", path: "/admin", section: "Administration" },
  { icon: Settings, title: "Settings", path: "/settings", section: "Administration" },
  { icon: CircleHelp, title: "Help & Documentation", path: "#help", section: "Administration", disabled: true },
]

const previewItems: Item[] = [
  { icon: ChartNoAxesColumnIncreasing, title: "Overview", path: "/preview", section: "Navigation" },
  { icon: MapPin, title: "Site Management", path: "/preview/sites", section: "Navigation" },
  { icon: MapPin, title: "Edit Site", path: "/preview/edit-site", section: "Navigation" },
  { icon: Archive, title: "Artifact Management", path: "/preview/artifacts", section: "Navigation" },
  { icon: Radio, title: "Beacon Management", path: "/preview/beacons", section: "Navigation" },
  { icon: ChartNoAxesColumnIncreasing, title: "Analytics & Reports", path: "/preview/analytics", section: "Navigation" },
  { icon: MessageSquare, title: "Feedback Review", path: "/preview/feedback", section: "Navigation" },
  { icon: UsersRound, title: "Visitors", path: "/preview/visitors", section: "Navigation" },
  { icon: Bell, title: "Notifications", path: "/preview/notifications", section: "Navigation" },
  { icon: Users, title: "Team & Roles", path: "/preview/team", section: "Administration" },
  { icon: Settings, title: "Settings", path: "/preview/settings", section: "Administration" },
  { icon: UserCircle, title: "Account", path: "/preview/account", section: "Administration" },
]

export function AppSidebar({ preview = false }: { preview?: boolean }) {
  const { user: authenticatedUser } = useAuth({ enabled: !preview })
  const currentUser = preview
    ? { full_name: "Alex Morgan", email: "alex.morgan@example.org · DEMO", is_superuser: true }
    : authenticatedUser

  const items = preview ? previewItems : currentUser?.is_superuser ? [...navItems, ...adminItems] : navItems

  return (
    <Sidebar collapsible="icon" className="border-r-0">
      <SidebarHeader className="px-4 py-4 group-data-[collapsible=icon]:px-0 group-data-[collapsible=icon]:items-center">
        <Logo variant="responsive" />
      </SidebarHeader>
      <SidebarContent>
        <Main items={items} />
      </SidebarContent>
      <SidebarFooter className="border-t border-sidebar-border px-2 py-3">
        <User user={currentUser} preview={preview} />
      </SidebarFooter>
    </Sidebar>
  )
}

export default AppSidebar
