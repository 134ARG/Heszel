import { CpuMetricsState } from '../model/SystemDetailModels'
import { DetailValueRow } from './DetailValueRow'
import { DetailCardHeader } from './DetailCardHeader'

@Component
export struct CpuCard {
  @ObjectLink state: CpuMetricsState

  build() {
    Column({ space: 12 }) {
      DetailCardHeader({ title: 'CPU detail' })

      if (this.state.breakdown.length >= 5) {
        DetailValueRow({ label: 'User', value: `${this.state.breakdown[0].toFixed(0)}%` })
        DetailValueRow({ label: 'System', value: `${this.state.breakdown[1].toFixed(0)}%` })
        DetailValueRow({ label: 'I/O wait', value: `${this.state.breakdown[2].toFixed(0)}%` })
        DetailValueRow({ label: 'Steal', value: `${this.state.breakdown[3].toFixed(0)}%` })
      }

      if (this.state.cores.length > 0) {
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
          }, (value: number, index: number) =>
            `${index}:${value.toFixed(0)}:${value >= 90}`)
        }
        .width('100%')

        if (this.state.coreCount > this.visibleCoreLimit()) {
          Text(`Showing ${this.visibleCoreLimit()} of ${this.state.coreCount} threads`)
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
    return 32
  }

  private visibleCores(): number[] {
    return this.state.cores.slice(0, this.visibleCoreLimit())
  }
}
