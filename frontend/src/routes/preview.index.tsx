import { createFileRoute } from "@tanstack/react-router"
import { PreviewScreen } from "@/components/Admin/PreviewScreen"

export const Route = createFileRoute("/preview/")({
  component: () => <PreviewScreen screen="overview" />,
})
