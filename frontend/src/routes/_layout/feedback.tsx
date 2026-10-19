import { createFileRoute } from "@tanstack/react-router"

import { FeedbackScreen } from "@/components/Admin/FeatureScreens"

export const Route = createFileRoute("/_layout/feedback")({
  component: FeedbackScreen,
  head: () => ({ meta: [{ title: "Feedback Review - Smart Heritage" }] }),
})
