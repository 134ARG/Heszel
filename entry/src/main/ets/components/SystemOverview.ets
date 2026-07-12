import { OverviewMetricsState } from '../model/SystemDetailModels'
import { MetricTile } from './MetricTile'
import { PressureBar } from './PressureBar'

@Component
export struct SystemOverview {
  @ObjectLink metrics: OverviewMetricsState
  @Prop compact: boolean = false

  build() {
    Column({ space: 18 }) {
      if (this.compact) {
        Column({ space: 12 }) {
          Row({ space: 12 }) {
            MetricTile({ value: this.metrics.cpuPercent, label: 'CPU', suffix: '%' })
            MetricTile({ value: this.metrics.memoryPercent, label: 'Memory', suffix: '%' })
          }.width('100%')
          Row({ space: 12 }) {
            MetricTile({ value: this.metrics.diskPercent, label: 'Disk', suffix: '%' })
            MetricTile({ value: this.metrics.gpuPercent, label: 'GPU', suffix: '%' })
          }.width('100%')
        }.width('100%')
      } else {
        Row({ space: 12 }) {
          MetricTile({ value: this.metrics.cpuPercent, label: 'CPU', suffix: '%' })
          MetricTile({ value: this.metrics.memoryPercent, label: 'Memory', suffix: '%' })
          MetricTile({ value: this.metrics.diskPercent, label: 'Disk', suffix: '%' })
          MetricTile({ value: this.metrics.gpuPercent, label: 'GPU', suffix: '%' })
        }.width('100%')
      }

      Column({ space: 14 }) {
        Text('Resource pressure')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
        PressureBar({ value: this.metrics.cpuPercent, label: 'CPU', color: $r('app.color.metric_cpu') })
        PressureBar({ value: this.metrics.memoryPercent, label: 'Memory', color: $r('app.color.metric_memory') })
        PressureBar({ value: this.metrics.diskPercent, label: 'Disk', color: $r('app.color.metric_disk') })
      }
      .width('100%')
      .padding(18)
      .backgroundColor($r('app.color.surface'))
      .borderRadius(16)

      if (this.compact) {
        Column({ space: 18 }) {
          this.loadAverage()
          Divider().color($r('app.color.divider'))
          this.temperature()
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(18)
        .backgroundColor($r('app.color.surface'))
        .borderRadius(16)
      } else {
        Row({ space: 12 }) {
          Row() { this.loadAverage() }.layoutWeight(1)
          Row() { this.temperature() }.layoutWeight(1)
        }
        .width('100%')
        .padding(18)
        .backgroundColor($r('app.color.surface'))
        .borderRadius(16)
      }
    }
    .width('100%')
  }

  @Builder
  private loadAverage() {
    Column({ space: 8 }) {
      Text('LOAD AVERAGE').fontSize(11).fontColor($r('app.color.text_tertiary'))
      Text(`${this.metrics.loadOne.toFixed(2)}  ${this.metrics.loadFive.toFixed(2)}  ${this.metrics.loadFifteen.toFixed(2)}`)
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      Text('1m       5m       15m').fontSize(11).fontColor($r('app.color.text_tertiary'))
    }.alignItems(HorizontalAlign.Start).width('100%')
  }

  @Builder
  private temperature() {
    Column({ space: 8 }) {
      Text('TEMPERATURE').fontSize(11).fontColor($r('app.color.text_tertiary'))
      Text(this.metrics.temperatureCelsius > 0 ? `${this.metrics.temperatureCelsius.toFixed(0)} °C` : '—')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      Text(`Uptime ${this.formatUptime(this.metrics.uptimeSeconds)}`)
        .fontSize(11)
        .fontColor($r('app.color.text_tertiary'))
    }.alignItems(HorizontalAlign.Start).width('100%')
  }

  private formatUptime(seconds: number): string {
    if (seconds <= 0) return '—'
    const days = Math.floor(seconds / 86400)
    return days > 0 ? `${days}d` : `${Math.max(1, Math.floor(seconds / 3600))}h`
  }
}
