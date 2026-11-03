import {
  BeaconsService,
  type BeaconCreate,
  type BeaconPublic,
  type BeaconUpdate,
  type BeaconsPublic,
} from "@/client"

import { unwrapApi } from "./api-errors"

export interface BeaconFilters {
  site_id?: string
  artifact_id?: string
  skip?: number
  limit?: number
}

export const beaconKeys = {
  all: ["beacons"] as const,

  lists: () => [...beaconKeys.all, "list"] as const,

  list: (filters: BeaconFilters) =>
    [...beaconKeys.lists(), filters] as const,

  details: () => [...beaconKeys.all, "detail"] as const,

  detail: (beaconId: string) =>
    [...beaconKeys.details(), beaconId] as const,
}

export const beaconsService = {
  async list(
    filters: BeaconFilters = {},
  ): Promise<BeaconsPublic> {
    return unwrapApi(
      BeaconsService.readBeacons({ query: filters }),
      "Beacon",
    )
  },

  async get(beaconId: string): Promise<BeaconPublic> {
    return unwrapApi(
      BeaconsService.readBeacon({
        path: { beacon_id: beaconId },
      }),
      "Beacon",
    )
  },

  async create(input: BeaconCreate): Promise<BeaconPublic> {
    return unwrapApi(
      BeaconsService.createBeacon({ body: input }),
      "Beacon",
    )
  },

  async update(
    beaconId: string,
    input: BeaconUpdate,
  ): Promise<BeaconPublic> {
    return unwrapApi(
      BeaconsService.updateBeacon({
        path: { beacon_id: beaconId },
        body: input,
      }),
      "Beacon",
    )
  },

  async deactivate(beaconId: string): Promise<void> {
    await unwrapApi(
      BeaconsService.deleteBeacon({
        path: { beacon_id: beaconId },
      }),
      "Beacon",
    )
  },
}
