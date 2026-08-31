import {
  MetricChartAxisPolicy,
  MetricChartSeries,
  MetricChartValueFormat
} from './MetricChartModels'
import { BeszelSystemStatsWire, SystemDetailState } from './SystemDetailModels'

export const CHART_BYTES_PER_GB = 1024 * 1024 * 1024
export const CHART_BYTES_PER_MB = 1024 * 1024

export enum MetricChartKind {
  HEALTH,
  CPU,
  MEMORY,
  NETWORK,
  GPU,
  STORAGE
}

export enum MetricChartPanelKind {
  HEALTH_TEMPERATURE,
  CPU_USAGE,
  MEMORY_USAGE,
  NETWORK_UPLOAD,
  NETWORK_DOWNLOAD,
  GPU_USAGE,
  GPU_MEMORY,
  GPU_POWER,
  STORAGE_USAGE,
  STORAGE_READ,
  STORAGE_WRITE
}

export class MetricChartLabels {
  total: string = 'Total'
  cpuUser: string = 'User'
  cpuSystem: string = 'System'
  cpuIoWait: string = 'I/O wait'
  cpuSteal: string = 'Steal'
  cpuCore: string = 'Core'
  memoryUsed: string = 'Used'
  memoryCache: string = 'Buffer + cache'
  memoryZfs: string = 'ZFS ARC'
  memorySwap: string = 'Swap'
  rootFilesystem: string = 'Root filesystem'
}

export class MetricChartDefinition {
  key: string = ''
  label: string = ''

  constructor(key: string, label: string) {
    this.key = key
    this.label = label
  }
}

export class MetricChartPanelDefinition {
  kind: MetricChartPanelKind = MetricChartPanelKind.CPU_USAGE
  axisPolicy: MetricChartAxisPolicy = MetricChartAxisPolicy.AUTO
  valueFormat: MetricChartValueFormat = MetricChartValueFormat.NUMBER
  unit: string = ''

  constructor(kind: MetricChartPanelKind, axisPolicy: MetricChartAxisPolicy,
    valueFormat: MetricChartValueFormat, unit: string = '') {
    this.kind = kind
    this.axisPolicy = axisPolicy
    this.valueFormat = valueFormat
    this.unit = unit
  }
}

export interface MetricChartSource {
  panelDefinitions(): MetricChartPanelDefinition[]
  initialSeries(detail: SystemDetailState, labels: MetricChartLabels): MetricChartSeries[]
  initialValue(kind: MetricChartPanelKind, detail: SystemDetailState, key: string): number
  appendDefinitions(definitions: MetricChartDefinition[], stats: BeszelSystemStatsWire,
    labels: MetricChartLabels): void
  valueFor(kind: MetricChartPanelKind, stats: BeszelSystemStatsWire, key: string): number
}

export function pushChartDefinition(definitions: MetricChartDefinition[], key: string, label: string): void {
  if (!definitions.some((item: MetricChartDefinition) => item.key === key)) {
    definitions.push(new MetricChartDefinition(key, label))
  }
}

export function finiteChartValue(value: number | undefined): number {
  return value !== undefined && Number.isFinite(value) ? Math.max(0, value) : Number.NaN
}

export function chartArrayValue(values: number[] | null | undefined, index: number): number {
  if (values === undefined || values === null || index < 0 || index >= values.length) return Number.NaN
  return finiteChartValue(values[index])
}

export function scaledChartValue(value: number | undefined, scale: number): number {
  const finite = finiteChartValue(value)
  return Number.isFinite(finite) ? finite * scale : Number.NaN
}
