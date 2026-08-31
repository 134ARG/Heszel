import { MetricChartAxisPolicy, MetricChartSeries, MetricChartValueFormat } from './MetricChartModels'
import { BeszelSystemStatsWire, SensorMetric, SystemDetailState } from './SystemDetailModels'
import {
  MetricChartDefinition,
  MetricChartPanelDefinition,
  pushChartDefinition,
  MetricChartLabels,
  MetricChartPanelKind,
  MetricChartSource
} from './MetricChartSource'

export class HealthMetricChartSource implements MetricChartSource {
  panelDefinitions(): MetricChartPanelDefinition[] {
    return [new MetricChartPanelDefinition(MetricChartPanelKind.HEALTH_TEMPERATURE,
      MetricChartAxisPolicy.AUTO, MetricChartValueFormat.NUMBER, '°C')]
  }

  initialSeries(detail: SystemDetailState, labels: MetricChartLabels): MetricChartSeries[] {
    const ranked = detail.healthMetrics.sensors.slice().sort((left: SensorMetric, right: SensorMetric) =>
      right.temperatureCelsius - left.temperatureCelsius)
    return ranked.map((sensor: SensorMetric, index: number) =>
      new MetricChartSeries(sensor.name, sensor.name, index < 4))
  }

  initialValue(kind: MetricChartPanelKind, detail: SystemDetailState, key: string): number {
    if (kind !== MetricChartPanelKind.HEALTH_TEMPERATURE) return Number.NaN
    const sensor = detail.healthMetrics.sensors.find((item: SensorMetric) => item.name === key)
    return sensor !== undefined ? sensor.temperatureCelsius : Number.NaN
  }

  appendDefinitions(definitions: MetricChartDefinition[], stats: BeszelSystemStatsWire,
    labels: MetricChartLabels): void {
    if (stats.t === undefined || stats.t === null) return
    Object.keys(stats.t).sort().forEach((name: string) => pushChartDefinition(definitions, name, name))
  }

  valueFor(kind: MetricChartPanelKind, stats: BeszelSystemStatsWire, key: string): number {
    if (kind !== MetricChartPanelKind.HEALTH_TEMPERATURE) return Number.NaN
    const value = stats.t?.[key]
    return value !== undefined && Number.isFinite(value) ? value : Number.NaN
  }
}
