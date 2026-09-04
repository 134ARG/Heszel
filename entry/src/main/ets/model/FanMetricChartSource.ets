import { MetricChartAxisPolicy, MetricChartSeries, MetricChartValueFormat } from './MetricChartModels'
import { BeszelSystemStatsWire, FanMetric, SystemDetailState } from './SystemDetailModels'
import {
  finiteChartValue,
  MetricChartDefinition,
  MetricChartLabels,
  MetricChartPanelDefinition,
  MetricChartPanelKind,
  MetricChartSource,
  pushChartDefinition
} from './MetricChartSource'

export class FanMetricChartSource implements MetricChartSource {
  panelDefinitions(): MetricChartPanelDefinition[] {
    return [new MetricChartPanelDefinition(MetricChartPanelKind.FAN_SPEED,
      MetricChartAxisPolicy.ZERO_BASED, MetricChartValueFormat.INTEGER, ' RPM')]
  }

  initialSeries(_kind: MetricChartPanelKind, detail: SystemDetailState,
    _labels: MetricChartLabels): MetricChartSeries[] {
    const ranked = detail.fanMetrics.fans.slice().sort((left: FanMetric, right: FanMetric) =>
      right.rpm - left.rpm)
    return ranked.map((fan: FanMetric) => new MetricChartSeries(fan.name, fan.name))
  }

  initialValue(kind: MetricChartPanelKind, detail: SystemDetailState, key: string): number {
    if (kind !== MetricChartPanelKind.FAN_SPEED) return Number.NaN
    const fan = detail.fanMetrics.fans.find((item: FanMetric) => item.name === key)
    return fan !== undefined ? fan.rpm : Number.NaN
  }

  appendDefinitions(kind: MetricChartPanelKind, definitions: MetricChartDefinition[], stats: BeszelSystemStatsWire,
    _labels: MetricChartLabels): void {
    if (kind !== MetricChartPanelKind.FAN_SPEED || stats.f === undefined || stats.f === null) return
    Object.keys(stats.f).sort().forEach((name: string) => pushChartDefinition(definitions, name, name))
  }

  valueFor(kind: MetricChartPanelKind, stats: BeszelSystemStatsWire, key: string): number {
    if (kind !== MetricChartPanelKind.FAN_SPEED) return Number.NaN
    return finiteChartValue(stats.f?.[key])
  }
}
