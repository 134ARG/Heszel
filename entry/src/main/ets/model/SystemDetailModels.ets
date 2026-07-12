import { SystemMetric } from './BeszelModels'

export interface BeszelSystemDetailsWire {
  id: string
  hostname?: string
  kernel?: string
  cores?: number
  threads?: number
  cpu?: string
  os?: number
  os_name?: string
  arch?: string
  memory?: number
  podman?: boolean
  updated?: string
}

export interface BeszelFilesystemStatsWire {
  d?: number
  du?: number
  r?: number
  w?: number
  rb?: number
  wb?: number
  dios?: number[] | null
}

export interface BeszelGpuStatsWire {
  n?: string
  mu?: number
  mt?: number
  u?: number
  p?: number
  pp?: number
}

export interface BeszelSystemStatsWire {
  cpu?: number
  cpub?: number[] | null
  cpus?: number[] | null
  m?: number
  mu?: number
  mp?: number
  mb?: number
  mz?: number
  s?: number
  su?: number
  d?: number
  du?: number
  dp?: number
  dr?: number
  dw?: number
  dio?: number[] | null
  dios?: number[] | null
  ns?: number
  nr?: number
  b?: number[] | null
  t?: Record<string, number> | null
  efs?: Record<string, BeszelFilesystemStatsWire> | null
  g?: Record<string, BeszelGpuStatsWire> | null
  bat?: number[] | null
  ni?: Record<string, number[]> | null
}

export interface BeszelContainerStatsWire {
  n?: string
  c?: number
  m?: number
  ns?: number
  nr?: number
  b?: number[] | null
}

export interface BeszelSystemStatsRecordWire {
  created?: string
  stats?: BeszelSystemStatsWire | null
}

export interface BeszelSystemStatsListWire {
  items: BeszelSystemStatsRecordWire[]
}

export interface BeszelContainerStatsRecordWire {
  created?: string
  stats?: BeszelContainerStatsWire[] | null
}

export interface BeszelContainerStatsListWire {
  items: BeszelContainerStatsRecordWire[]
}

function safeNumber(value: number | undefined): number {
  return value !== undefined && Number.isFinite(value) ? Math.max(0, value) : 0
}

function arrayNumber(values: number[] | null | undefined, index: number): number {
  return values !== undefined && values !== null && index < values.length ? safeNumber(values[index]) : 0
}

export class SystemHardwareDetails {
  hostname: string = ''
  kernel: string = ''
  cores: number = 0
  threads: number = 0
  cpuModel: string = ''
  osName: string = ''
  architecture: string = ''
  memoryBytes: number = 0
  podman: boolean = false

  static fromWire(wire: BeszelSystemDetailsWire): SystemHardwareDetails {
    const details = new SystemHardwareDetails()
    details.hostname = wire.hostname ?? ''
    details.kernel = wire.kernel ?? ''
    details.cores = safeNumber(wire.cores)
    details.threads = safeNumber(wire.threads)
    details.cpuModel = wire.cpu ?? ''
    details.osName = wire.os_name ?? ''
    details.architecture = wire.arch ?? ''
    details.memoryBytes = safeNumber(wire.memory)
    details.podman = wire.podman ?? false
    return details
  }

  hasData(): boolean {
    return this.hostname.length > 0 || this.cpuModel.length > 0 || this.osName.length > 0 || this.kernel.length > 0
  }
}

export class FilesystemMetric {
  name: string = ''
  totalGb: number = 0
  usedGb: number = 0
  readBytesPerSecond: number = 0
  writeBytesPerSecond: number = 0
  ioPercent: number = 0
  readAwaitMs: number = 0
  writeAwaitMs: number = 0
}

export class GpuMetric {
  id: string = ''
  name: string = ''
  usagePercent: number = 0
  memoryUsedMb: number = 0
  memoryTotalMb: number = 0
  powerWatts: number = 0
}

export class SensorMetric {
  name: string = ''
  temperatureCelsius: number = 0
}

export class NetworkInterfaceMetric {
  name: string = ''
  uploadBytesPerSecond: number = 0
  downloadBytesPerSecond: number = 0
  totalUploadBytes: number = 0
  totalDownloadBytes: number = 0
}

export class ContainerMetric {
  name: string = ''
  cpuPercent: number = 0
  memoryGb: number = 0
  uploadBytesPerSecond: number = 0
  downloadBytesPerSecond: number = 0

