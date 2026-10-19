import { createFileRoute } from "@tanstack/react-router"

import { BeaconManagementScreen } from "@/components/Admin/FeatureScreens"

export const Route = createFileRoute("/_layout/beacons")({
  component: BeaconManagementScreen,
  head: () => ({ meta: [{ title: "Beacon Management - Smart Heritage" }] }),
})
