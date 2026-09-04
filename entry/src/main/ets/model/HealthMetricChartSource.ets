import { MetricChartAxisPolicy, MetricChartSeries, MetricChartValueFormat } from './MetricChartModels'
import {
  BeszelSystemStatsWire,
  HumidityMetric,
  SensorMetric,
  SystemDetailState
} from './SystemDetailModels'
import {
  MetricChartDefinition,
  MetricChartPanelDefinition,
  pushChartDefinition,
  MetricChartLabels,
  MetricChartPanelKind,
  MetricChartSource
} from './MetricChartSource'

export class HealthMetricChartSource implements MetricChartSource {
  private readonly temperaturesAvailable: boolean
  private readonly humidityAvailable: boolean

  constructor(detail: SystemDetailState) {
    this.temperaturesAvailable = detail.healthMetrics.sensorsAvailable
    this.humidityAvailable = detail.healthMetrics.humidityAvailable
  }

  panelDefinitions(): MetricChartPanelDefinition[] {
    const panels: MetricChartPanelDefinition[] = []
    if (this.temperaturesAvailable) {
      panels.push(new MetricChartPanelDefinition(MetricChartPanelKind.HEALTH_TEMPERATURE,
        MetricChartAxisPolicy.AUTO, MetricChartValueFormat.NUMBER, '°C'))
    }
    if (this.humidityAvailable) {
      panels.push(new MetricChartPanelDefinition(MetricChartPanelKind.HEALTH_HUMIDITY,
        MetricChartAxisPolicy.AUTO, MetricChartValueFormat.NUMBER, '%'))
    }
    return panels
  }

  initialSeries(kind: MetricChartPanelKind, detail: SystemDetailState,
    _labels: MetricChartLabels): MetricChartSeries[] {
    if (kind === MetricChartPanelKind.HEALTH_HUMIDITY) {
      const ranked = detail.healthMetrics.humidities.slice().sort(
        (left: HumidityMetric, right: HumidityMetric) =>
          right.relativeHumidityPercent - left.relativeHumidityPercent)
      return ranked.map((humidity: HumidityMetric) => new MetricChartSeries(humidity.name, humidity.name))
    }
    const ranked = detail.healthMetrics.sensors.slice().sort((left: SensorMetric, right: SensorMetric) =>
      right.temperatureCelsius - left.temperatureCelsius)
    return ranked.map((sensor: SensorMetric) => new MetricChartSeries(sensor.name, sensor.name))
  }

  initialValue(kind: MetricChartPanelKind, detail: SystemDetailState, key: string): number {
    if (kind === MetricChartPanelKind.HEALTH_TEMPERATURE) {
      const sensor = detail.healthMetrics.sensors.find((item: SensorMetric) => item.name === key)
      return sensor !== undefined ? sensor.temperatureCelsius : Number.NaN
    }
    if (kind === MetricChartPanelKind.HEALTH_HUMIDITY) {
      const humidity = detail.healthMetrics.humidities.find((item: HumidityMetric) => item.name === key)
      return humidity !== undefined ? humidity.relativeHumidityPercent : Number.NaN
    }
    return Number.NaN
  }

  appendDefinitions(kind: MetricChartPanelKind, definitions: MetricChartDefinition[], stats: BeszelSystemStatsWire,
    _labels: MetricChartLabels): void {
    const values = kind === MetricChartPanelKind.HEALTH_TEMPERATURE ? stats.t : stats.hum
    if (values === undefined || values === null) return
    Object.keys(values).sort().forEach((name: string) => pushChartDefinition(definitions, name, name))
  }

  valueFor(kind: MetricChartPanelKind, stats: BeszelSystemStatsWire, key: string): number {
    if (kind === MetricChartPanelKind.HEALTH_TEMPERATURE) {
      const value = stats.t?.[key]
      return value !== undefined && Number.isFinite(value) ? value : Number.NaN
    }
    if (kind === MetricChartPanelKind.HEALTH_HUMIDITY) {
      const value = stats.hum?.[key]
      return value !== undefined && Number.isFinite(value) ? Math.min(100, Math.max(0, value)) : Number.NaN
    }
    return Number.NaN
  }
}
