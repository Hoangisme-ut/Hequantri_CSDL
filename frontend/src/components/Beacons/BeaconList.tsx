
import { Pencil, Radio, Trash2 } from "lucide-react"

import type { BeaconPublic } from "@/client"
import type { Site } from "@/services/sites"

import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { EmptyState } from "@/components/Common/AdminPrimitives"

interface BeaconListProps {
  beacons: BeaconPublic[]
  sites: Site[]
  artifactLabels: Record<string, string>
  isLoading?: boolean
  onEdit: (beacon: BeaconPublic) => void
  onDeactivate: (beacon: BeaconPublic) => void
  deactivatingBeaconId?: string | null
}

function formatLastSeen(value?: string | null) {
  if (!value) return "Never"

  const date = new Date(value)

  if (Number.isNaN(date.getTime())) return value

  return date.toLocaleString()
}

function formatBattery(value?: number | null) {
  if (value == null) return "Unknown"
  return `${value}%`
}

export function BeaconList({
  beacons,
  sites,
  artifactLabels,
  isLoading = false,
  onEdit,
  onDeactivate,
  deactivatingBeaconId = null,
}: BeaconListProps) {
  const siteNames = new Map(
    sites.map((site) => [site.id, site.name]),
  )

  if (isLoading) {
    return (
      <div className="p-8 text-center text-sm text-muted-foreground">
        Loading beacons...
      </div>
    )
  }

  if (beacons.length === 0) {
    return (
      <EmptyState
        title="No beacons found"
        description="Add a beacon or adjust your search and filters."
        icon={Radio}
      />
    )
  }

  return (
    <div className="overflow-x-auto">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Proximity UUID</TableHead>
            <TableHead>Major / Minor</TableHead>
            <TableHead>Site</TableHead>
            <TableHead>Artifact</TableHead>
            <TableHead>Battery</TableHead>
            <TableHead>Last seen</TableHead>
            <TableHead>Status</TableHead>
            <TableHead className="text-right">Actions</TableHead>
          </TableRow>
        </TableHeader>

        <TableBody>
          {beacons.map((beacon) => {
            const isActive = beacon.is_active ?? false
            const isDeactivating =
              deactivatingBeaconId === beacon.id

            return (
              <TableRow key={beacon.id}>
                <TableCell
                  className="max-w-[220px] truncate font-mono text-xs"
                  title={beacon.proximity_uuid}
                >
                  {beacon.proximity_uuid}
                </TableCell>

                <TableCell className="whitespace-nowrap">
                  {beacon.major} / {beacon.minor}
                </TableCell>

                <TableCell>
                  {siteNames.get(beacon.site_id) ?? (
                    <span className="text-muted-foreground">
                      Unknown site
                    </span>
                  )}
                </TableCell>

                <TableCell>
                  {beacon.artifact_id ? (
                    artifactLabels[beacon.artifact_id] ?? (
                      <span className="text-muted-foreground">
                        Artifact {beacon.artifact_id}
                      </span>
                    )
                  ) : (
                    <span className="text-muted-foreground">
                      Unassigned
                    </span>
                  )}
                </TableCell>

                <TableCell>
                  {formatBattery(beacon.battery_level)}
                </TableCell>

                <TableCell className="whitespace-nowrap text-sm text-muted-foreground">
                  {formatLastSeen(beacon.last_seen_at)}
                </TableCell>

                <TableCell>
                  <Badge
                    variant={isActive ? "default" : "secondary"}
                  >
                    {isActive ? "Active" : "Inactive"}
                  </Badge>
                </TableCell>

                <TableCell>
                  <div className="flex justify-end gap-1">
                    <Button
                      type="button"
                      variant="ghost"
                      size="icon"
                      aria-label="Edit beacon"
                      title="Edit beacon"
                      onClick={() => onEdit(beacon)}
                    >
                      <Pencil className="size-4" />
                    </Button>

                    {isActive && (
                      <Button
                        type="button"
                        variant="ghost"
                        size="icon"
                        aria-label="Deactivate beacon"
                        title="Deactivate beacon"
                        disabled={isDeactivating}
                        onClick={() => onDeactivate(beacon)}
                      >
                        <Trash2 className="size-4 text-destructive" />
                      </Button>
                    )}
                  </div>
                </TableCell>
              </TableRow>
            )
          })}
        </TableBody>
      </Table>
    </div>
  )
}
