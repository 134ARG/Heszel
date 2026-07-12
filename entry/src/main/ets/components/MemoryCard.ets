import { SystemDetailState } from '../model/SystemDetailModels'
import { formatGigabytes } from './DetailFormatting'
import { DetailValueRow } from './DetailValueRow'
import { PressureBar } from './PressureBar'

@Component
export struct MemoryCard {
  @ObjectLink detail: SystemDetailState

  build() {
    Column({ space: 11 }) {
      Text('Memory')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      PressureBar({
        value: this.detail.metrics.memoryPercent,
        label: 'Usage',
        color: $r('app.color.metric_memory')
      })
      DetailValueRow({
        label: 'Used',
        value: `${formatGigabytes(this.detail.metrics.memoryUsedGb)} / ${formatGigabytes(this.detail.metrics.memoryTotalGb)}`
      })
      if (this.detail.metrics.memoryCacheGb > 0) {
        DetailValueRow({ label: 'Buffer + cache', value: formatGigabytes(this.detail.metrics.memoryCacheGb) })
      }
      if (this.detail.metrics.zfsArcGb > 0) {
        DetailValueRow({ label: 'ZFS ARC', value: formatGigabytes(this.detail.metrics.zfsArcGb) })
      }
      if (this.detail.metrics.swapTotalGb > 0) {
        DetailValueRow({
          label: 'Swap',
          value: `${formatGigabytes(this.detail.metrics.swapUsedGb)} / ${formatGigabytes(this.detail.metrics.swapTotalGb)}`
        })
      }
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(16)
  }
}
