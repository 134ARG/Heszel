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
      DetailCardHeader({ title: 'Storage' })
      PressureBar({
        value: this.state.percent,
        label: 'Root filesystem',
        color: $r('app.color.metric_disk')
      })
      DetailValueRow({
        label: 'Root used',
        value: `${formatGigabytes(this.state.usedGb)} / ${formatGigabytes(this.state.totalGb)}`
      })
      DetailValueRow({ label: 'Read', value: formatRate(this.state.readBytesPerSecond) })
      DetailValueRow({ label: 'Write', value: formatRate(this.state.writeBytesPerSecond) })
      if (this.state.diskIoVisible()) {
        DetailValueRow({ label: 'I/O utilization', value: `${this.state.ioPercent.toFixed(0)}%` })
      }
      if (this.state.latencyVisible()) {
        DetailValueRow({
          label: 'Read / write latency',
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
            label: 'Used',
            value: `${formatGigabytes(filesystem.usedGb)} / ${formatGigabytes(filesystem.totalGb)}`
          })
          DetailValueRow({
            label: 'Read / write',
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
    .borderRadius(16)
  }

  private filesystemPercent(filesystem: FilesystemMetric): number {
    return filesystem.totalGb > 0 ? filesystem.usedGb / filesystem.totalGb * 100 : 0
  }
}
