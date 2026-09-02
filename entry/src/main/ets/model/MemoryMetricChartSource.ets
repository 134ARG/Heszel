import { MetricChartAxisPolicy, MetricChartSeries, MetricChartValueFormat } from './MetricChartModels'
import { BeszelSystemStatsWire, SystemDetailState } from './SystemDetailModels'
import {
  CHART_BYTES_PER_GB,
  MetricChartDefinition,
  MetricChartPanelDefinition,
  pushChartDefinition,
  scaledChartValue,
  MetricChartLabels,
  MetricChartPanelKind,
  MetricChartSource
} from './MetricChartSource'

const MEMORY_USED_KEY = 'memory_used'
const MEMORY_CACHE_KEY = 'memory_cache'
const MEMORY_ZFS_KEY = 'memory_zfs'
const MEMORY_SWAP_KEY = 'memory_swap'

export class MemoryMetricChartSource implements MetricChartSource {
  panelDefinitions(): MetricChartPanelDefinition[] {
    return [new MetricChartPanelDefinition(MetricChartPanelKind.MEMORY_USAGE,
      MetricChartAxisPolicy.ZERO_BASED, MetricChartValueFormat.BYTES)]
  }

  initialSeries(_kind: MetricChartPanelKind, detail: SystemDetailState,
    labels: MetricChartLabels): MetricChartSeries[] {
    const series: MetricChartSeries[] = [new MetricChartSeries(MEMORY_USED_KEY, labels.memoryUsed)]
    if (detail.memoryMetrics.cacheGb > 0) {
      series.push(new MetricChartSeries(MEMORY_CACHE_KEY, labels.memoryCache))
    }
    if (detail.memoryMetrics.zfsArcGb > 0) {
      series.push(new MetricChartSeries(MEMORY_ZFS_KEY, labels.memoryZfs))
    }
    if (detail.memoryMetrics.swapTotalGb > 0 || detail.memoryMetrics.swapUsedGb > 0) {
      series.push(new MetricChartSeries(MEMORY_SWAP_KEY, labels.memorySwap))
    }
    return series
  }

  initialValue(kind: MetricChartPanelKind, detail: SystemDetailState, key: string): number {
    if (kind !== MetricChartPanelKind.MEMORY_USAGE) return Number.NaN
    if (key === MEMORY_USED_KEY) return detail.memoryMetrics.usedGb * CHART_BYTES_PER_GB
    if (key === MEMORY_CACHE_KEY) return detail.memoryMetrics.cacheGb * CHART_BYTES_PER_GB
    if (key === MEMORY_ZFS_KEY) return detail.memoryMetrics.zfsArcGb * CHART_BYTES_PER_GB
    if (key === MEMORY_SWAP_KEY) return detail.memoryMetrics.swapUsedGb * CHART_BYTES_PER_GB
    return Number.NaN
  }

  appendDefinitions(_kind: MetricChartPanelKind, definitions: MetricChartDefinition[], stats: BeszelSystemStatsWire,
    labels: MetricChartLabels): void {
    if (stats.mu !== undefined) pushChartDefinition(definitions, MEMORY_USED_KEY, labels.memoryUsed)
    if (stats.mb !== undefined) pushChartDefinition(definitions, MEMORY_CACHE_KEY, labels.memoryCache)
    if (stats.mz !== undefined) pushChartDefinition(definitions, MEMORY_ZFS_KEY, labels.memoryZfs)
    if (stats.su !== undefined) pushChartDefinition(definitions, MEMORY_SWAP_KEY, labels.memorySwap)
  }

  valueFor(kind: MetricChartPanelKind, stats: BeszelSystemStatsWire, key: string): number {
    if (kind !== MetricChartPanelKind.MEMORY_USAGE) return Number.NaN
    if (key === MEMORY_USED_KEY) return scaledChartValue(stats.mu, CHART_BYTES_PER_GB)
    if (key === MEMORY_CACHE_KEY) return scaledChartValue(stats.mb, CHART_BYTES_PER_GB)
    if (key === MEMORY_ZFS_KEY) return scaledChartValue(stats.mz, CHART_BYTES_PER_GB)
    if (key === MEMORY_SWAP_KEY) return scaledChartValue(stats.su, CHART_BYTES_PER_GB)
    return Number.NaN
  }
}
