
import { useEffect, useState } from "react"
import { useQuery } from "@tanstack/react-query"

import type { BeaconCreate, BeaconPublic } from "@/client"
import { sitesService } from "@/services/sites"
import { artifactsService } from "@/services/artifacts"
import { artifactKeys } from "@/services/artifacts"

import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"

interface BeaconFormProps {
  initialData?: BeaconPublic | null
  isSubmitting?: boolean
  onSubmit: (data: BeaconCreate) => Promise<void>
  onCancel: () => void
}

type BeaconDraft = {
  proximity_uuid: string
  major: string
  minor: string
  site_id: string
  artifact_id: string
  tx_power: string
  rssi_threshold: string
  is_active: boolean
}

const emptyDraft: BeaconDraft = {
  proximity_uuid: "",
  major: "",
  minor: "",
  site_id: "",
  artifact_id: "",
  tx_power: "",
  rssi_threshold: "",
  is_active: true,
}

function createDraft(beacon?: BeaconPublic | null): BeaconDraft {
  if (!beacon) return emptyDraft

  return {
    proximity_uuid: beacon.proximity_uuid,
    major: String(beacon.major),
    minor: String(beacon.minor),
    site_id: beacon.site_id,
    artifact_id: beacon.artifact_id ?? "",
    tx_power: beacon.tx_power?.toString() ?? "",
    rssi_threshold: beacon.rssi_threshold?.toString() ?? "",
    is_active: beacon.is_active ?? true,
  }
}

function parseOptionalNumber(value: string): number | null {
  return value.trim() === "" ? null : Number(value)
}

