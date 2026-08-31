import { MemoryMetricsState } from '../model/SystemDetailModels'
import { formatGigabytes } from './DetailFormatting'
import { DetailCardHeader } from './DetailCardHeader'
import { DetailValueRow } from './DetailValueRow'
import { PressureBar } from './PressureBar'

@Component
export struct MemoryCard {
  @ObjectLink state: MemoryMetricsState
  onOpenHistory: () => void = () => {}

  build() {
    Column({ space: 11 }) {
      DetailCardHeader({
        title: $r('app.string.memory'),
        showAction: true,
        actionLabel: $r('app.string.history_chart'),
        onAction: () => this.onOpenHistory()
      })
      PressureBar({
        value: this.state.percent,
        label: $r('app.string.usage'),
        color: $r('app.color.metric_memory')
      })
      DetailValueRow({
        label: $r('app.string.used'),
        value: `${formatGigabytes(this.state.usedGb)} / ${formatGigabytes(this.state.totalGb)}`
      })
      if (this.state.cacheGb > 0) {
        DetailValueRow({ label: $r('app.string.buffer_cache'), value: formatGigabytes(this.state.cacheGb) })
      }
      if (this.state.zfsArcGb > 0) {
        DetailValueRow({
          label: $r('app.string.metric_zfs_arc'),
          value: formatGigabytes(this.state.zfsArcGb)
        })
      }
      if (this.state.swapTotalGb > 0) {
        DetailValueRow({
          label: $r('app.string.swap'),
          value: `${formatGigabytes(this.state.swapUsedGb)} / ${formatGigabytes(this.state.swapTotalGb)}`
        })
      }
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.card_border') })
    .borderRadius(16)
  }
}
