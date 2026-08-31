import { GpuMetric, GpuMetricsState } from '../model/SystemDetailModels'
import { DetailValueRow } from './DetailValueRow'
import { DetailCardHeader } from './DetailCardHeader'
import { PressureBar } from './PressureBar'

@Component
struct GpuSection {
  @ObjectLink gpu: GpuMetric
  @Prop showDivider: boolean = false

  build() {
    Column({ space: 12 }) {
      if (this.showDivider) {
        Divider().color($r('app.color.divider'))
      }
      Column({ space: 9 }) {
        PressureBar({ value: this.gpu.usagePercent, label: this.gpu.name, color: $r('app.color.metric_gpu') })
        if (this.gpu.hasMemory) {
          DetailValueRow({
            label: $r('app.string.gpu_memory'),
            value: `${this.gpu.memoryUsedMb.toFixed(0)} / ${this.gpu.memoryTotalMb.toFixed(0)} MB`
          })
        }
        if (this.gpu.hasPower) {
          DetailValueRow({ label: $r('app.string.power'), value: `${this.gpu.powerWatts.toFixed(1)} W` })
        }
      }
      .width('100%')
    }
    .width('100%')
  }
}

@Component
export struct GpuCard {
  @ObjectLink state: GpuMetricsState
  onOpenHistory: () => void = () => {}

  build() {
    Column({ space: 12 }) {
      DetailCardHeader({
        title: $r('app.string.metric_gpu'),
        showAction: true,
        actionLabel: $r('app.string.history_chart'),
        onAction: () => this.onOpenHistory()
      })

      ForEach(this.state.gpus, (gpu: GpuMetric, index: number) => {
        GpuSection({ gpu: gpu, showDivider: index > 0 })
      }, (gpu: GpuMetric) => gpu.id)
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.card_border') })
    .borderRadius(16)
  }
}
