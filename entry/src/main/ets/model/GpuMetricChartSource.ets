import { MetricChartAxisPolicy, MetricChartSeries, MetricChartValueFormat } from './MetricChartModels'
import { BeszelSystemStatsWire, SystemDetailState } from './SystemDetailModels'
import {
  CHART_BYTES_PER_MB,
  finiteChartValue,
  MetricChartDefinition,
  MetricChartPanelDefinition,
  pushChartDefinition,
  scaledChartValue,
  MetricChartLabels,
  MetricChartPanelKind,
  MetricChartSource
} from './MetricChartSource'

export class GpuMetricChartSource implements MetricChartSource {
  panelDefinitions(): MetricChartPanelDefinition[] {
    return [
      new MetricChartPanelDefinition(MetricChartPanelKind.GPU_USAGE,
        MetricChartAxisPolicy.PERCENT, MetricChartValueFormat.NUMBER, '%'),
      new MetricChartPanelDefinition(MetricChartPanelKind.GPU_MEMORY,
        MetricChartAxisPolicy.ZERO_BASED, MetricChartValueFormat.BYTES),
      new MetricChartPanelDefinition(MetricChartPanelKind.GPU_POWER,
        MetricChartAxisPolicy.ZERO_BASED, MetricChartValueFormat.NUMBER, 'W')
    ]
  }

  initialSeries(detail: SystemDetailState, labels: MetricChartLabels): MetricChartSeries[] {
    return detail.gpuMetrics.gpus.map((gpu) => new MetricChartSeries(gpu.id, gpu.name))
  }

  initialValue(kind: MetricChartPanelKind, detail: SystemDetailState, key: string): number {
    const gpu = detail.gpuMetrics.gpus.find((item) => item.id === key)
    if (gpu === undefined) return Number.NaN
    if (kind === MetricChartPanelKind.GPU_USAGE) return gpu.usagePercent
    if (kind === MetricChartPanelKind.GPU_MEMORY) {
      return gpu.hasMemory ? gpu.memoryUsedMb * CHART_BYTES_PER_MB : Number.NaN
    }
    if (kind === MetricChartPanelKind.GPU_POWER) return gpu.hasPower ? gpu.powerWatts : Number.NaN
    return Number.NaN
  }

  appendDefinitions(definitions: MetricChartDefinition[], stats: BeszelSystemStatsWire,
    labels: MetricChartLabels): void {
    if (stats.g === undefined || stats.g === null) return
    Object.keys(stats.g).forEach((id: string) => {
      pushChartDefinition(definitions, id, stats.g?.[id].n ?? id)
    })
  }

  valueFor(kind: MetricChartPanelKind, stats: BeszelSystemStatsWire, key: string): number {
    const gpu = stats.g?.[key]
    if (gpu === undefined) return Number.NaN
    if (kind === MetricChartPanelKind.GPU_USAGE) return finiteChartValue(gpu.u)
    if (kind === MetricChartPanelKind.GPU_MEMORY) return scaledChartValue(gpu.mu, CHART_BYTES_PER_MB)
    if (kind === MetricChartPanelKind.GPU_POWER) {
      return finiteChartValue(gpu.pp !== undefined ? gpu.pp : gpu.p)
    }
    return Number.NaN
  }
}
