import { GpuMetric, GpuMetricsState } from '../model/SystemDetailModels'
import { DetailValueRow } from './DetailValueRow'
import { DetailCardHeader } from './DetailCardHeader'
import { PressureBar } from './PressureBar'

@Component
export struct GpuCard {
  @ObjectLink state: GpuMetricsState

  build() {
    Column({ space: 12 }) {
      DetailCardHeader({ title: 'GPU' })

      ForEach(this.state.gpus, (gpu: GpuMetric, index: number) => {
        if (index > 0) {
          Divider().color($r('app.color.divider'))
        }
        Column({ space: 9 }) {
          PressureBar({ value: gpu.usagePercent, label: gpu.name, color: $r('app.color.metric_cpu') })
          if (gpu.hasMemory) {
            DetailValueRow({
              label: 'Memory',
              value: `${gpu.memoryUsedMb.toFixed(0)} / ${gpu.memoryTotalMb.toFixed(0)} MB`
            })
          }
          if (gpu.hasPower) {
            DetailValueRow({ label: 'Power', value: `${gpu.powerWatts.toFixed(1)} W` })
          }
        }
        .width('100%')
      }, (gpu: GpuMetric) =>
        `${gpu.id}:${gpu.usagePercent.toFixed(0)}:${gpu.memoryUsedMb.toFixed(0)}:` +
          `${gpu.memoryTotalMb.toFixed(0)}:${gpu.powerWatts.toFixed(1)}:${gpu.hasMemory}:${gpu.hasPower}`)
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.card_border') })
    .borderRadius(16)
  }
}
