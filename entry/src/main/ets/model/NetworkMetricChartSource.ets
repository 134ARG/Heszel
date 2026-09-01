import { MetricChartAxisPolicy, MetricChartSeries, MetricChartValueFormat } from './MetricChartModels'
import { BeszelSystemStatsWire, SystemDetailState } from './SystemDetailModels'
import {
  chartArrayValue,
  CHART_BYTES_PER_MB,
  MetricChartDefinition,
  MetricChartPanelDefinition,
  pushChartDefinition,
  scaledChartValue,
  MetricChartLabels,
  MetricChartPanelKind,
  MetricChartSource
} from './MetricChartSource'

const NETWORK_TOTAL_KEY = '__total__'

export class NetworkMetricChartSource implements MetricChartSource {
  panelDefinitions(): MetricChartPanelDefinition[] {
    return [
      new MetricChartPanelDefinition(MetricChartPanelKind.NETWORK_UPLOAD,
        MetricChartAxisPolicy.ZERO_BASED, MetricChartValueFormat.BYTES_PER_SECOND),
      new MetricChartPanelDefinition(MetricChartPanelKind.NETWORK_DOWNLOAD,
        MetricChartAxisPolicy.ZERO_BASED, MetricChartValueFormat.BYTES_PER_SECOND)
    ]
  }

  initialSeries(detail: SystemDetailState, labels: MetricChartLabels): MetricChartSeries[] {
    if (detail.networkMetrics.interfaces.length === 0) {
      return [new MetricChartSeries(NETWORK_TOTAL_KEY, labels.total)]
    }
    return detail.networkMetrics.interfaces.map((networkInterface) =>
      new MetricChartSeries(networkInterface.name, networkInterface.name))
  }

  initialValue(kind: MetricChartPanelKind, detail: SystemDetailState, key: string): number {
    const upload = kind === MetricChartPanelKind.NETWORK_UPLOAD
    const download = kind === MetricChartPanelKind.NETWORK_DOWNLOAD
    if (!upload && !download) return Number.NaN
    if (key === NETWORK_TOTAL_KEY) {
      return upload ? detail.networkMetrics.uploadBytesPerSecond : detail.networkMetrics.downloadBytesPerSecond
    }
    const networkInterface = detail.networkMetrics.interfaces.find((item) => item.name === key)
    if (networkInterface === undefined) return Number.NaN
    return upload ? networkInterface.uploadBytesPerSecond : networkInterface.downloadBytesPerSecond
  }

  appendDefinitions(definitions: MetricChartDefinition[], stats: BeszelSystemStatsWire,
    labels: MetricChartLabels): void {
    if (stats.ni !== undefined && stats.ni !== null && Object.keys(stats.ni).length > 0) {
      Object.keys(stats.ni).forEach((name: string) => pushChartDefinition(definitions, name, name))
    } else if (stats.b !== undefined || stats.ns !== undefined || stats.nr !== undefined) {
      pushChartDefinition(definitions, NETWORK_TOTAL_KEY, labels.total)
    }
  }

  valueFor(kind: MetricChartPanelKind, stats: BeszelSystemStatsWire, key: string): number {
    const index = kind === MetricChartPanelKind.NETWORK_UPLOAD ? 0 :
      kind === MetricChartPanelKind.NETWORK_DOWNLOAD ? 1 : -1
    if (index < 0) return Number.NaN
    if (key !== NETWORK_TOTAL_KEY) return chartArrayValue(stats.ni?.[key], index)
    if (stats.b !== undefined && stats.b !== null) return chartArrayValue(stats.b, index)
    return scaledChartValue(index === 0 ? stats.ns : stats.nr, CHART_BYTES_PER_MB)
  }
}
