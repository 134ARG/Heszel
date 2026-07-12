import { MemoryMetricsState } from '../model/SystemDetailModels'
import { formatGigabytes } from './DetailFormatting'
import { DetailCardHeader } from './DetailCardHeader'
import { DetailValueRow } from './DetailValueRow'
import { PressureBar } from './PressureBar'

@Component
export struct MemoryCard {
  @ObjectLink state: MemoryMetricsState

  build() {
    Column({ space: 11 }) {
      DetailCardHeader({ title: 'Memory' })
      PressureBar({
        value: this.state.percent,
        label: 'Usage',
        color: $r('app.color.metric_memory')
      })
      DetailValueRow({
        label: 'Used',
        value: `${formatGigabytes(this.state.usedGb)} / ${formatGigabytes(this.state.totalGb)}`
      })
      if (this.state.cacheGb > 0) {
        DetailValueRow({ label: 'Buffer + cache', value: formatGigabytes(this.state.cacheGb) })
      }
      if (this.state.zfsArcGb > 0) {
        DetailValueRow({ label: 'ZFS ARC', value: formatGigabytes(this.state.zfsArcGb) })
      }
      if (this.state.swapTotalGb > 0) {
        DetailValueRow({
          label: 'Swap',
          value: `${formatGigabytes(this.state.swapUsedGb)} / ${formatGigabytes(this.state.swapTotalGb)}`
        })
      }
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(16)
  }
}