export default function BeaconForm({
  initialData,
  isSubmitting = false,
  onSubmit,
  onCancel,
}: BeaconFormProps) {
  const [draft, setDraft] = useState<BeaconDraft>(
    () => createDraft(initialData),
  )
  const [formError, setFormError] = useState<string | null>(null)

  const sitesQuery = useQuery({
    queryKey: ["sites", "beacon-selector"],
    queryFn: () => sitesService.list(),
  })

  const artifactsQuery = useQuery({
    queryKey: artifactKeys.list({
      site_id: draft.site_id,
      skip: 0,
      limit: 200,
      include_inactive: false,
    }),
    queryFn: () =>
      artifactsService.list({
        site_id: draft.site_id,
        skip: 0,
        limit: 200,
        include_inactive: false,
      }),
    enabled: Boolean(draft.site_id),
  })

  useEffect(() => {
    setDraft(createDraft(initialData))
    setFormError(null)
  }, [initialData])

  function updateField<K extends keyof BeaconDraft>(
    field: K,
    value: BeaconDraft[K],
  ) {
    setDraft((current) => ({
      ...current,
      [field]: value,
    }))
  }

  function handleSiteChange(siteId: string) {
    setDraft((current) => ({
      ...current,
      site_id: siteId,
      artifact_id: "",
    }))
  }

  async function handleSubmit(
    event: React.FormEvent<HTMLFormElement>,
  ) {
    event.preventDefault()
    setFormError(null)

    const uuid = draft.proximity_uuid.trim()
    const major = Number(draft.major)
    const minor = Number(draft.minor)
    const txPower = parseOptionalNumber(draft.tx_power)
    const rssiThreshold = parseOptionalNumber(draft.rssi_threshold)

    if (!uuid) {
      setFormError("Proximity UUID is required.")
      return
    }

    if (!draft.site_id) {
      setFormError("Please select a site.")
      return
    }

    if (
      draft.major.trim() === "" ||
      !Number.isInteger(major) ||
      major < 0 ||
      major > 65535
    ) {
      setFormError("Major must be an integer between 0 and 65535.")
      return
    }

    if (
      draft.minor.trim() === "" ||
      !Number.isInteger(minor) ||
      minor < 0 ||
      minor > 65535
    ) {
      setFormError("Minor must be an integer between 0 and 65535.")
      return
    }

    if (txPower !== null && !Number.isFinite(txPower)) {
      setFormError("TX Power must be a valid number.")
      return
    }

    if (
      rssiThreshold !== null &&
      !Number.isFinite(rssiThreshold)
    ) {
      setFormError("RSSI Threshold must be a valid number.")
      return
    }

    const selectedArtifact = artifactsQuery.data?.data.find(
      (artifact) => artifact.id === draft.artifact_id,
    )

    if (draft.artifact_id && !selectedArtifact) {
      setFormError(
        "The selected artifact is unavailable for this site.",
      )
      return
    }

    try {
      await onSubmit({
        proximity_uuid: uuid,
        major,
        minor,
        site_id: draft.site_id,
        artifact_id: draft.artifact_id || null,
        tx_power: txPower,
        rssi_threshold: rssiThreshold,
        is_active: draft.is_active,
      })
    } catch (error) {
      setFormError(
        error instanceof Error
          ? error.message
          : "Could not save beacon.",
      )
    }
  }

  const sites = sitesQuery.data?.data ?? []
  const artifacts = artifactsQuery.data?.data ?? []

  return (
    <form onSubmit={handleSubmit} className="space-y-5">
      <div className="grid gap-4 sm:grid-cols-2">
        <label className="grid gap-1.5 text-sm font-medium sm:col-span-2">
          Proximity UUID
          <Input
            value={draft.proximity_uuid}
            onChange={(event) =>
              updateField("proximity_uuid", event.target.value)
            }
            placeholder="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
            maxLength={100}
            required
            disabled={isSubmitting}
          />
          <span className="text-xs font-normal text-muted-foreground">
            Enter the UUID configured on the physical beacon.
          </span>
        </label>

        <label className="grid gap-1.5 text-sm font-medium">
          Major
          <Input
            type="number"
            min={0}
            max={65535}
            step={1}
            value={draft.major}
            onChange={(event) =>
              updateField("major", event.target.value)
            }
            placeholder="1"
            required
            disabled={isSubmitting}
          />
        </label>

        <label className="grid gap-1.5 text-sm font-medium">
          Minor
          <Input
            type="number"
            min={0}
            max={65535}
            step={1}
            value={draft.minor}
            onChange={(event) =>
              updateField("minor", event.target.value)
            }
            placeholder="1"
            required
            disabled={isSubmitting}
          />
        </label>

        <label className="grid gap-1.5 text-sm font-medium sm:col-span-2">
          Site
          <select
            className="h-9 rounded-md border border-input bg-background px-3 text-sm"
            value={draft.site_id}
            onChange={(event) => handleSiteChange(event.target.value)}
            disabled={isSubmitting || sitesQuery.isLoading}
            required
          >
            <option value="">Select a site</option>
            {sites
              .filter(
                (site) =>
                  site.is_active || site.id === draft.site_id,
              )
              .map((site) => (
                <option key={site.id} value={site.id}>
                  {site.name}
                  {site.is_active ? "" : " (inactive)"}
                </option>
              ))}
          </select>

          {sitesQuery.isError && (
            <span className="text-xs text-destructive">
              {sitesQuery.error.message}
            </span>
          )}
        </label>

        <label className="grid gap-1.5 text-sm font-medium sm:col-span-2">
          Assigned Artifact
          <select
            className="h-9 rounded-md border border-input bg-background px-3 text-sm"
            value={draft.artifact_id}
            onChange={(event) =>
              updateField("artifact_id", event.target.value)
            }
            disabled={
              isSubmitting ||
              !draft.site_id ||
              artifactsQuery.isLoading ||
              artifactsQuery.isError
            }
          >
            <option value="">Unassigned</option>
            {artifacts.map((artifact) => (
              <option key={artifact.id} value={artifact.id}>
                {artifact.code}
                {artifact.title ? ` - ${artifact.title}` : ""}
              </option>
            ))}
          </select>

          {artifactsQuery.isLoading && (
            <span className="text-xs text-muted-foreground">
              Loading artifacts...
            </span>
          )}

          {artifactsQuery.isError && (
            <span className="text-xs text-destructive">
              {artifactsQuery.error.message}
            </span>
          )}

          <span className="text-xs font-normal text-muted-foreground">
            Only artifacts belonging to the selected site are available.
          </span>
        </label>

        <label className="grid gap-1.5 text-sm font-medium">
          TX Power
          <Input
            type="number"
            step="any"
            value={draft.tx_power}
            onChange={(event) =>
              updateField("tx_power", event.target.value)
            }
            placeholder="Optional"
            disabled={isSubmitting}
          />
        </label>

        <label className="grid gap-1.5 text-sm font-medium">
          RSSI Threshold
          <Input
            type="number"
            step="any"
            value={draft.rssi_threshold}
            onChange={(event) =>
              updateField("rssi_threshold", event.target.value)
            }
            placeholder="Optional"
            disabled={isSubmitting}
          />
        </label>

        <label className="flex items-center gap-2 text-sm sm:col-span-2">
          <input
            type="checkbox"
            checked={draft.is_active}
            onChange={(event) =>
              updateField("is_active", event.target.checked)
            }
            disabled={isSubmitting}
          />
          Active
        </label>
      </div>

      {formError && (
        <p role="alert" className="text-sm text-destructive">
          {formError}
        </p>
      )}

      <div className="flex flex-wrap justify-end gap-2">
        <Button
          type="button"
          variant="outline"
          onClick={onCancel}
          disabled={isSubmitting}
        >
          Cancel
        </Button>

        <Button
          type="submit"
          disabled={
            isSubmitting ||
            sitesQuery.isLoading ||
            sitesQuery.isError ||
            Boolean(draft.site_id && artifactsQuery.isError)
          }
        >
          {isSubmitting
            ? "Saving..."
            : initialData
              ? "Save changes"
              : "Add Beacon"}
        </Button>
      </div>
    </form>
  )
}
