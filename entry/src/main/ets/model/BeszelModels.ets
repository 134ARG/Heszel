export interface BeszelSystemInfoWire {
  cpu?: number
  mp?: number
  dp?: number
  dt?: number
  g?: number
  la?: number[]
  u?: number
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
    return summary
  }

  updateFrom(other: SystemSummary): void {
    this.name = other.name
    this.host = other.host
    this.status = other.status
    this.updated = other.updated
    this.cpuPercent = other.cpuPercent
    this.memoryPercent = other.memoryPercent
    this.diskPercent = other.diskPercent
    this.temperatureCelsius = other.temperatureCelsius
    this.gpuPercent = other.gpuPercent
    this.loadOne = other.loadOne
    this.loadFive = other.loadFive
    this.loadFifteen = other.loadFifteen
    this.uptimeSeconds = other.uptimeSeconds
  }

  updateMetrics(info: BeszelSystemInfoWire): void {
    this.cpuPercent = metric(info.cpu)
    this.memoryPercent = metric(info.mp)
    this.diskPercent = metric(info.dp)
    this.temperatureCelsius = metric(info.dt)
    this.gpuPercent = metric(info.g)
    this.loadOne = metric(info.la?.[0])
    this.loadFive = metric(info.la?.[1])
    this.loadFifteen = metric(info.la?.[2])
    this.uptimeSeconds = metric(info.u)
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
