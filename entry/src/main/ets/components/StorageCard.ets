import { FilesystemMetric, StorageMetricsState } from '../model/SystemDetailModels'
import { formatGigabytes, formatRate } from './DetailFormatting'
import { DetailCardHeader } from './DetailCardHeader'
import { DetailValueRow } from './DetailValueRow'
import { PressureBar } from './PressureBar'

@Component
export struct StorageCard {
  @ObjectLink state: StorageMetricsState

  build() {
    Column({ space: 12 }) {
      DetailCardHeader({ title: $r('app.string.storage') })
      PressureBar({
        value: this.state.percent,
        label: $r('app.string.root_filesystem'),
        color: $r('app.color.metric_disk')
      })
      DetailValueRow({
        label: $r('app.string.root_used'),
        value: `${formatGigabytes(this.state.usedGb)} / ${formatGigabytes(this.state.totalGb)}`
      })
      DetailValueRow({ label: $r('app.string.read'), value: formatRate(this.state.readBytesPerSecond) })
      DetailValueRow({ label: $r('app.string.write'), value: formatRate(this.state.writeBytesPerSecond) })
      if (this.state.diskIoVisible()) {
        DetailValueRow({ label: $r('app.string.io_utilization'), value: `${this.state.ioPercent.toFixed(0)}%` })
      }
      if (this.state.latencyVisible()) {
        DetailValueRow({
          label: $r('app.string.read_write_latency'),
          value: `${this.state.readAwaitMs.toFixed(1)} / ${this.state.writeAwaitMs.toFixed(1)} ms`
        })
      }

      ForEach(this.state.filesystems, (filesystem: FilesystemMetric) => {
        Divider().color($r('app.color.divider'))
        Column({ space: 9 }) {
          PressureBar({
            value: this.filesystemPercent(filesystem),
            label: filesystem.name,
            color: $r('app.color.metric_disk')
          })
          DetailValueRow({
            label: $r('app.string.used'),
            value: `${formatGigabytes(filesystem.usedGb)} / ${formatGigabytes(filesystem.totalGb)}`
          })
          DetailValueRow({
            label: $r('app.string.read_write'),
            value: `${formatRate(filesystem.readBytesPerSecond)} · ${formatRate(filesystem.writeBytesPerSecond)}`
          })
        }
        .width('100%')
      }, (filesystem: FilesystemMetric) =>
        `${filesystem.name}:${this.filesystemPercent(filesystem).toFixed(0)}:` +
          `${formatGigabytes(filesystem.usedGb)}:${formatGigabytes(filesystem.totalGb)}:` +
          `${formatRate(filesystem.readBytesPerSecond)}:${formatRate(filesystem.writeBytesPerSecond)}`)
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.card_border') })
    .borderRadius(16)
  }

  private filesystemPercent(filesystem: FilesystemMetric): number {
    return filesystem.totalGb > 0 ? filesystem.usedGb / filesystem.totalGb * 100 : 0
  }
}
