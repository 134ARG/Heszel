import { BeszelSystemWire, SystemSummary } from '../model/BeszelModels'
import {
  BeszelContainerStatsWire,
  BeszelSystemStatsRecordWire,
  BeszelSystemStatsWire,
  SystemDetailState
} from '../model/SystemDetailModels'
import { BeszelSmartDeviceWire } from '../model/SmartModels'

const GIB = 1073741824
export const DEMO_MODE = true

const CPU_MODELS: string[] = [
  'AMD Ryzen 9 7900X',
  'Intel Core i5-13500',
  'Intel N100',
  'AMD Ryzen 7 7840U',
  'Intel Xeon E-2388G'
]

const OS_NAMES: string[] = [
  'Ubuntu 24.04 LTS',
  'Debian 13',
  'Ubuntu Server 24.04 LTS',
  'Fedora Linux 42',
  'Ubuntu 22.04 LTS'
]

const SYSTEM_WIRES: BeszelSystemWire[] = [
  {
    id: 'demo-atlas', name: 'Atlas Workstation', host: '192.0.2.10', status: 'up',
    info: { cpu: 37.4, mp: 62.1, dp: 46.8, dt: 57, g: 41, la: [4.28, 3.91, 3.47],
      u: 1032480, v: '0.18.8', bat: [84, 1], sv: [18, 0] }
  },
  {
    id: 'demo-orion', name: 'Orion NAS', host: '198.51.100.24', status: 'up',
    info: { cpu: 18.6, mp: 48.3, dp: 71.5, dt: 45, g: 12, la: [1.82, 1.64, 1.51],
      u: 2844720, v: '0.18.8', sv: [14, 0] }
  },
  {
    id: 'demo-kepler', name: 'Kepler Edge', host: '203.0.113.42', status: 'up',
    info: { cpu: 12.8, mp: 39.7, dp: 28.4, dt: 42, g: 8, la: [0.68, 0.74, 0.71],
      u: 482760, v: '0.18.8', sv: [9, 0] }
  },
  {
    id: 'demo-luna', name: 'Luna Laptop', host: 'localhost', status: 'up',
    info: { cpu: 24.2, mp: 55.6, dp: 34.1, dt: 51, g: 27, la: [2.14, 1.98, 1.76],
      u: 97200, v: '0.18.8', bat: [72, 2], sv: [11, 0] }
  },
  {
    id: 'demo-vault', name: 'Vault Backup', host: '192.0.2.80', status: 'down',
    info: { cpu: 0, mp: 44.8, dp: 82.3, dt: 0, g: 0, la: [0, 0, 0],
      u: 0, v: '0.18.8', sv: [12, 1] }
  }
]

export class DemoDashboardData {
  systems: SystemSummary[] = []
  details: Map<string, SystemDetailState> = new Map<string, SystemDetailState>()
  statsBySystem: Map<string, BeszelSystemStatsWire> = new Map<string, BeszelSystemStatsWire>()
  selectedId: string = 'demo-atlas'
}

export function createDemoDashboardData(): DemoDashboardData {
  const data = new DemoDashboardData()
  SYSTEM_WIRES.forEach((wire: BeszelSystemWire, index: number) => {
    const system = SystemSummary.fromWire(wire)
    const totalMemory = [64, 32, 16, 24, 32][index]
    const totalDisk = [512, 256, 128, 1024, 512][index]
    const stats = createStats(system, index, totalMemory, totalDisk)
    data.systems.push(system)
    data.details.set(system.id, createDetail(system, index, totalMemory, stats))
    data.statsBySystem.set(system.id, stats)
  })
  return data
}

function createDetail(system: SystemSummary, variant: number, totalMemory: number,
  stats: BeszelSystemStatsWire): SystemDetailState {
  const state = new SystemDetailState(system.id)
  const containers = createContainers(variant)
  const smartDevices = createSmartDevices(system.id, variant)

  state.applySummary(system)
  state.applyHardware({
    id: system.id,
    hostname: system.id.replace('demo-', '') + '-demo',
    kernel: '6.8.0-demo-generic',
    cores: variant === 0 ? 12 : 4 + variant * 2,
    threads: variant === 0 ? 24 : 8 + variant * 4,
    cpu: CPU_MODELS[variant],
    os_name: OS_NAMES[variant],
    arch: 'x86_64',
    memory: totalMemory * GIB,
    podman: variant === 0 || variant === 2
  })
  state.cpuTrend.seed(createCpuTrend(system.cpuPercent, variant))
  state.initializeCapabilities(stats, containers, smartDevices)
  state.applyMetrics(stats, containers)
  state.loaded = true
  return state
}

