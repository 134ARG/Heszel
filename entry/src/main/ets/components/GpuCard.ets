import { GpuMetric, SystemDetailState } from '../model/SystemDetailModels'
import { DetailValueRow } from './DetailValueRow'
import { PressureBar } from './PressureBar'

@Component
export struct GpuCard {
  @ObjectLink detail: SystemDetailState

  build() {
    Column({ space: 12 }) {
      Text('GPU')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      ForEach(this.detail.metrics.gpus, (gpu: GpuMetric, index: number) => {
        if (index > 0) {
          Divider().color($r('app.color.divider'))
        }
        Column({ space: 9 }) {
          PressureBar({ value: gpu.usagePercent, label: gpu.name, color: $r('app.color.metric_cpu') })
          if (gpu.memoryTotalMb > 0) {
            DetailValueRow({
              label: 'Memory',
              value: `${gpu.memoryUsedMb.toFixed(0)} / ${gpu.memoryTotalMb.toFixed(0)} MB`
            })
          }
          if (gpu.powerWatts > 0) {
            DetailValueRow({ label: 'Power', value: `${gpu.powerWatts.toFixed(1)} W` })
          }
        }
        .width('100%')
      }, (gpu: GpuMetric) => gpu.id)
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(16)
  }
}
