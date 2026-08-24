export interface BeszelSmartAttributeWire {
  id?: number
  n?: string
  v?: number
  w?: number
  t?: number
  rv?: number
  rs?: string
  wf?: string
}

export interface BeszelSmartDeviceWire {
  id: string
  system?: string
  name?: string
  model?: string
  state?: string
  capacity?: number
  temp?: number
  firmware?: string
  serial?: string
  type?: string
  hours?: number
  cycles?: number
  attributes?: BeszelSmartAttributeWire[] | null
  updated?: string
}

export interface BeszelSmartDeviceListWire {
  items: BeszelSmartDeviceWire[]
}

function safeNumber(value: number | undefined): number {
  return value !== undefined && Number.isFinite(value) ? Math.max(0, value) : 0
}

@Observed
export class SmartAttributeMetric {
  id: number = 0
  name: string = ''
  current: number = 0
  worst: number = 0
  threshold: number = 0
  rawValue: number = 0
  rawString: string = ''
  whenFailed: string = ''
  currentAvailable: boolean = false
  worstAvailable: boolean = false
  thresholdAvailable: boolean = false
  rawAvailable: boolean = false

  static fromWire(wire: BeszelSmartAttributeWire): SmartAttributeMetric {
    const metric = new SmartAttributeMetric()
    metric.id = safeNumber(wire.id)
    metric.name = wire.n ?? ''
    metric.current = safeNumber(wire.v)
    metric.worst = safeNumber(wire.w)
    metric.threshold = safeNumber(wire.t)
    metric.rawValue = safeNumber(wire.rv)
    metric.rawString = wire.rs ?? ''
    metric.whenFailed = wire.wf ?? ''
    metric.currentAvailable = wire.v !== undefined
    metric.worstAvailable = wire.w !== undefined
    metric.thresholdAvailable = wire.t !== undefined
    metric.rawAvailable = wire.rv !== undefined || metric.rawString.length > 0
    return metric
  }

  normalizedName(): string {
    return this.name.toLowerCase().replaceAll('_', '').replaceAll('-', '').replaceAll(' ', '')
  }

  isFeatured(): boolean {
    const key = this.normalizedName()
    return key.includes('criticalwarning') || key.includes('percentageused') || key.includes('availablespare') ||
      key.includes('mediaerror') || key.includes('unsafeshutdown') || key.includes('reallocatedsector') ||
      key.includes('pendingsector') || key.includes('offlineuncorrectable') || key.includes('predeol') ||
      key.includes('preeol') || key.includes('lifetimeest')
  }

  isWarning(): boolean {
    if (this.whenFailed.length > 0) {
      return true
    }
    const key = this.normalizedName()
    return this.rawValue > 0 && (key.includes('criticalwarning') || key.includes('mediaerror') ||
      key.includes('reallocatedsector') || key.includes('pendingsector') || key.includes('offlineuncorrectable'))
  }
}

@Observed
export class SmartDeviceMetric {
  id: string = ''
  name: string = ''
  model: string = ''
  state: string = 'UNKNOWN'
  capacityBytes: number = 0
  temperatureCelsius: number = 0
  firmware: string = ''
  serial: string = ''
  type: string = ''
  powerOnHours: number = 0
  powerCycles: number = 0
  updated: string = ''
  attributes: SmartAttributeMetric[] = []

  static fromWire(wire: BeszelSmartDeviceWire): SmartDeviceMetric {
    const device = new SmartDeviceMetric()
    device.id = wire.id
    device.name = wire.name ?? ''
    device.model = wire.model ?? ''
    device.state = (wire.state ?? 'UNKNOWN').toUpperCase()
    device.capacityBytes = safeNumber(wire.capacity)
    device.temperatureCelsius = safeNumber(wire.temp)
    device.firmware = wire.firmware ?? ''
    device.serial = wire.serial ?? ''
    device.type = wire.type ?? ''
    device.powerOnHours = safeNumber(wire.hours)
    device.powerCycles = safeNumber(wire.cycles)
    device.updated = wire.updated ?? ''
    const attributes = wire.attributes ?? []
    device.attributes = attributes.map((attribute: BeszelSmartAttributeWire) =>
      SmartAttributeMetric.fromWire(attribute))
    return device
  }

  displayName(): string {
    if (this.model.length > 0) {
      return this.model
    }
    if (this.name.length > 0) {
      return this.name
    }
    return 'Disk'
  }

  typeLabel(): string {
    const type = this.type.toLowerCase()
    if (type === 'sat' || type === 'ata') {
      return 'SATA'
    }
    return this.type.length > 0 ? this.type.toUpperCase() : 'SMART'
  }

  isHealthy(): boolean {
    return this.state === 'PASSED' || this.state === 'HEALTHY'
  }

  isWarning(): boolean {
    return this.state === 'WARNING'
  }

  isFailed(): boolean {
    return this.state === 'FAILED'
  }

  needsAttention(): boolean {
    return this.isWarning() || this.isFailed()
  }

  severity(): number {
    if (this.isFailed()) return 3
    if (this.isWarning()) return 2
    if (this.isHealthy()) return 1
    return 0
  }

  featuredAttributes(): SmartAttributeMetric[] {
    return this.attributes.filter((attribute: SmartAttributeMetric) => attribute.isFeatured()).slice(0, 6)
  }
}

@Observed
export class SmartHealthState {
  devices: SmartDeviceMetric[] = []
  latestUpdated: string = ''

  update(wire: BeszelSmartDeviceWire[] | null | undefined): void {
    if (wire === undefined || wire === null) {
      return
    }
    const devices = wire.map((item: BeszelSmartDeviceWire) => SmartDeviceMetric.fromWire(item))
    devices.sort((left: SmartDeviceMetric, right: SmartDeviceMetric) => {
      if (left.severity() !== right.severity()) {
        return right.severity() - left.severity()
      }
      return left.displayName().localeCompare(right.displayName())
    })
    this.devices = devices
    this.latestUpdated = ''
    devices.forEach((device: SmartDeviceMetric) => {
      if (device.updated > this.latestUpdated) {
        this.latestUpdated = device.updated
      }
    })
  }

  isVisible(): boolean {
    return this.devices.length > 0
  }

  healthyCount(): number {
    return this.devices.filter((device: SmartDeviceMetric) => device.isHealthy()).length
  }

  attentionCount(): number {
    return this.devices.filter((device: SmartDeviceMetric) => device.needsAttention()).length
  }

  unknownCount(): number {
    return this.devices.length - this.healthyCount() - this.attentionCount()
  }

  summaryDevices(): SmartDeviceMetric[] {
    return this.devices.slice(0, 3)
  }
}