function createStats(system: SystemSummary, variant: number, totalMemory: number,
  totalDisk: number): BeszelSystemStatsWire {
  const readRate = (14 + variant * 3) * 1048576
  const writeRate = (5 + variant * 2) * 1048576
  return {
    cpu: system.cpuPercent,
    cpub: [24 + variant, 8, 2, 1, 65 - variant],
    cpus: createCoreUsage(system.cpuPercent, variant),
    m: totalMemory,
    mu: totalMemory * system.memoryPercent / 100,
    mp: system.memoryPercent,
    mb: 4.8 + variant,
    mz: variant === 1 ? 3.6 : 1.4,
    s: 8,
    su: 0.7 + variant * 0.2,
    d: totalDisk,
    du: totalDisk * system.diskPercent / 100,
    dp: system.diskPercent,
    dio: [readRate, writeRate],
    dios: [0, 0, 7.2 + variant, 1.3, 2.4],
    b: [2457600 + variant * 160000, 8870000 + variant * 320000],
    t: {
      'CPU package': Math.max(42, system.temperatureCelsius),
      'NVMe': 43 + variant,
      'GPU hotspot': 61 + variant,
      'Mainboard': 38 + variant
    },
    efs: {
      'Projects': { d: 2048, du: 1184 + variant * 43, rb: 7340032, wb: 3145728,
        dios: [0, 0, 4.8, 1.1, 1.7] },
      'Archive': { d: 4096, du: 2210 + variant * 86, rb: 1572864, wb: 524288,
        dios: [0, 0, 2.1, 4.2, 5.6] }
    },
    g: {
      'gpu0': { n: variant === 0 ? 'NVIDIA RTX 4070' : 'Integrated GPU',
        mu: 3260 + variant * 120, mt: variant === 0 ? 12288 : 4096,
        u: system.gpuPercent, pp: 78.4 + variant }
    },
    bat: system.batteryPercent > 0 ? [system.batteryPercent, system.batteryState] : undefined,
    ni: {
      'Ethernet': [1048576, 6291456, 18253611008, 74239156224],
      'Wi-Fi': [245760, 921600, 4831838208, 12884901888]
    }
  }
}

function createCoreUsage(cpu: number, variant: number): number[] {
  const cores: number[] = []
  for (let index = 0; index < 16; index += 1) {
    const offset = (index * 7 + variant * 5) % 19 - 9
    cores.push(Math.max(1, Math.min(99, cpu + offset)))
  }
  return cores
}

function createCpuTrend(cpu: number, variant: number): BeszelSystemStatsRecordWire[] {
  const records: BeszelSystemStatsRecordWire[] = []
  const nowMs = Date.now()
  for (let index = 0; index < 60; index += 1) {
    const wave = Math.sin((index + variant * 3) / 5) * 8
    const pulse = index % 17 === 0 ? 14 : 0
    records.push({
      created: new Date(nowMs - (59 - index) * 60_000).toISOString(),
      stats: { cpu: Math.max(2, Math.min(96, cpu + wave + pulse)) }
    })
  }
  return records
}

function createContainers(variant: number): BeszelContainerStatsWire[] {
  return [
    { n: 'dashboard', c: 2.4 + variant, m: 0.42, b: [98304, 524288] },
    { n: 'database', c: 4.8 + variant, m: 1.26, b: [65536, 131072] },
    { n: 'media-indexer', c: 8.1 + variant, m: 0.86, b: [196608, 1048576] }
  ]
}

function createSmartDevices(systemId: string, variant: number): BeszelSmartDeviceWire[] {
  const updated = '2026-08-27T08:30:00.000Z'
  return [
    {
      id: `${systemId}-nvme`, system: systemId, name: '/dev/nvme0n1',
      model: 'Demo NVMe Pro 2TB', state: 'PASSED', capacity: 2000398934016,
      temp: 43 + variant, firmware: 'D1.4', serial: `DEMO-NVME-${variant + 1}`,
      type: 'nvme', hours: 4280 + variant * 320, cycles: 184 + variant * 12, updated: updated,
      attributes: [
        { id: 1, n: 'Critical Warning', rv: 0, rs: '0' },
        { id: 2, n: 'Available Spare', rv: 100, rs: '100' },
        { id: 3, n: 'Percentage Used', rv: 7 + variant, rs: `${7 + variant}` },
        { id: 4, n: 'Unsafe Shutdowns', rv: 2 + variant, rs: `${2 + variant}` },
        { id: 5, n: 'Media Errors', rv: 0, rs: '0' }
      ]
    },
    {
      id: `${systemId}-ssd`, system: systemId, name: '/dev/sda',
      model: 'Demo SATA SSD 1TB', state: 'PASSED', capacity: 1000204886016,
      temp: 36 + variant, firmware: 'S3.2', serial: `DEMO-SSD-${variant + 1}`,
      type: 'sat', hours: 8150 + variant * 280, cycles: 326 + variant * 15, updated: updated,
      attributes: [
        { id: 5, n: 'Reallocated Sector Count', v: 100, w: 100, t: 10, rv: 0, rs: '0' },
        { id: 197, n: 'Current Pending Sector', v: 100, w: 100, t: 0, rv: 0, rs: '0' }
      ]
    },
    {
      id: `${systemId}-hdd`, system: systemId, name: '/dev/sdb',
      model: 'Demo Archive HDD 4TB', state: variant === 1 ? 'WARNING' : 'PASSED',
      capacity: 4000787030016, temp: 39 + variant, firmware: 'H2.7',
      serial: `DEMO-HDD-${variant + 1}`, type: 'sat', hours: 14260 + variant * 410,
      cycles: 512 + variant * 18, updated: updated,
      attributes: [
        { id: 5, n: 'Reallocated Sector Count', v: 98, w: 98, t: 10,
          rv: variant === 1 ? 2 : 0, rs: variant === 1 ? '2' : '0' },
        { id: 9, n: 'Power On Hours', v: 92, w: 92, t: 0,
          rv: 14260 + variant * 410, rs: `${14260 + variant * 410}` },
        { id: 194, n: 'Temperature Celsius', v: 61, w: 54, t: 0,
          rv: 39 + variant, rs: `${39 + variant}` }
      ]
    }
  ]
}
