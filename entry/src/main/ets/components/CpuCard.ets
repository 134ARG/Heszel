import { SystemDetailState } from '../model/SystemDetailModels'
import { DetailValueRow } from './DetailValueRow'

@Component
export struct CpuCard {
  @ObjectLink detail: SystemDetailState
  @Prop compact: boolean = false

  build() {
    Column({ space: 12 }) {
      Text('CPU detail')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      if (this.detail.metrics.cpuBreakdown.length >= 5) {
        DetailValueRow({ label: 'User', value: `${this.detail.metrics.cpuBreakdown[0].toFixed(0)}%` })
        DetailValueRow({ label: 'System', value: `${this.detail.metrics.cpuBreakdown[1].toFixed(0)}%` })
        DetailValueRow({ label: 'I/O wait', value: `${this.detail.metrics.cpuBreakdown[2].toFixed(0)}%` })
        DetailValueRow({ label: 'Steal', value: `${this.detail.metrics.cpuBreakdown[3].toFixed(0)}%` })
      }

      if (this.detail.metrics.cpuCores.length > 0) {
        Text('Per-core usage')
          .fontSize(11)
          .fontColor($r('app.color.text_tertiary'))
          .width('100%')
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.visibleCores(), (value: number, index: number) => {
            Text(`${index}  ${value.toFixed(0)}%`)
              .fontSize(11)
              .fontColor(value >= 90 ? $r('app.color.error') : $r('app.color.text_primary'))
              .padding({ left: 9, right: 9, top: 6, bottom: 6 })
              .margin({ right: 6, bottom: 6 })
              .backgroundColor($r('app.color.surface_input'))
              .borderRadius(8)
          }, (_value: number, index: number) => index.toString())
        }
        .width('100%')

        if (this.detail.metrics.cpuCores.length > this.visibleCoreLimit()) {
          Text(`Showing ${this.visibleCoreLimit()} of ${this.detail.metrics.cpuCores.length} threads`)
            .fontSize(11)
            .fontColor($r('app.color.text_tertiary'))
            .width('100%')
        }
      }
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(16)
  }

  private visibleCoreLimit(): number {
    return this.compact ? 16 : 32
  }

  private visibleCores(): number[] {
    return this.detail.metrics.cpuCores.slice(0, this.visibleCoreLimit())
  }
}
