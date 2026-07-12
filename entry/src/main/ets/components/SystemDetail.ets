import { SystemMetric, SystemSummary } from '../model/BeszelModels'
import { SystemDetailState } from '../model/SystemDetailModels'
import { ContainersCard } from './ContainersCard'
import { CpuCard } from './CpuCard'
import { GpuCard } from './GpuCard'
import { HardwareCard } from './HardwareCard'
import { HealthCard } from './HealthCard'
import { MemoryCard } from './MemoryCard'
import { NetworkCard } from './NetworkCard'
import { PressureBar } from './PressureBar'
import { MetricTile } from './MetricTile'
import { StorageCard } from './StorageCard'

@Component
export struct SystemDetail {
  @ObjectLink system: SystemSummary
  @ObjectLink detail: SystemDetailState
  @Prop compact: boolean = false

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Row({ space: 12 }) {
          Row()
            .width(11)
            .height(11)
            .borderRadius(6)
            .backgroundColor(this.system.isUp() ? $r('app.color.status_up') : $r('app.color.status_down'))
          Column({ space: 3 }) {
            Text(this.system.name)
              .fontSize(this.compact ? 24 : 28)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.system.host.length > 0 ? this.system.host : 'No host label')
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Text(this.system.status.toUpperCase())
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.system.isUp() ? $r('app.color.action') : $r('app.color.status_down_text'))
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor(this.system.isUp() ?
              $r('app.color.action_surface') : $r('app.color.status_down_surface'))
            .borderRadius(8)
        }
        .width('100%')

        if (this.compact) {
          Column({ space: 12 }) {
            Row({ space: 12 }) {
              MetricTile({ value: this.metricValue(SystemMetric.CPU), label: 'CPU', suffix: '%' })
              MetricTile({ value: this.metricValue(SystemMetric.Memory), label: 'Memory', suffix: '%' })
            }
            .width('100%')
            Row({ space: 12 }) {
              MetricTile({ value: this.metricValue(SystemMetric.Disk), label: 'Disk', suffix: '%' })
              MetricTile({ value: this.metricValue(SystemMetric.GPU), label: 'GPU', suffix: '%' })
            }
            .width('100%')
          }
          .width('100%')
        } else {
          Row({ space: 12 }) {
            MetricTile({ value: this.metricValue(SystemMetric.CPU), label: 'CPU', suffix: '%' })
            MetricTile({ value: this.metricValue(SystemMetric.Memory), label: 'Memory', suffix: '%' })
            MetricTile({ value: this.metricValue(SystemMetric.Disk), label: 'Disk', suffix: '%' })
            MetricTile({ value: this.metricValue(SystemMetric.GPU), label: 'GPU', suffix: '%' })
          }
          .width('100%')
        }

        Column({ space: 14 }) {
          Text('Resource pressure')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
          PressureBar({
            value: this.metricValue(SystemMetric.CPU),
            label: 'CPU',
            color: $r('app.color.metric_cpu')
          })
          PressureBar({
            value: this.metricValue(SystemMetric.Memory),
            label: 'Memory',
            color: $r('app.color.metric_memory')
          })
          PressureBar({
            value: this.metricValue(SystemMetric.Disk),
            label: 'Disk',
            color: $r('app.color.metric_disk')
          })
        }
        .width('100%')
        .padding(18)
        .backgroundColor($r('app.color.surface'))
        .borderRadius(16)

        if (this.compact) {
          Column({ space: 18 }) {
            this.loadAverage()
            Divider()
              .color($r('app.color.divider'))
            this.temperature()
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(18)
          .backgroundColor($r('app.color.surface'))
          .borderRadius(16)
        } else {
          Row({ space: 12 }) {
            Row() {
              this.loadAverage()
            }
            .layoutWeight(1)

            Row() {
              this.temperature()
            }
            .layoutWeight(1)
          }
          .width('100%')
          .padding(18)
          .backgroundColor($r('app.color.surface'))
          .borderRadius(16)
        }

        if (this.detail.loading && !this.detail.loaded) {
          Row({ space: 10 }) {
            LoadingProgress()
              .width(20)
              .height(20)
              .color($r('app.color.action'))
            Text('Loading detailed metrics…')
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.surface'))
          .borderRadius(14)
        }

        if (this.detail.errorMessage.length > 0) {
          Text(this.detail.errorMessage)
            .fontSize(12)
            .fontColor($r('app.color.error_text'))
            .width('100%')
            .padding(14)
            .backgroundColor($r('app.color.error_surface'))
            .borderRadius(12)
        }

        if (this.compact) {
          Column({ space: 14 }) {
            this.primaryDetailCards()
            this.secondaryDetailCards()
          }
          .width('100%')
        } else {
          Row({ space: 14 }) {
            Column({ space: 14 }) {
              this.primaryDetailCards()
            }
            .layoutWeight(1)

            Column({ space: 14 }) {
              this.secondaryDetailCards()
            }
            .layoutWeight(1)
          }
          .alignItems(VerticalAlign.Top)
          .width('100%')
        }
      }
      .width('100%')
      .padding({
        left: this.compact ? 16 : 22,
        right: this.compact ? 16 : 22,
        top: this.compact ? 14 : 20,
        bottom: 30
      })
    }
    .layoutWeight(1)
    .height('100%')
    .scrollBar(BarState.Off)
  }

  @Builder
  private primaryDetailCards() {
    if (this.detail.hardware.hasData()) {
      HardwareCard({ detail: this.detail, system: this.system })
    }
    if (this.detail.hasMetrics) {
      MemoryCard({ detail: this.detail })
      StorageCard({ detail: this.detail })
    }
  }

  @Builder
  private secondaryDetailCards() {
    if (this.detail.hasMetrics &&
      (this.detail.metrics.cpuBreakdown.length > 0 || this.detail.metrics.cpuCores.length > 0)) {
      CpuCard({ detail: this.detail, compact: this.compact })
    }
    if (this.detail.hasMetrics) {
      NetworkCard({ detail: this.detail })
    }
    if (this.detail.metrics.gpus.length > 0) {
      GpuCard({ detail: this.detail })
    }
    if (this.detail.metrics.sensors.length > 0 || this.detail.metrics.batteryPercent > 0 ||
      this.system.batteryPercent > 0 || this.system.servicesTotal > 0) {
      HealthCard({ detail: this.detail, system: this.system })
    }
    if (this.detail.containers.length > 0) {
      ContainersCard({ detail: this.detail })
    }
  }

  private metricValue(metric: SystemMetric): number {
    if (metric === SystemMetric.GPU) {
      return this.system.metricValue(metric)
    }
    return this.detail.hasMetrics ? this.detail.metrics.metricValue(metric) : this.system.metricValue(metric)
  }
  @Builder
  private loadAverage() {
    Column({ space: 8 }) {
      Text('LOAD AVERAGE')
        .fontSize(11)
        .fontColor($r('app.color.text_tertiary'))
      Text(`${this.system.loadOne.toFixed(2)}  ${this.system.loadFive.toFixed(2)}  ${this.system.loadFifteen.toFixed(2)}`)
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      Text('1m       5m       15m')
        .fontSize(11)
        .fontColor($r('app.color.text_tertiary'))
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  private temperature() {
    Column({ space: 8 }) {
      Text('TEMPERATURE')
        .fontSize(11)
        .fontColor($r('app.color.text_tertiary'))
      Text(this.system.temperatureCelsius > 0 ? `${this.system.temperatureCelsius.toFixed(0)} °C` : '—')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      Text(`Uptime ${this.formatUptime(this.system.uptimeSeconds)}`)
        .fontSize(11)
        .fontColor($r('app.color.text_tertiary'))
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  private formatUptime(seconds: number): string {
    if (seconds <= 0) {
      return '—'
    }
    const days = Math.floor(seconds / 86400)
    if (days > 0) {
      return `${days}d`
    }
    return `${Math.max(1, Math.floor(seconds / 3600))}h`
  }
}
