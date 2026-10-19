import { createFileRoute } from "@tanstack/react-router"

import { PreviewScreen, type PreviewScreenName } from "@/components/Admin/PreviewScreen"

export const Route = createFileRoute("/preview/$screen")({
  component: ScreenRoute,
})

function ScreenRoute() {
  const { screen } = Route.useParams()
  return <PreviewScreen screen={screen as PreviewScreenName} />
}
