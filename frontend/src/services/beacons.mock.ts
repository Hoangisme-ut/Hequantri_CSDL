export type DemoBeacon = {
  id: string
  proximityUuid: string
  major: number
  minor: number
  site: string
  artifact: string | null
  active: boolean
  battery: number | null
  lastSeen: string | null
}

export const demoBeacons: DemoBeacon[] = [
  {
    id: "beacon-001",
    proximityUuid: "E2C56DB5-DFFB-48D2-B060-D0F5A71096E0",
    major: 1,
    minor: 1,
    site: "Temple of Literature",
    artifact: "Stele of Doctors",
    active: true,
    battery: 92,
    lastSeen: "2 min ago",
  },
  {
    id: "beacon-002",
    proximityUuid: "E2C56DB5-DFFB-48D2-B060-D0F5A71096E0",
    major: 1,
    minor: 2,
    site: "Temple of Literature",
    artifact: "Khue Van Pavilion",
    active: true,
    battery: 74,
    lastSeen: "18 min ago",
  },
  {
    id: "beacon-003",
    proximityUuid: "A3B4C5D6-E7F8-4901-ABCD-1234567890AB",
    major: 2,
    minor: 1,
    site: "Imperial Citadel of Thang Long",
    artifact: "Doan Mon Gate",
    active: true,
    battery: 51,
    lastSeen: "1 day ago",
  },
  {
    id: "beacon-004",
    proximityUuid: "A3B4C5D6-E7F8-4901-ABCD-1234567890AB",
    major: 2,
    minor: 2,
    site: "Imperial Citadel of Thang Long",
    artifact: null,
    active: false,
    battery: 18,
    lastSeen: "12 days ago",
  },
  {
    id: "beacon-005",
    proximityUuid: "6F9619FF-8B86-D011-B42D-00C04FC964FF",
    major: 3,
    minor: 1,
    site: "One Pillar Pagoda",
    artifact: null,
    active: true,
    battery: null,
    lastSeen: null,
  },
]