  static fromWire(wire: BeszelContainerStatsWire): ContainerMetric {
    const container = new ContainerMetric()
    container.name = wire.n ?? 'Container'
    container.cpuPercent = safeNumber(wire.c)
    container.memoryGb = safeNumber(wire.m)
    container.uploadBytesPerSecond = wire.b !== undefined && wire.b !== null ?
      arrayNumber(wire.b, 0) : safeNumber(wire.ns) * 1024 * 1024
    container.downloadBytesPerSecond = wire.b !== undefined && wire.b !== null ?
      arrayNumber(wire.b, 1) : safeNumber(wire.nr) * 1024 * 1024
    return container
  }
}

export class SystemMetricsSnapshot {
  cpuPercent: number = 0
  cpuBreakdown: number[] = []
  cpuCores: number[] = []
  memoryTotalGb: number = 0
  memoryUsedGb: number = 0
  memoryPercent: number = 0
  memoryCacheGb: number = 0
  zfsArcGb: number = 0
  swapTotalGb: number = 0
  swapUsedGb: number = 0
  diskTotalGb: number = 0
  diskUsedGb: number = 0
  diskPercent: number = 0
  diskReadBytesPerSecond: number = 0
  diskWriteBytesPerSecond: number = 0
  diskIoPercent: number = 0
  diskReadAwaitMs: number = 0
  diskWriteAwaitMs: number = 0
  uploadBytesPerSecond: number = 0
  downloadBytesPerSecond: number = 0
  batteryPercent: number = 0
  batteryState: number = 0
  filesystems: FilesystemMetric[] = []
  gpus: GpuMetric[] = []
  sensors: SensorMetric[] = []
  interfaces: NetworkInterfaceMetric[] = []

  static fromWire(wire: BeszelSystemStatsWire): SystemMetricsSnapshot {
    const snapshot = new SystemMetricsSnapshot()
    snapshot.cpuPercent = safeNumber(wire.cpu)
    snapshot.cpuBreakdown = wire.cpub?.slice() ?? []
    snapshot.cpuCores = wire.cpus?.slice() ?? []
    snapshot.memoryTotalGb = safeNumber(wire.m)
    snapshot.memoryUsedGb = safeNumber(wire.mu)
    snapshot.memoryPercent = safeNumber(wire.mp)
    snapshot.memoryCacheGb = safeNumber(wire.mb)
    snapshot.zfsArcGb = safeNumber(wire.mz)
    snapshot.swapTotalGb = safeNumber(wire.s)
    snapshot.swapUsedGb = safeNumber(wire.su)
    snapshot.diskTotalGb = safeNumber(wire.d)
    snapshot.diskUsedGb = safeNumber(wire.du)
    snapshot.diskPercent = safeNumber(wire.dp)
    snapshot.diskReadBytesPerSecond = wire.dio !== undefined && wire.dio !== null ?
      arrayNumber(wire.dio, 0) : safeNumber(wire.dr) * 1024 * 1024
    snapshot.diskWriteBytesPerSecond = wire.dio !== undefined && wire.dio !== null ?
      arrayNumber(wire.dio, 1) : safeNumber(wire.dw) * 1024 * 1024
    snapshot.diskIoPercent = arrayNumber(wire.dios, 2)
    snapshot.diskReadAwaitMs = arrayNumber(wire.dios, 3)
    snapshot.diskWriteAwaitMs = arrayNumber(wire.dios, 4)
    snapshot.uploadBytesPerSecond = wire.b !== undefined && wire.b !== null ?
      arrayNumber(wire.b, 0) : safeNumber(wire.ns) * 1024 * 1024
    snapshot.downloadBytesPerSecond = wire.b !== undefined && wire.b !== null ?
      arrayNumber(wire.b, 1) : safeNumber(wire.nr) * 1024 * 1024
    snapshot.batteryPercent = arrayNumber(wire.bat, 0)
    snapshot.batteryState = arrayNumber(wire.bat, 1)
    snapshot.filesystems = SystemMetricsSnapshot.filesystemsFromWire(wire.efs)
    snapshot.gpus = SystemMetricsSnapshot.gpusFromWire(wire.g)
    snapshot.sensors = SystemMetricsSnapshot.sensorsFromWire(wire.t)
    snapshot.interfaces = SystemMetricsSnapshot.interfacesFromWire(wire.ni)
    return snapshot
  }

  metricValue(metric: SystemMetric): number {
    switch (metric) {
      case SystemMetric.CPU:
        return this.cpuPercent
      case SystemMetric.Memory:
        return this.memoryPercent
      case SystemMetric.Disk:
        return this.diskPercent
      default:
        return 0
    }
  }

