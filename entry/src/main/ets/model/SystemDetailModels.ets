import { BeszelSystemInfoWire, SystemSummary } from './BeszelModels'

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

function numberArraysEqual(left: number[], right: number[]): boolean {
  if (left.length !== right.length) {
    return false
  }
  for (let index = 0; index < left.length; index += 1) {
    if (left[index] !== right[index]) {
      return false
    }
  }
  return true
}

function numberArrayPrefixEqual(left: number[], right: number[], limit: number): boolean {
  const comparedLength = Math.min(right.length, limit)
  if (left.length !== comparedLength) return false
  for (let index = 0; index < comparedLength; index += 1) {
    if (left[index] !== right[index]) return false
  }
  return true
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
  hasMemory: boolean = false
  hasPower: boolean = false
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
  hasNetwork: boolean = false

  static fromWire(wire: BeszelContainerStatsWire, previous: ContainerMetric | null = null): ContainerMetric {
    const container = new ContainerMetric()
    container.name = wire.n ?? 'Container'
    container.cpuPercent = safeNumber(wire.c)
    container.memoryGb = safeNumber(wire.m)
    container.uploadBytesPerSecond = wire.b !== undefined && wire.b !== null ?
      arrayNumber(wire.b, 0) : safeNumber(wire.ns) * 1024 * 1024
    container.downloadBytesPerSecond = wire.b !== undefined && wire.b !== null ?
      arrayNumber(wire.b, 1) : safeNumber(wire.nr) * 1024 * 1024
    container.hasNetwork = previous?.hasNetwork === true || wire.b !== undefined && wire.b !== null ||
      wire.ns !== undefined || wire.nr !== undefined
    return container
  }
}

