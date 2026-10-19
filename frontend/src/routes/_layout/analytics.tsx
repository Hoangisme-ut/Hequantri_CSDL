import { createFileRoute } from "@tanstack/react-router"

import { AnalyticsScreen } from "@/components/Admin/FeatureScreens"

export const Route = createFileRoute("/_layout/analytics")({
  component: AnalyticsScreen,
  head: () => ({ meta: [{ title: "Analytics & Reports - Smart Heritage" }] }),
})
