export interface BeszelSystemInfoWire {
  cpu?: number
  mp?: number
  dp?: number
  dt?: number
  g?: number
  la?: number[]
  u?: number
  v?: string
  bat?: number[]
  sv?: number[]
}

export interface BeszelSystemWire {
  id: string
  name: string
  host?: string
  port?: number
  status?: string
  updated?: string
  info?: BeszelSystemInfoWire
}

export interface BeszelSystemListWire {
  items: BeszelSystemWire[]
  page: number
  perPage: number
  totalItems: number
  totalPages: number
}

export interface BeszelAuthWire {
  token: string
}

export interface BeszelErrorWire {
  message?: string
}

function metric(value: number | undefined): number {
  if (value === undefined || !Number.isFinite(value)) {
    return 0
  }
  return Math.max(0, value)
}

export class BeszelSession {
  baseUrl: string = ''
  token: string = ''
  email: string = ''
  gatewayKey: string = ''
}

export enum SystemMetric {
  CPU,
  Memory,
  Disk,
  GPU
}

@Observed
export class SystemSummary {
  id: string = ''
  name: string = ''
  host: string = ''
  status: string = 'unknown'
  updated: string = ''
  cpuPercent: number = 0
  memoryPercent: number = 0
  diskPercent: number = 0
  temperatureCelsius: number = 0
  gpuPercent: number = 0
  loadOne: number = 0
  loadFive: number = 0
  loadFifteen: number = 0
  uptimeSeconds: number = 0
  agentVersion: string = ''
  batteryPercent: number = 0
  batteryState: number = 0
  servicesTotal: number = 0
  servicesFailed: number = 0
  servicesReported: boolean = false

  static fromWire(record: BeszelSystemWire): SystemSummary {
    const summary = new SystemSummary()
    const info = record.info
    summary.id = record.id
    summary.name = record.name
    summary.host = record.host ?? ''
    summary.status = record.status ?? 'unknown'
    summary.updated = record.updated ?? ''
    summary.cpuPercent = metric(info?.cpu)
    summary.memoryPercent = metric(info?.mp)
    summary.diskPercent = metric(info?.dp)
    summary.temperatureCelsius = metric(info?.dt)
    summary.gpuPercent = metric(info?.g)
    summary.loadOne = metric(info?.la?.[0])
    summary.loadFive = metric(info?.la?.[1])
    summary.loadFifteen = metric(info?.la?.[2])
    summary.uptimeSeconds = metric(info?.u)
    summary.agentVersion = info?.v ?? ''
    summary.batteryPercent = metric(info?.bat?.[0])
    summary.batteryState = metric(info?.bat?.[1])
    summary.servicesTotal = metric(info?.sv?.[0])
    summary.servicesFailed = metric(info?.sv?.[1])
    summary.servicesReported = info?.sv !== undefined
    return summary
  }

  // Returns true when status changed, so callers can refresh array-level bindings
  // (e.g. the header's online count) that reassigning the systems array drives.
  updateFrom(other: SystemSummary): boolean {
    if (this.name !== other.name) this.name = other.name
    if (this.host !== other.host) this.host = other.host
    const statusChanged = this.status !== other.status
    if (statusChanged) this.status = other.status
    if (this.updated !== other.updated) this.updated = other.updated
    if (this.cpuPercent !== other.cpuPercent) this.cpuPercent = other.cpuPercent
    if (this.memoryPercent !== other.memoryPercent) this.memoryPercent = other.memoryPercent
    if (this.diskPercent !== other.diskPercent) this.diskPercent = other.diskPercent
    if (this.temperatureCelsius !== other.temperatureCelsius) this.temperatureCelsius = other.temperatureCelsius
    if (this.gpuPercent !== other.gpuPercent) this.gpuPercent = other.gpuPercent
    if (this.loadOne !== other.loadOne) this.loadOne = other.loadOne
    if (this.loadFive !== other.loadFive) this.loadFive = other.loadFive
    if (this.loadFifteen !== other.loadFifteen) this.loadFifteen = other.loadFifteen
    if (this.uptimeSeconds !== other.uptimeSeconds) this.uptimeSeconds = other.uptimeSeconds
    if (this.agentVersion !== other.agentVersion) this.agentVersion = other.agentVersion
    if (this.batteryPercent !== other.batteryPercent) this.batteryPercent = other.batteryPercent
    if (this.batteryState !== other.batteryState) this.batteryState = other.batteryState
    if (other.servicesReported) {
      if (this.servicesTotal !== other.servicesTotal) this.servicesTotal = other.servicesTotal
      if (this.servicesFailed !== other.servicesFailed) this.servicesFailed = other.servicesFailed
      this.servicesReported = true
    }
    return statusChanged
  }

  updateCardMetrics(info: BeszelSystemInfoWire): void {
    if (info.cpu !== undefined && this.cpuPercent !== metric(info.cpu)) this.cpuPercent = metric(info.cpu)
    if (info.mp !== undefined && this.memoryPercent !== metric(info.mp)) this.memoryPercent = metric(info.mp)
    if (info.dp !== undefined && this.diskPercent !== metric(info.dp)) this.diskPercent = metric(info.dp)
    if (info.dt !== undefined && this.temperatureCelsius !== metric(info.dt)) {
      this.temperatureCelsius = metric(info.dt)
    }
    if (info.g !== undefined && this.gpuPercent !== metric(info.g)) this.gpuPercent = metric(info.g)
    if (info.la !== undefined) {
      if (this.loadOne !== metric(info.la[0])) this.loadOne = metric(info.la[0])
      if (this.loadFive !== metric(info.la[1])) this.loadFive = metric(info.la[1])
      if (this.loadFifteen !== metric(info.la[2])) this.loadFifteen = metric(info.la[2])
    }
    if (info.u !== undefined && this.uptimeSeconds !== metric(info.u)) this.uptimeSeconds = metric(info.u)
    if (info.bat !== undefined) {
      if (this.batteryPercent !== metric(info.bat[0])) this.batteryPercent = metric(info.bat[0])
      if (this.batteryState !== metric(info.bat[1])) this.batteryState = metric(info.bat[1])
    }
    if (info.sv !== undefined) {
      if (!this.servicesReported) this.servicesReported = true
      if (this.servicesTotal !== metric(info.sv[0])) this.servicesTotal = metric(info.sv[0])
      if (this.servicesFailed !== metric(info.sv[1])) this.servicesFailed = metric(info.sv[1])
    }
  }

  metricValue(metric: SystemMetric): number {
    switch (metric) {
      case SystemMetric.CPU:
        return this.cpuPercent
      case SystemMetric.Memory:
        return this.memoryPercent
      case SystemMetric.Disk:
        return this.diskPercent
      case SystemMetric.GPU:
        return this.gpuPercent
      default:
        return 0
    }
  }

  isUp(): boolean {
    return this.status === 'up'
  }
}
