import { MetricChartAxisPolicy, MetricChartSeries, MetricChartValueFormat } from './MetricChartModels'
import {
  BeszelFilesystemStatsWire,
  BeszelSystemStatsWire,
  FilesystemMetric,
  SystemDetailState
} from './SystemDetailModels'
import {
  chartArrayValue,
  CHART_BYTES_PER_MB,
  finiteChartValue,
  MetricChartDefinition,
  MetricChartLabels,
  MetricChartPanelDefinition,
  MetricChartPanelKind,
  MetricChartSource,
  pushChartDefinition,
  scaledChartValue
} from './MetricChartSource'

const STORAGE_ROOT_KEY = '__storage_root__'
const STORAGE_FILESYSTEM_PREFIX = 'filesystem:'

export class StorageMetricChartSource implements MetricChartSource {
  panelDefinitions(): MetricChartPanelDefinition[] {
    return [
      new MetricChartPanelDefinition(MetricChartPanelKind.STORAGE_USAGE,
        MetricChartAxisPolicy.PERCENT, MetricChartValueFormat.NUMBER, '%'),
      new MetricChartPanelDefinition(MetricChartPanelKind.STORAGE_READ,
        MetricChartAxisPolicy.ZERO_BASED, MetricChartValueFormat.BYTES_PER_SECOND),
      new MetricChartPanelDefinition(MetricChartPanelKind.STORAGE_WRITE,
        MetricChartAxisPolicy.ZERO_BASED, MetricChartValueFormat.BYTES_PER_SECOND)
    ]
  }

  initialSeries(detail: SystemDetailState, labels: MetricChartLabels): MetricChartSeries[] {
    const series: MetricChartSeries[] = [
      new MetricChartSeries(STORAGE_ROOT_KEY, labels.rootFilesystem)
    ]
    detail.storageMetrics.filesystems.forEach((filesystem: FilesystemMetric) => {
      series.push(new MetricChartSeries(this.filesystemKey(filesystem.name), filesystem.name))
    })
    return series
  }

  initialValue(kind: MetricChartPanelKind, detail: SystemDetailState, key: string): number {
    if (key === STORAGE_ROOT_KEY) {
      if (kind === MetricChartPanelKind.STORAGE_USAGE) return detail.storageMetrics.percent
      if (kind === MetricChartPanelKind.STORAGE_READ) return detail.storageMetrics.readBytesPerSecond
      if (kind === MetricChartPanelKind.STORAGE_WRITE) return detail.storageMetrics.writeBytesPerSecond
      return Number.NaN
    }
    const name = this.filesystemName(key)
    if (name === null) return Number.NaN
    const filesystem = detail.storageMetrics.filesystems.find((item: FilesystemMetric) => item.name === name)
    if (filesystem === undefined) return Number.NaN
    if (kind === MetricChartPanelKind.STORAGE_USAGE) {
      return this.usagePercent(filesystem.usedGb, filesystem.totalGb)
    }
    if (kind === MetricChartPanelKind.STORAGE_READ) return filesystem.readBytesPerSecond
    if (kind === MetricChartPanelKind.STORAGE_WRITE) return filesystem.writeBytesPerSecond
    return Number.NaN
  }

  appendDefinitions(definitions: MetricChartDefinition[], stats: BeszelSystemStatsWire,
    labels: MetricChartLabels): void {
    if (this.hasRootStats(stats)) {
      pushChartDefinition(definitions, STORAGE_ROOT_KEY, labels.rootFilesystem)
    }
    if (stats.efs === undefined || stats.efs === null) return
    Object.keys(stats.efs).forEach((name: string) => {
      pushChartDefinition(definitions, this.filesystemKey(name), name)
    })
  }

  valueFor(kind: MetricChartPanelKind, stats: BeszelSystemStatsWire, key: string): number {
    if (key === STORAGE_ROOT_KEY) return this.rootValue(kind, stats)
    const name = this.filesystemName(key)
    if (name === null) return Number.NaN
    const filesystem = stats.efs?.[name]
    if (filesystem === undefined) return Number.NaN
    return this.filesystemValue(kind, filesystem)
  }

  private rootValue(kind: MetricChartPanelKind, stats: BeszelSystemStatsWire): number {
    if (kind === MetricChartPanelKind.STORAGE_USAGE) {
      if (stats.dp !== undefined) return finiteChartValue(stats.dp)
      return this.usagePercent(stats.du, stats.d)
    }
    if (kind === MetricChartPanelKind.STORAGE_READ) {
      if (stats.dio !== undefined && stats.dio !== null) return chartArrayValue(stats.dio, 0)
      return scaledChartValue(stats.dr, CHART_BYTES_PER_MB)
    }
    if (kind === MetricChartPanelKind.STORAGE_WRITE) {
      if (stats.dio !== undefined && stats.dio !== null) return chartArrayValue(stats.dio, 1)
      return scaledChartValue(stats.dw, CHART_BYTES_PER_MB)
    }
    return Number.NaN
  }

  private filesystemValue(kind: MetricChartPanelKind, filesystem: BeszelFilesystemStatsWire): number {
    if (kind === MetricChartPanelKind.STORAGE_USAGE) {
      return this.usagePercent(filesystem.du, filesystem.d)
    }
    if (kind === MetricChartPanelKind.STORAGE_READ) {
      if (filesystem.rb !== undefined) return finiteChartValue(filesystem.rb)
      return scaledChartValue(filesystem.r, CHART_BYTES_PER_MB)
    }
    if (kind === MetricChartPanelKind.STORAGE_WRITE) {
      if (filesystem.wb !== undefined) return finiteChartValue(filesystem.wb)
      return scaledChartValue(filesystem.w, CHART_BYTES_PER_MB)
    }
    return Number.NaN
  }

  private usagePercent(used: number | undefined, total: number | undefined): number {
    if (used === undefined || total === undefined || !Number.isFinite(used) ||
      !Number.isFinite(total) || total <= 0) return Number.NaN
    return Math.max(0, used / total * 100)
  }

  private hasRootStats(stats: BeszelSystemStatsWire): boolean {
    return stats.d !== undefined || stats.du !== undefined || stats.dp !== undefined ||
      stats.dio !== undefined && stats.dio !== null || stats.dr !== undefined || stats.dw !== undefined
  }

  private filesystemKey(name: string): string {
    return `${STORAGE_FILESYSTEM_PREFIX}${name}`
  }

  private filesystemName(key: string): string | null {
    return key.startsWith(STORAGE_FILESYSTEM_PREFIX) ? key.slice(STORAGE_FILESYSTEM_PREFIX.length) : null
  }
}