  private static filesystemsFromWire(wire: Record<string, BeszelFilesystemStatsWire> | null | undefined): FilesystemMetric[] {
    if (wire === undefined || wire === null) {
      return []
    }
    const filesystems: FilesystemMetric[] = []
    Object.keys(wire).forEach((name: string) => {
      const source = wire[name]
      const filesystem = new FilesystemMetric()
      filesystem.name = name
      filesystem.totalGb = safeNumber(source.d)
      filesystem.usedGb = safeNumber(source.du)
      filesystem.readBytesPerSecond = source.rb !== undefined ? safeNumber(source.rb) : safeNumber(source.r) * 1024 * 1024
      filesystem.writeBytesPerSecond = source.wb !== undefined ? safeNumber(source.wb) : safeNumber(source.w) * 1024 * 1024
      filesystem.ioPercent = arrayNumber(source.dios, 2)
      filesystem.readAwaitMs = arrayNumber(source.dios, 3)
      filesystem.writeAwaitMs = arrayNumber(source.dios, 4)
      filesystems.push(filesystem)
    })
    return filesystems
  }

  private static gpusFromWire(wire: Record<string, BeszelGpuStatsWire> | null | undefined): GpuMetric[] {
    if (wire === undefined || wire === null) {
      return []
    }
    const gpus: GpuMetric[] = []
    Object.keys(wire).forEach((id: string) => {
      const source = wire[id]
      const gpu = new GpuMetric()
      gpu.id = id
      gpu.name = source.n ?? id
      gpu.usagePercent = safeNumber(source.u)
      gpu.memoryUsedMb = safeNumber(source.mu)
      gpu.memoryTotalMb = safeNumber(source.mt)
      gpu.powerWatts = source.pp !== undefined ? safeNumber(source.pp) : safeNumber(source.p)
      gpus.push(gpu)
    })
    return gpus
  }

  private static sensorsFromWire(wire: Record<string, number> | null | undefined): SensorMetric[] {
    if (wire === undefined || wire === null) {
      return []
    }
    const sensors: SensorMetric[] = []
    Object.keys(wire).forEach((name: string) => {
      const sensor = new SensorMetric()
      sensor.name = name
      sensor.temperatureCelsius = safeNumber(wire[name])
      sensors.push(sensor)
    })
    return sensors
  }

  private static interfacesFromWire(wire: Record<string, number[]> | null | undefined): NetworkInterfaceMetric[] {
    if (wire === undefined || wire === null) {
      return []
    }
    const interfaces: NetworkInterfaceMetric[] = []
    Object.keys(wire).forEach((name: string) => {
      const source = wire[name]
      const networkInterface = new NetworkInterfaceMetric()
      networkInterface.name = name
      networkInterface.uploadBytesPerSecond = arrayNumber(source, 0)
      networkInterface.downloadBytesPerSecond = arrayNumber(source, 1)
      networkInterface.totalUploadBytes = arrayNumber(source, 2)
      networkInterface.totalDownloadBytes = arrayNumber(source, 3)
      interfaces.push(networkInterface)
    })
    return interfaces
  }
}

@Observed
export class SystemDetailState {
  systemId: string = ''
  loading: boolean = false
  loaded: boolean = false
  errorMessage: string = ''
  hardware: SystemHardwareDetails = new SystemHardwareDetails()
  metrics: SystemMetricsSnapshot = new SystemMetricsSnapshot()
  containers: ContainerMetric[] = []
  hasMetrics: boolean = false
  updated: string = ''
  lastRealtimeAt: number = 0

  constructor(systemId: string = '') {
    this.systemId = systemId
  }

  applyHardware(wire: BeszelSystemDetailsWire | null): void {
    if (wire !== null) {
      this.hardware = SystemHardwareDetails.fromWire(wire)
    }
  }

  applyMetrics(stats: BeszelSystemStatsWire, containers?: BeszelContainerStatsWire[] | null, updated: string = '',
    realtime: boolean = false): void {
    this.metrics = SystemMetricsSnapshot.fromWire(stats)
    this.hasMetrics = true
    this.updated = updated
    if (realtime) {
      this.lastRealtimeAt = Date.now()
    }
    if (containers !== undefined && containers !== null) {
      this.applyContainers(containers)
    }
  }

  applyContainers(wire: BeszelContainerStatsWire[]): void {
    const containers: ContainerMetric[] = []
    wire.forEach((item: BeszelContainerStatsWire) => {
      containers.push(ContainerMetric.fromWire(item))
    })
    containers.sort((left: ContainerMetric, right: ContainerMetric) => right.cpuPercent - left.cpuPercent)
    this.containers = containers
  }
}
