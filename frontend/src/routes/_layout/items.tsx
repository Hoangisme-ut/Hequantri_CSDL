import { createFileRoute } from "@tanstack/react-router"

import { ArtifactManagement } from "@/components/Artifacts/ArtifactManagement"

export const Route = createFileRoute("/_layout/items")({
  component: ArtifactManagement,
  head: () => ({ meta: [{ title: "Artifact Management - Smart Heritage" }] }),
})
