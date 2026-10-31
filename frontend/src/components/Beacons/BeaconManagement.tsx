import { useMemo, useState } from "react"
import {
  useMutation,
  useQuery,
  useQueryClient,
} from "@tanstack/react-query"
import {
  AlertCircle,
  Plus,
  Radio,
  Search,
  Unlink,
  Wifi,
  WifiOff,
} from "lucide-react"
import { toast } from "sonner"

import type { BeaconCreate, BeaconPublic } from "@/client"
import BeaconForm from "./BeaconForm"
import { BeaconList } from "./BeaconList"

import { beaconsService, beaconKeys } from "@/services/beacon"
import { sitesService } from "@/services/sites"
import { artifactsService } from "@/services/artifacts"

import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"

type StatusFilter = "all" | "active" | "inactive" | "unassigned"

interface StatCardProps {
  title: string
  value: number
  description: string
  icon: React.ReactNode
}

function StatCard({
  title,
  value,
  description,
  icon,
}: StatCardProps) {
  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle className="text-sm font-medium text-muted-foreground">
          {title}
        </CardTitle>
        <div className="text-muted-foreground">{icon}</div>
      </CardHeader>

      <CardContent>
        <div className="text-2xl font-bold">{value}</div>
        <p className="mt-1 text-xs text-muted-foreground">
          {description}
        </p>
      </CardContent>
    </Card>
  )
}