class MetricConverters {
  static filesystemsFromWire(wire: Record<string, BeszelFilesystemStatsWire> | null | undefined): FilesystemMetric[] {
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

  static gpusFromWire(wire: Record<string, BeszelGpuStatsWire> | null | undefined,
    previous: GpuMetric[]): GpuMetric[] {
    if (wire === undefined || wire === null) {
      return []
    }
    const gpus: GpuMetric[] = []
    Object.keys(wire).forEach((id: string) => {
      const source = wire[id]
      const old = previous.find((candidate: GpuMetric) => candidate.id === id)
      const gpu = new GpuMetric()
      gpu.id = id
      gpu.name = source.n ?? id
      gpu.usagePercent = safeNumber(source.u)
      gpu.memoryUsedMb = safeNumber(source.mu)
      gpu.memoryTotalMb = safeNumber(source.mt)
      gpu.powerWatts = source.pp !== undefined ? safeNumber(source.pp) : safeNumber(source.p)
      gpu.hasMemory = old?.hasMemory === true || source.mu !== undefined || source.mt !== undefined
      gpu.hasPower = old?.hasPower === true || source.pp !== undefined || source.p !== undefined
      gpus.push(gpu)
    })
    return gpus
  }

  static sensorsFromWire(wire: Record<string, number> | null | undefined): SensorMetric[] {
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

  static interfacesFromWire(wire: Record<string, number[]> | null | undefined): NetworkInterfaceMetric[] {
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
export class OverviewMetricsState {
  cpuPercent: number = 0
  memoryPercent: number = 0
  diskPercent: number = 0
  gpuPercent: number = 0
  loadOne: number = 0
  loadFive: number = 0
  loadFifteen: number = 0
  temperatureCelsius: number = 0
  uptimeSeconds: number = 0

  updateFromSummary(system: SystemSummary): void {
    this.updateValue('cpu', system.cpuPercent)
    this.updateValue('memory', system.memoryPercent)
    this.updateValue('disk', system.diskPercent)
    this.updateValue('gpu', system.gpuPercent)
    this.updateInfoValues(system.loadOne, system.loadFive, system.loadFifteen,
      system.temperatureCelsius, system.uptimeSeconds)
  }

  updateRealtime(info: BeszelSystemInfoWire | undefined, stats: BeszelSystemStatsWire | undefined): void {
    if (stats?.cpu !== undefined) {
      this.updateValue('cpu', safeNumber(stats.cpu))
    } else if (info?.cpu !== undefined) {
      this.updateValue('cpu', safeNumber(info.cpu))
    }
    if (stats?.mp !== undefined) {
      this.updateValue('memory', safeNumber(stats.mp))
    } else if (info?.mp !== undefined) {
      this.updateValue('memory', safeNumber(info.mp))
    }
    if (stats?.dp !== undefined) {
      this.updateValue('disk', safeNumber(stats.dp))
    } else if (info?.dp !== undefined) {
      this.updateValue('disk', safeNumber(info.dp))
    }
    if (info !== undefined) this.updateInfoDetails(info)
  }

  private updateInfoDetails(info: BeszelSystemInfoWire): void {
    if (info.g !== undefined) this.updateValue('gpu', safeNumber(info.g))
    if (info.la !== undefined && info.la.length > 0 && this.loadOne !== safeNumber(info.la[0])) {
      this.loadOne = safeNumber(info.la[0])
    }
    if (info.la !== undefined && info.la.length > 1 && this.loadFive !== safeNumber(info.la[1])) {
      this.loadFive = safeNumber(info.la[1])
    }
    if (info.la !== undefined && info.la.length > 2 && this.loadFifteen !== safeNumber(info.la[2])) {
      this.loadFifteen = safeNumber(info.la[2])
    }
    if (info.dt !== undefined && this.temperatureCelsius !== safeNumber(info.dt)) {
      this.temperatureCelsius = safeNumber(info.dt)
    }
    if (info.u !== undefined && this.uptimeSeconds !== safeNumber(info.u)) {
      this.uptimeSeconds = safeNumber(info.u)
    }
  }

  updateStats(wire: BeszelSystemStatsWire): void {
    if (wire.cpu !== undefined) this.updateValue('cpu', safeNumber(wire.cpu))
    if (wire.mp !== undefined) this.updateValue('memory', safeNumber(wire.mp))
    if (wire.dp !== undefined) this.updateValue('disk', safeNumber(wire.dp))
  }

  private updateValue(metric: string, value: number): void {
    if (metric === 'cpu' && this.cpuPercent !== value) {
      this.cpuPercent = value
    } else if (metric === 'memory' && this.memoryPercent !== value) {
      this.memoryPercent = value
    } else if (metric === 'disk' && this.diskPercent !== value) {
      this.diskPercent = value
    } else if (metric === 'gpu' && this.gpuPercent !== value) {
      this.gpuPercent = value
    }
  }

  private updateInfoValues(loadOne: number, loadFive: number, loadFifteen: number,
    temperature: number, uptime: number): void {
    if (this.loadOne !== loadOne) this.loadOne = loadOne
    if (this.loadFive !== loadFive) this.loadFive = loadFive
    if (this.loadFifteen !== loadFifteen) this.loadFifteen = loadFifteen
    if (this.temperatureCelsius !== temperature) this.temperatureCelsius = temperature
    if (this.uptimeSeconds !== uptime) this.uptimeSeconds = uptime
  }
}

@Observed
export class CpuMetricsState {
  available: boolean = false
  breakdown: number[] = []
  cores: number[] = []
  coreCount: number = 0
  initialize(wire: BeszelSystemStatsWire): void {
    this.available = wire.cpub !== undefined && wire.cpub !== null || wire.cpus !== undefined && wire.cpus !== null
  }

  update(wire: BeszelSystemStatsWire): void {
    if (!this.available) return
    this.applyWire(wire)
  }

  private applyWire(wire: BeszelSystemStatsWire): void {
    if (wire.cpub !== undefined && wire.cpub !== null && !numberArraysEqual(this.breakdown, wire.cpub)) {
      this.breakdown = wire.cpub.slice()
    }
    if (wire.cpus !== undefined && wire.cpus !== null) {
      if (this.coreCount !== wire.cpus.length) this.coreCount = wire.cpus.length
      if (!numberArrayPrefixEqual(this.cores, wire.cpus, 32)) this.cores = wire.cpus.slice(0, 32)
    }
  }

  isVisible(): boolean { return this.available }
}

@Observed
export class MemoryMetricsState {
  available: boolean = false
  totalGb: number = 0
  usedGb: number = 0
  percent: number = 0
  cacheGb: number = 0
  zfsArcGb: number = 0
  swapTotalGb: number = 0
  swapUsedGb: number = 0
  initialize(wire: BeszelSystemStatsWire): void {
    this.available = wire.m !== undefined || wire.mu !== undefined || wire.mp !== undefined
  }

  update(wire: BeszelSystemStatsWire): void {
    if (!this.available) return
    this.applyWire(wire)
  }

  private applyWire(wire: BeszelSystemStatsWire): void {
    if (wire.m !== undefined && this.totalGb !== safeNumber(wire.m)) this.totalGb = safeNumber(wire.m)
    if (wire.mu !== undefined && this.usedGb !== safeNumber(wire.mu)) this.usedGb = safeNumber(wire.mu)
    if (wire.mp !== undefined && this.percent !== safeNumber(wire.mp)) this.percent = safeNumber(wire.mp)
    if (wire.mb !== undefined && this.cacheGb !== safeNumber(wire.mb)) this.cacheGb = safeNumber(wire.mb)
    if (wire.mz !== undefined && this.zfsArcGb !== safeNumber(wire.mz)) this.zfsArcGb = safeNumber(wire.mz)
    if (wire.s !== undefined && this.swapTotalGb !== safeNumber(wire.s)) this.swapTotalGb = safeNumber(wire.s)
    if (wire.su !== undefined && this.swapUsedGb !== safeNumber(wire.su)) this.swapUsedGb = safeNumber(wire.su)
  }

  isVisible(): boolean { return this.available }
}

@Observed
export class StorageMetricsState {
  available: boolean = false
  diskIoAvailable: boolean = false
  latencyAvailable: boolean = false
  totalGb: number = 0
  usedGb: number = 0
  percent: number = 0
  readBytesPerSecond: number = 0
  writeBytesPerSecond: number = 0
  ioPercent: number = 0
  readAwaitMs: number = 0
  writeAwaitMs: number = 0
  filesystems: FilesystemMetric[] = []
  initialize(wire: BeszelSystemStatsWire): void {
    this.available = wire.d !== undefined || wire.du !== undefined || wire.dp !== undefined ||
      wire.efs !== undefined && wire.efs !== null
    this.diskIoAvailable = wire.dio !== undefined && wire.dio !== null || wire.dr !== undefined ||
      wire.dw !== undefined
    this.latencyAvailable = wire.dios !== undefined && wire.dios !== null
  }

  update(wire: BeszelSystemStatsWire): void {
    if (!this.available) return
    this.applyWire(wire)
  }

  private applyWire(wire: BeszelSystemStatsWire): void {
    this.setNumbers(wire)
    if (wire.efs !== undefined && wire.efs !== null) {
      const filesystems = MetricConverters.filesystemsFromWire(wire.efs)
      if (filesystems.length > 0) this.filesystems = filesystems
    }
  }

  isVisible(): boolean { return this.available }
  diskIoVisible(): boolean { return this.diskIoAvailable }
  latencyVisible(): boolean { return this.latencyAvailable }

  private setNumbers(wire: BeszelSystemStatsWire): void {
    if (wire.d !== undefined && this.totalGb !== safeNumber(wire.d)) this.totalGb = safeNumber(wire.d)
    if (wire.du !== undefined && this.usedGb !== safeNumber(wire.du)) this.usedGb = safeNumber(wire.du)
    if (wire.dp !== undefined && this.percent !== safeNumber(wire.dp)) this.percent = safeNumber(wire.dp)
    if (wire.dio !== undefined && wire.dio !== null) {
      if (wire.dio.length > 0 && this.readBytesPerSecond !== arrayNumber(wire.dio, 0)) {
        this.readBytesPerSecond = arrayNumber(wire.dio, 0)
      }
      if (wire.dio.length > 1 && this.writeBytesPerSecond !== arrayNumber(wire.dio, 1)) {
        this.writeBytesPerSecond = arrayNumber(wire.dio, 1)
      }
    } else {
      if (wire.dr !== undefined && this.readBytesPerSecond !== safeNumber(wire.dr) * 1048576) {
        this.readBytesPerSecond = safeNumber(wire.dr) * 1048576
      }
      if (wire.dw !== undefined && this.writeBytesPerSecond !== safeNumber(wire.dw) * 1048576) {
        this.writeBytesPerSecond = safeNumber(wire.dw) * 1048576
      }
    }
    if (wire.dios !== undefined && wire.dios !== null) {
      if (wire.dios.length > 2 && this.ioPercent !== arrayNumber(wire.dios, 2)) {
        this.ioPercent = arrayNumber(wire.dios, 2)
      }
      if (wire.dios.length > 3 && this.readAwaitMs !== arrayNumber(wire.dios, 3)) {
        this.readAwaitMs = arrayNumber(wire.dios, 3)
      }
      if (wire.dios.length > 4 && this.writeAwaitMs !== arrayNumber(wire.dios, 4)) {
        this.writeAwaitMs = arrayNumber(wire.dios, 4)
      }
    }
  }
}

@Observed
export class NetworkMetricsState {
  available: boolean = false
  uploadBytesPerSecond: number = 0
  downloadBytesPerSecond: number = 0
  interfaces: NetworkInterfaceMetric[] = []
  initialize(wire: BeszelSystemStatsWire): void {
    this.available = wire.b !== undefined && wire.b !== null || wire.ns !== undefined || wire.nr !== undefined ||
      wire.ni !== undefined && wire.ni !== null
  }

  update(wire: BeszelSystemStatsWire): void {
    if (!this.available) return
    this.applyWire(wire)
  }

  private applyWire(wire: BeszelSystemStatsWire): void {
    if (wire.b !== undefined && wire.b !== null) {
      if (wire.b.length > 0 && this.uploadBytesPerSecond !== arrayNumber(wire.b, 0)) {
        this.uploadBytesPerSecond = arrayNumber(wire.b, 0)
      }
      if (wire.b.length > 1 && this.downloadBytesPerSecond !== arrayNumber(wire.b, 1)) {
        this.downloadBytesPerSecond = arrayNumber(wire.b, 1)
      }
    } else {
      if (wire.ns !== undefined && this.uploadBytesPerSecond !== safeNumber(wire.ns) * 1048576) {
        this.uploadBytesPerSecond = safeNumber(wire.ns) * 1048576
      }
      if (wire.nr !== undefined && this.downloadBytesPerSecond !== safeNumber(wire.nr) * 1048576) {
        this.downloadBytesPerSecond = safeNumber(wire.nr) * 1048576
      }
    }
    if (wire.ni !== undefined && wire.ni !== null) {
      const interfaces = MetricConverters.interfacesFromWire(wire.ni)
      if (interfaces.length > 0) this.interfaces = interfaces
    }
  }

  isVisible(): boolean { return this.available }
}

@Observed
export class GpuMetricsState {
  available: boolean = false
  gpus: GpuMetric[] = []
  initialize(wire: BeszelSystemStatsWire): void {
    this.available = wire.g !== undefined && wire.g !== null && Object.keys(wire.g).length > 0
  }

  update(wire: BeszelSystemStatsWire): void {
    if (this.available) this.applyWire(wire)
  }

  private applyWire(wire: BeszelSystemStatsWire): void {
    if (wire.g !== undefined && wire.g !== null) {
      const gpus = MetricConverters.gpusFromWire(wire.g, this.gpus)
      if (gpus.length > 0) this.gpus = gpus
    }
  }

  isVisible(): boolean { return this.available }
}

@Observed
export class HealthMetricsState {
  sensorsAvailable: boolean = false
  batteryAvailable: boolean = false
  servicesAvailable: boolean = false
  sensors: SensorMetric[] = []
  batteryPercent: number = 0
  batteryState: number = 0
  servicesTotal: number = 0
  servicesFailed: number = 0
  initialize(wire: BeszelSystemStatsWire): void {
    this.sensorsAvailable = wire.t !== undefined && wire.t !== null && Object.keys(wire.t).length > 0
    this.batteryAvailable = this.batteryAvailable || wire.bat !== undefined && wire.bat !== null
  }

  initializeSummary(system: SystemSummary): void {
    this.servicesAvailable = this.servicesAvailable || system.servicesTotal > 0
    this.batteryAvailable = this.batteryAvailable || system.batteryPercent > 0
  }

  update(wire: BeszelSystemStatsWire): void {
    if (!this.isVisible()) return
    this.applyWire(wire)
  }

  updateSummary(system: SystemSummary): void {
    if (system.servicesTotal > 0) {
      if (this.servicesTotal !== system.servicesTotal) this.servicesTotal = system.servicesTotal
      if (this.servicesFailed !== system.servicesFailed) this.servicesFailed = system.servicesFailed
    }
    if (this.batteryAvailable && system.batteryPercent > 0) {
      this.batteryPercent = system.batteryPercent
      this.batteryState = system.batteryState
    }
  }

  updateInfo(info: BeszelSystemInfoWire): void {
    if (this.servicesAvailable && info.sv !== undefined) {
      if (info.sv.length > 0 && this.servicesTotal !== safeNumber(info.sv[0])) {
        this.servicesTotal = safeNumber(info.sv[0])
      }
      if (info.sv.length > 1 && this.servicesFailed !== safeNumber(info.sv[1])) {
        this.servicesFailed = safeNumber(info.sv[1])
      }
    }
    if (this.batteryAvailable && info.bat !== undefined && info.bat !== null) {
      const percent = arrayNumber(info.bat, 0)
      const state = arrayNumber(info.bat, 1)
      if (this.batteryPercent !== percent) this.batteryPercent = percent
      if (this.batteryState !== state) this.batteryState = state
    }
  }

  private applyWire(wire: BeszelSystemStatsWire): void {
    if (this.sensorsAvailable && wire.t !== undefined && wire.t !== null) {
      const sensors = MetricConverters.sensorsFromWire(wire.t)
      if (sensors.length > 0) this.sensors = sensors
    }
    if (this.batteryAvailable && wire.bat !== undefined && wire.bat !== null) {
      if (wire.bat.length > 0 && this.batteryPercent !== arrayNumber(wire.bat, 0)) {
        this.batteryPercent = arrayNumber(wire.bat, 0)
      }
      if (wire.bat.length > 1 && this.batteryState !== arrayNumber(wire.bat, 1)) {
        this.batteryState = arrayNumber(wire.bat, 1)
      }
    }
  }

  isVisible(): boolean {
    return this.sensorsAvailable || this.batteryAvailable || this.servicesAvailable
  }
  batteryVisible(): boolean { return this.batteryAvailable }
  servicesVisible(): boolean { return this.servicesAvailable }
}

@Observed
export class ContainerMetricsState {
  available: boolean = false
  containers: ContainerMetric[] = []
  initialize(wire: BeszelContainerStatsWire[] | null | undefined): void {
    this.available = wire !== undefined && wire !== null
  }

  update(wire: BeszelContainerStatsWire[] | null | undefined): void {
    if (!this.available || wire === undefined || wire === null) return
    this.applyWire(wire)
  }

  private applyWire(wire: BeszelContainerStatsWire[]): void {
    const incoming = new Map<string, BeszelContainerStatsWire>()
    wire.forEach((item: BeszelContainerStatsWire) => incoming.set(item.n ?? 'Container', item))
    const next: ContainerMetric[] = []
    this.containers.forEach((previous: ContainerMetric) => {
      const item = incoming.get(previous.name)
      if (item !== undefined) {
        next.push(ContainerMetric.fromWire(item, previous))
        incoming.delete(previous.name)
      }
    })
    incoming.forEach((item: BeszelContainerStatsWire) => next.push(ContainerMetric.fromWire(item)))
    this.containers = next
  }

  isVisible(): boolean { return this.available }
}

@Observed
export class SystemDetailState {
  systemId: string = ''
  loading: boolean = false
  loaded: boolean = false
  errorMessage: string = ''
  hardware: SystemHardwareDetails = new SystemHardwareDetails()
  layoutVersion: number = 0
  overview: OverviewMetricsState = new OverviewMetricsState()
  cpuMetrics: CpuMetricsState = new CpuMetricsState()
  memoryMetrics: MemoryMetricsState = new MemoryMetricsState()
  storageMetrics: StorageMetricsState = new StorageMetricsState()
  networkMetrics: NetworkMetricsState = new NetworkMetricsState()
  gpuMetrics: GpuMetricsState = new GpuMetricsState()
  healthMetrics: HealthMetricsState = new HealthMetricsState()
  containerMetrics: ContainerMetricsState = new ContainerMetricsState()
  private capabilitiesInitialized: boolean = false

  constructor(systemId: string = '') {
    this.systemId = systemId
  }

  applyHardware(wire: BeszelSystemDetailsWire | null): void {
    if (wire !== null) {
      this.hardware = SystemHardwareDetails.fromWire(wire)
    }
  }

  applySummary(system: SystemSummary): void {
    const healthWasVisible = this.healthMetrics.isVisible()
    if (!this.capabilitiesInitialized) this.healthMetrics.initializeSummary(system)
    this.overview.updateFromSummary(system)
    this.healthMetrics.updateSummary(system)
    if (healthWasVisible !== this.healthMetrics.isVisible()) this.layoutVersion += 1
  }

  initializeCapabilities(stats: BeszelSystemStatsWire | null | undefined,
    containers: BeszelContainerStatsWire[] | null | undefined): void {
    if (this.capabilitiesInitialized) return
    if (stats !== undefined && stats !== null) {
      this.cpuMetrics.initialize(stats)
      this.memoryMetrics.initialize(stats)
      this.storageMetrics.initialize(stats)
      this.networkMetrics.initialize(stats)
      this.gpuMetrics.initialize(stats)
      this.healthMetrics.initialize(stats)
    }
    this.containerMetrics.initialize(containers)
    this.capabilitiesInitialized = true
    this.layoutVersion += 1
  }

  applyMetrics(stats: BeszelSystemStatsWire, containers?: BeszelContainerStatsWire[] | null): void {
    this.overview.updateStats(stats)
    this.updateMetricGroups(stats, containers)
  }

  applyRealtime(info: BeszelSystemInfoWire | undefined, stats: BeszelSystemStatsWire | undefined,
    containers: BeszelContainerStatsWire[] | null | undefined): void {
    this.overview.updateRealtime(info, stats)
    if (info !== undefined) this.healthMetrics.updateInfo(info)
    if (stats !== undefined) {
      this.updateMetricGroups(stats, containers)
    } else {
      this.containerMetrics.update(containers)
    }
  }

  private updateMetricGroups(stats: BeszelSystemStatsWire,
    containers: BeszelContainerStatsWire[] | null | undefined): void {
    this.cpuMetrics.update(stats)
    this.memoryMetrics.update(stats)
    this.storageMetrics.update(stats)
    this.networkMetrics.update(stats)
    this.gpuMetrics.update(stats)
    this.healthMetrics.update(stats)
    this.containerMetrics.update(containers)
  }

  applyContainers(wire: BeszelContainerStatsWire[]): void {
    this.containerMetrics.update(wire)
  }

}
