import { FilesystemMetric, SystemDetailState } from '../model/SystemDetailModels'
import { formatGigabytes, formatRate } from './DetailFormatting'
import { DetailValueRow } from './DetailValueRow'
import { PressureBar } from './PressureBar'

@Component
export struct StorageCard {
  @ObjectLink detail: SystemDetailState

  build() {
    Column({ space: 12 }) {
      Text('Storage')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      PressureBar({
        value: this.detail.metrics.diskPercent,
        label: 'Root filesystem',
        color: $r('app.color.metric_disk')
      })
      DetailValueRow({
        label: 'Root used',
        value: `${formatGigabytes(this.detail.metrics.diskUsedGb)} / ${formatGigabytes(this.detail.metrics.diskTotalGb)}`
      })
      DetailValueRow({ label: 'Read', value: formatRate(this.detail.metrics.diskReadBytesPerSecond) })
      DetailValueRow({ label: 'Write', value: formatRate(this.detail.metrics.diskWriteBytesPerSecond) })
      if (this.detail.metrics.diskIoPercent > 0) {
        DetailValueRow({ label: 'I/O utilization', value: `${this.detail.metrics.diskIoPercent.toFixed(0)}%` })
      }
      if (this.detail.metrics.diskReadAwaitMs > 0 || this.detail.metrics.diskWriteAwaitMs > 0) {
        DetailValueRow({
          label: 'Read / write latency',
          value: `${this.detail.metrics.diskReadAwaitMs.toFixed(1)} / ${this.detail.metrics.diskWriteAwaitMs.toFixed(1)} ms`
        })
      }

      ForEach(this.detail.metrics.filesystems, (filesystem: FilesystemMetric) => {
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
      }, (filesystem: FilesystemMetric) => filesystem.name)
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
