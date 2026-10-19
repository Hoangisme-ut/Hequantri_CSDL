import { createFileRoute } from "@tanstack/react-router"

import { NotificationsScreen } from "@/components/Admin/FeatureScreens"

export const Route = createFileRoute("/_layout/notifications")({
  component: NotificationsScreen,
  head: () => ({ meta: [{ title: "Notifications - Smart Heritage" }] }),
})
