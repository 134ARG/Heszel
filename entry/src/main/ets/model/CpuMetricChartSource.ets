import { MetricChartAxisPolicy, MetricChartSeries, MetricChartValueFormat } from './MetricChartModels'
import { BeszelSystemStatsWire, SystemDetailState } from './SystemDetailModels'
import {
  chartArrayValue,
  finiteChartValue,
  MetricChartDefinition,
  MetricChartPanelDefinition,
  pushChartDefinition,
  MetricChartLabels,
  MetricChartPanelKind,
  MetricChartSource
} from './MetricChartSource'

const CPU_TOTAL_KEY = 'cpu'
const CPU_USER_KEY = 'cpu_user'
const CPU_SYSTEM_KEY = 'cpu_system'
const CPU_IO_WAIT_KEY = 'cpu_io_wait'
const CPU_STEAL_KEY = 'cpu_steal'
const CPU_CORE_PREFIX = 'cpu_core:'

export class CpuMetricChartSource implements MetricChartSource {
  panelDefinitions(): MetricChartPanelDefinition[] {
    return [
      new MetricChartPanelDefinition(MetricChartPanelKind.CPU_USAGE,
        MetricChartAxisPolicy.PERCENT, MetricChartValueFormat.NUMBER, '%', true, false, CPU_TOTAL_KEY),
      new MetricChartPanelDefinition(MetricChartPanelKind.CPU_CORES,
        MetricChartAxisPolicy.PERCENT, MetricChartValueFormat.NUMBER, '%', true, true)
    ]
  }

  initialSeries(kind: MetricChartPanelKind, detail: SystemDetailState,
    labels: MetricChartLabels): MetricChartSeries[] {
    const series: MetricChartSeries[] = []
    if (kind === MetricChartPanelKind.CPU_CORES) {
      detail.cpuMetrics.cores.forEach((core) => {
        series.push(new MetricChartSeries(`${CPU_CORE_PREFIX}${core.index}`, `${labels.cpuCore} ${core.index}`))
      })
      return series
    }
    if (kind !== MetricChartPanelKind.CPU_USAGE) return series
    series.push(new MetricChartSeries(CPU_TOTAL_KEY, labels.total))
    const keys = [CPU_USER_KEY, CPU_SYSTEM_KEY, CPU_IO_WAIT_KEY, CPU_STEAL_KEY]
    const names = [labels.cpuUser, labels.cpuSystem, labels.cpuIoWait, labels.cpuSteal]
    const count = Math.min(detail.cpuMetrics.breakdown.length, keys.length)
    for (let index = 0; index < count; index += 1) {
      series.push(new MetricChartSeries(keys[index], names[index]))
    }
    return series
  }

  initialValue(kind: MetricChartPanelKind, detail: SystemDetailState, key: string): number {
    if (kind === MetricChartPanelKind.CPU_CORES && key.startsWith(CPU_CORE_PREFIX)) {
      const coreIndex = Number(key.slice(CPU_CORE_PREFIX.length))
      const core = detail.cpuMetrics.cores.find((item) => item.index === coreIndex)
      return core !== undefined ? core.usagePercent : Number.NaN
    }
    if (kind !== MetricChartPanelKind.CPU_USAGE) return Number.NaN
    if (key === CPU_TOTAL_KEY) return detail.overview.cpuPercent
    if (key === CPU_USER_KEY) return chartArrayValue(detail.cpuMetrics.breakdown, 0)
    if (key === CPU_SYSTEM_KEY) return chartArrayValue(detail.cpuMetrics.breakdown, 1)
    if (key === CPU_IO_WAIT_KEY) return chartArrayValue(detail.cpuMetrics.breakdown, 2)
    if (key === CPU_STEAL_KEY) return chartArrayValue(detail.cpuMetrics.breakdown, 3)
    return Number.NaN
  }

  appendDefinitions(kind: MetricChartPanelKind, definitions: MetricChartDefinition[], stats: BeszelSystemStatsWire,
    labels: MetricChartLabels): void {
    if (kind === MetricChartPanelKind.CPU_CORES) {
      if (stats.cpus !== undefined && stats.cpus !== null) {
        for (let index = 0; index < stats.cpus.length; index += 1) {
          pushChartDefinition(definitions, `${CPU_CORE_PREFIX}${index}`, `${labels.cpuCore} ${index}`)
        }
      }
      return
    }
    if (kind !== MetricChartPanelKind.CPU_USAGE) return
    if (stats.cpu !== undefined) pushChartDefinition(definitions, CPU_TOTAL_KEY, labels.total)
    const keys = [CPU_USER_KEY, CPU_SYSTEM_KEY, CPU_IO_WAIT_KEY, CPU_STEAL_KEY]
    const names = [labels.cpuUser, labels.cpuSystem, labels.cpuIoWait, labels.cpuSteal]
    if (stats.cpub !== undefined && stats.cpub !== null) {
      for (let index = 0; index < Math.min(stats.cpub.length, keys.length); index += 1) {
        pushChartDefinition(definitions, keys[index], names[index])
      }
    }
  }

  valueFor(kind: MetricChartPanelKind, stats: BeszelSystemStatsWire, key: string): number {
    if (kind === MetricChartPanelKind.CPU_CORES && key.startsWith(CPU_CORE_PREFIX)) {
      return chartArrayValue(stats.cpus, Number(key.slice(CPU_CORE_PREFIX.length)))
    }
    if (kind !== MetricChartPanelKind.CPU_USAGE) return Number.NaN
    if (key === CPU_TOTAL_KEY) return finiteChartValue(stats.cpu)
    if (key === CPU_USER_KEY) return chartArrayValue(stats.cpub, 0)
    if (key === CPU_SYSTEM_KEY) return chartArrayValue(stats.cpub, 1)
    if (key === CPU_IO_WAIT_KEY) return chartArrayValue(stats.cpub, 2)
    if (key === CPU_STEAL_KEY) return chartArrayValue(stats.cpub, 3)
    return Number.NaN
  }
}
