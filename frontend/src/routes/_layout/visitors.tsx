import { createFileRoute } from "@tanstack/react-router"

import { VisitorsScreen } from "@/components/Admin/FeatureScreens"

export const Route = createFileRoute("/_layout/visitors")({
  component: VisitorsScreen,
  head: () => ({ meta: [{ title: "Visitors - Smart Heritage" }] }),
})