export function BeaconManagement() {
  const queryClient = useQueryClient()

  const [searchTerm, setSearchTerm] = useState("")
  const [statusFilter, setStatusFilter] =
    useState<StatusFilter>("all")
  const [isDialogOpen, setIsDialogOpen] = useState(false)
  const [editingBeacon, setEditingBeacon] =
    useState<BeaconPublic | null>(null)

  // Load Beacon list
  const beaconsQuery = useQuery({
    queryKey: beaconKeys.list({ skip: 0, limit: 200 }),
    queryFn: () =>
      beaconsService.list({ skip: 0, limit: 200 }),
  })

  // Load Sites for displaying Site names
  const sitesQuery = useQuery({
    queryKey: ["sites", "beacon-management"],
    queryFn: () => sitesService.list(),
  })

  // Load Artifacts for displaying Artifact names
  const artifactsQuery = useQuery({
    queryKey: ["artifacts", "beacon-management"],
    queryFn: () =>
      artifactsService.list({
        skip: 0,
        limit: 200,
        include_inactive: true,
      }),
  })

  const beacons = beaconsQuery.data?.data ?? []
  const sites = sitesQuery.data?.data ?? []
  const artifacts = artifactsQuery.data?.data ?? []

  const siteNames = useMemo(() => {
    return Object.fromEntries(
      sites.map((site) => [site.id, site.name]),
    )
  }, [sites])

  const artifactLabels = useMemo(() => {
    return Object.fromEntries(
      artifacts.map((artifact) => [
        artifact.id,
        artifact.title || artifact.code,
      ]),
    )
  }, [artifacts])

  // Statistics
  const statistics = useMemo(() => {
    return {
      total: beacons.length,
      active: beacons.filter((beacon) => beacon.is_active).length,
      inactive: beacons.filter((beacon) => !beacon.is_active).length,
      unassigned: beacons.filter(
        (beacon) => !beacon.artifact_id,
      ).length,
    }
  }, [beacons])

  // Search and filter
  const filteredBeacons = useMemo(() => {
    const keyword = searchTerm.trim().toLowerCase()

    return beacons.filter((beacon) => {
      const siteName =
        siteNames[beacon.site_id]?.toLowerCase() ?? ""

      const artifactName = beacon.artifact_id
        ? artifactLabels[beacon.artifact_id]?.toLowerCase() ?? ""
        : ""

      const matchesSearch =
        !keyword ||
        beacon.proximity_uuid.toLowerCase().includes(keyword) ||
        String(beacon.major).includes(keyword) ||
        String(beacon.minor).includes(keyword) ||
        siteName.includes(keyword) ||
        artifactName.includes(keyword)

      const matchesStatus =
        statusFilter === "all" ||
        (statusFilter === "active" && beacon.is_active) ||
        (statusFilter === "inactive" && !beacon.is_active) ||
        (statusFilter === "unassigned" && !beacon.artifact_id)

      return matchesSearch && matchesStatus
    })
  }, [
    beacons,
    searchTerm,
    statusFilter,
    siteNames,
    artifactLabels,
  ])

  // Create Beacon
  const createMutation = useMutation({
    mutationFn: (input: BeaconCreate) =>
      beaconsService.create(input),
    onSuccess: async () => {
      await queryClient.invalidateQueries({
        queryKey: beaconKeys.all,
      })
      toast.success("Beacon created successfully.")
      closeDialog()
    },
    onError: (error) => {
      toast.error(
        error instanceof Error
          ? error.message
          : "Failed to create Beacon.",
      )
    },
  })

  // Update Beacon
  const updateMutation = useMutation({
    mutationFn: ({
      beaconId,
      input,
    }: {
      beaconId: string
      input: BeaconCreate
    }) => beaconsService.update(beaconId, input),
    onSuccess: async () => {
      await queryClient.invalidateQueries({
        queryKey: beaconKeys.all,
      })
      toast.success("Beacon updated successfully.")
      closeDialog()
    },
    onError: (error) => {
      toast.error(
        error instanceof Error
          ? error.message
          : "Failed to update Beacon.",
      )
    },
  })

  // Deactivate Beacon
  const deactivateMutation = useMutation({
    mutationFn: (beaconId: string) =>
      beaconsService.deactivate(beaconId),
    onSuccess: async () => {
      await queryClient.invalidateQueries({
        queryKey: beaconKeys.all,
      })
      toast.success("Beacon deactivated successfully.")
    },
    onError: (error) => {
      toast.error(
        error instanceof Error
          ? error.message
          : "Failed to deactivate Beacon.",
      )
    },
  })

  function closeDialog() {
    setIsDialogOpen(false)
    setEditingBeacon(null)
  }

  function openCreateDialog() {
    setEditingBeacon(null)
    setIsDialogOpen(true)
  }

  function openEditDialog(beacon: BeaconPublic) {
    setEditingBeacon(beacon)
    setIsDialogOpen(true)
  }

  async function handleSubmit(input: BeaconCreate) {
    if (editingBeacon) {
      await updateMutation.mutateAsync({
        beaconId: editingBeacon.id,
        input,
      })
    } else {
      await createMutation.mutateAsync(input)
    }
  }

  function handleDeactivate(beacon: BeaconPublic) {
    const confirmed = window.confirm(
      `Deactivate Beacon ${beacon.major}/${beacon.minor}?\n\nThis action will also unassign its Artifact.`,
    )

    if (confirmed) {
      deactivateMutation.mutate(beacon.id)
    }
  }

  const isSubmitting =
    createMutation.isPending || updateMutation.isPending

  const isLoading =
    beaconsQuery.isLoading ||
    sitesQuery.isLoading ||
    artifactsQuery.isLoading

  const hasError =
    beaconsQuery.isError ||
    sitesQuery.isError ||
    artifactsQuery.isError

  return (
    <div className="space-y-6">
      {/* Page heading */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <div className="flex items-center gap-2">
            <Radio className="h-6 w-6 text-primary" />
            <h1 className="text-2xl font-bold tracking-tight">
              Beacon Management
            </h1>
          </div>

          <p className="mt-1 text-sm text-muted-foreground">
            Manage BLE Beacons and assign them to heritage artifacts.
          </p>
        </div>

        <Button onClick={openCreateDialog}>
          <Plus className="mr-2 h-4 w-4" />
          Add Beacon
        </Button>
      </div>

      {/* Statistics */}
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          title="Total Beacons"
          value={statistics.total}
          description="Registered Beacons"
          icon={<Radio className="h-4 w-4" />}
        />

        <StatCard
          title="Active"
          value={statistics.active}
          description="Currently enabled"
          icon={<Wifi className="h-4 w-4" />}
        />

        <StatCard
          title="Inactive"
          value={statistics.inactive}
          description="Currently disabled"
          icon={<WifiOff className="h-4 w-4" />}
        />

        <StatCard
          title="Unassigned"
          value={statistics.unassigned}
          description="Not linked to an Artifact"
          icon={<Unlink className="h-4 w-4" />}
        />
      </div>

      {/* Search and filters */}
      <Card>
        <CardContent className="pt-6">
          <div className="flex flex-col gap-3 lg:flex-row lg:items-center">
            <div className="relative flex-1">
              <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
              <Input
                value={searchTerm}
                onChange={(event) =>
                  setSearchTerm(event.target.value)
                }
                placeholder="Search UUID, Major, Minor, Site or Artifact..."
                className="pl-9"
              />
            </div>

            <div className="flex flex-wrap gap-2">
              {(
                [
                  ["all", "All"],
                  ["active", "Active"],
                  ["inactive", "Inactive"],
                  ["unassigned", "Unassigned"],
                ] as const
              ).map(([value, label]) => (
                <Button
                  key={value}
                  type="button"
                  size="sm"
                  variant={
                    statusFilter === value
                      ? "default"
                      : "outline"
                  }
                  onClick={() => setStatusFilter(value)}
                >
                  {label}
                </Button>
              ))}
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Error state */}
      {hasError && (
        <div className="flex items-start gap-3 rounded-lg border border-destructive/30 bg-destructive/5 p-4">
          <AlertCircle className="mt-0.5 h-5 w-5 text-destructive" />

          <div className="flex-1">
            <p className="font-medium">
              Unable to load Beacon management data.
            </p>
            <p className="mt-1 text-sm text-muted-foreground">
              Please check your connection and try again.
            </p>
          </div>

          <Button
            variant="outline"
            size="sm"
            onClick={() => {
              void beaconsQuery.refetch()
              void sitesQuery.refetch()
              void artifactsQuery.refetch()
            }}
          >
            Retry
          </Button>
        </div>
      )}

      {/* Beacon list */}
      {!hasError && (
        <div className="space-y-3">
          <div className="flex items-center justify-between">
            <h2 className="text-lg font-semibold">
              Beacon List
            </h2>

            <span className="text-sm text-muted-foreground">
              {filteredBeacons.length} result
              {filteredBeacons.length === 1 ? "" : "s"}
            </span>
          </div>

          <BeaconList
            beacons={filteredBeacons}
            sites={sites}
            artifactLabels={artifactLabels}
            isLoading={isLoading}
            onEdit={openEditDialog}
            onDeactivate={handleDeactivate}
            deactivatingBeaconId={
              deactivateMutation.isPending
                ? deactivateMutation.variables
                : null
            }
          />
        </div>
      )}

      {/* Create / Edit dialog */}
      <Dialog
        open={isDialogOpen}
        onOpenChange={(open) => {
          if (!open && !isSubmitting) {
            closeDialog()
          }
        }}
      >
        <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-2xl">
          <DialogHeader>
            <DialogTitle>
              {editingBeacon ? "Edit Beacon" : "Add Beacon"}
            </DialogTitle>

            <DialogDescription>
              {editingBeacon
                ? "Update Beacon information and Artifact assignment."
                : "Register a new BLE Beacon and optionally assign an Artifact."}
            </DialogDescription>
          </DialogHeader>

          <BeaconForm
            initialData={editingBeacon}
            isSubmitting={isSubmitting}
            onSubmit={handleSubmit}
            onCancel={closeDialog}
          />
        </DialogContent>
      </Dialog>
    </div>
  )
}
