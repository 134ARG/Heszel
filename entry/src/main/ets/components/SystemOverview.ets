import {
  AppColorMode,
  ChartLineOpacity,
  ChartLineWidth,
  chartHeightVp,
  CpuChartHeight
} from '../model/AppearanceModels'
import { GpuMetricsState, HealthMetricsState, MetricTrendState, OverviewMetricsState } from '../model/SystemDetailModels'
import { AdaptiveMetricChart } from './AdaptiveMetricChart'
import { PressureBar } from './PressureBar'

@Component
export struct SystemOverview {
  @ObjectLink metrics: OverviewMetricsState
  @ObjectLink health: HealthMetricsState
  @ObjectLink gpu: GpuMetricsState
  @ObjectLink cpuTrend: MetricTrendState
  @Prop compact: boolean = false
  @Prop liveSampling: boolean = false
  @Prop cpuTrendLoading: boolean = false
  @Prop cpuChartHeight: CpuChartHeight = CpuChartHeight.DEFAULT
  @Prop colorMode: AppColorMode = AppColorMode.SYSTEM
  @Prop chartLineWidth: ChartLineWidth = ChartLineWidth.DEFAULT
  @Prop chartLineOpacity: ChartLineOpacity = ChartLineOpacity.DEFAULT

  build() {
    Column({ space: 18 }) {
      Column({ space: 14 }) {
        Text($r('app.string.resource_pressure'))
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
        Column({ space: 7 }) {
          Row() {
            Text($r('app.string.metric_cpu'))
              // .fontSize(13)
              // .fontColor($r('app.color.text_secondary'))
              .layoutWeight(1)
            Text(`${this.metrics.cpuPercent.toFixed(0)}%`)
              // .fontSize(13)
              // .fontWeight(FontWeight.Medium)
              // .fontColor($r('app.color.text_primary'))
          }
          .width('100%')
          AdaptiveMetricChart({
            state: this.cpuTrend.chart,
            loading: this.cpuTrendLoading,
            colorMode: this.colorMode,
            chartLineWidth: this.chartLineWidth,
            chartLineOpacity: this.chartLineOpacity,
            primarySeriesColor: $r('app.color.metric_cpu'),
            chartHeight: chartHeightVp(this.cpuChartHeight, this.compact, 67.2, 75.6),
            showLegend: false,
            sparseYAxisLabels: true
          })
          Row() {
            Text($r('app.string.latest_cpu_samples'))
              .fontSize(10)
              .fontColor($r('app.color.text_tertiary'))
              .layoutWeight(1)
            Text(this.liveSampling ? $r('app.string.sample_every_second') :
              $r('app.string.sample_every_minute'))
              .fontSize(10)
              .fontColor($r('app.color.text_tertiary'))
          }
          .width('100%')
        }
        .width('100%')
        PressureBar({ value: this.metrics.memoryPercent, label: $r('app.string.memory'), color: $r('app.color.metric_memory') })
        PressureBar({ value: this.metrics.diskPercent, label: $r('app.string.disk'), color: $r('app.color.metric_disk') })
        // info.g is the hub's "highest GPU" percent, matching the per-GPU bars below.
        if (this.gpu.isVisible()) {
          PressureBar({
            value: this.metrics.gpuPercent,
            label: $r('app.string.metric_gpu'),
            color: $r('app.color.metric_gpu')
          })
        }
      }
      .width('100%')
      .padding(18)
      .backgroundColor($r('app.color.surface'))
      .border({ width: 1, color: $r('app.color.card_border') })
      .borderRadius(16)

      if (this.compact) {
        Column({ space: 18 }) {
          this.loadAverage()
          Divider().color($r('app.color.divider'))
          Row({ space: 12 }) {
            Row() { this.temperature() }.layoutWeight(1)
            if (this.health.servicesVisible()) {
              Row() { this.services() }.layoutWeight(1)
            }
          }
          .alignItems(VerticalAlign.Top)
          .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(18)
        .backgroundColor($r('app.color.surface'))
        .border({ width: 1, color: $r('app.color.card_border') })
        .borderRadius(16)
      } else {
        Row({ space: 12 }) {
          Row() { this.loadAverage() }.layoutWeight(2)
          Row() { this.temperature() }.layoutWeight(1)
          if (this.health.servicesVisible()) {
            Row() { this.services() }.layoutWeight(1)
          }
        }
        .width('100%')
        .padding(18)
        .backgroundColor($r('app.color.surface'))
        .border({ width: 1, color: $r('app.color.card_border') })
        .borderRadius(16)
      }
    }
    .width('100%')
  }

  @Builder
  private loadAverage() {
    Column({ space: 8 }) {
      Text($r('app.string.load_average')).fontSize(11).fontColor($r('app.color.text_tertiary'))
      if (this.compact) {
        Text(`${this.metrics.loadOne.toFixed(2)}  ${this.metrics.loadFive.toFixed(2)}  ` +
          `${this.metrics.loadFifteen.toFixed(2)}`)
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.load_intervals_compact')).fontSize(11).fontColor($r('app.color.text_tertiary'))
      } else {
        Row({ space: 8 }) {
          this.loadValue(this.metrics.loadOne, $r('app.string.load_interval_1m'))
          this.loadValue(this.metrics.loadFive, $r('app.string.load_interval_5m'))
          this.loadValue(this.metrics.loadFifteen, $r('app.string.load_interval_15m'))
        }
        .width('100%')
      }
    }.alignItems(HorizontalAlign.Start).width('100%')
  }

  @Builder
  private loadValue(value: number, label: ResourceStr) {
    Column({ space: 3 }) {
      Text(value.toFixed(2))
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
      Text(label)
        .fontSize(11)
        .fontColor($r('app.color.text_tertiary'))
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
  }

  @Builder
  private temperature() {
    Column({ space: 8 }) {
      Text($r('app.string.temperature')).fontSize(11).fontColor($r('app.color.text_tertiary'))
      Text(this.metrics.temperatureCelsius > 0 ? `${this.metrics.temperatureCelsius.toFixed(0)} °C` : '—')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      Text($r('app.string.uptime_value', this.formatUptime(this.metrics.uptimeSeconds)))
        .fontSize(11)
        .fontColor($r('app.color.text_tertiary'))
    }.alignItems(HorizontalAlign.Start).width('100%')
  }

  @Builder
  private services() {
    Column({ space: 8 }) {
      Text($r('app.string.services')).fontSize(11).fontColor($r('app.color.text_tertiary'))
      Text($r('app.string.services_failed_count', this.health.servicesFailed))
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.health.servicesFailed > 0 ? $r('app.color.error_text') : $r('app.color.text_primary'))
      Text($r('app.string.services_healthy', this.healthyServices()))
        .fontSize(11)
        .fontColor($r('app.color.text_tertiary'))
    }.alignItems(HorizontalAlign.Start).width('100%')
  }

  private healthyServices(): number {
    return Math.max(0, this.health.servicesTotal - this.health.servicesFailed)
  }

  private formatUptime(seconds: number): string {
    if (seconds <= 0) return '—'
    const days = Math.floor(seconds / 86400)
    return days > 0 ? `${days}d` : `${Math.max(1, Math.floor(seconds / 3600))}h`
  }
}
