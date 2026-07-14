import { CpuMetricsState } from '../model/SystemDetailModels'
import { DetailValueRow } from './DetailValueRow'
import { DetailCardHeader } from './DetailCardHeader'

@Component
export struct CpuCard {
  @ObjectLink state: CpuMetricsState

  build() {
    Column({ space: 12 }) {
      DetailCardHeader({ title: $r('app.string.cpu_detail') })

      if (this.state.breakdown.length >= 5) {
        DetailValueRow({ label: $r('app.string.cpu_user'), value: `${this.state.breakdown[0].toFixed(0)}%` })
        DetailValueRow({ label: $r('app.string.cpu_system'), value: `${this.state.breakdown[1].toFixed(0)}%` })
        DetailValueRow({ label: $r('app.string.io_wait'), value: `${this.state.breakdown[2].toFixed(0)}%` })
        DetailValueRow({ label: $r('app.string.cpu_steal'), value: `${this.state.breakdown[3].toFixed(0)}%` })
      }

      if (this.state.cores.length > 0) {
        Text($r('app.string.per_core_usage'))
          .fontSize(11)
          .fontColor($r('app.color.text_tertiary'))
          .width('100%')
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.visibleCores(), (value: number, index: number) => {
            Text(`${index}  ${value.toFixed(0)}%`)
              .fontSize(11)
              .fontColor(value >= 90 ? $r('app.color.error') : $r('app.color.text_primary'))
              .textAlign(TextAlign.Center)
              .width(78)
              .height(30)
              .margin({ right: 6, bottom: 6 })
              .backgroundColor($r('app.color.surface_input'))
              .borderRadius(8)
              .maxLines(1)
          }, (value: number, index: number) =>
            `${index}:${value.toFixed(0)}:${value >= 90}`)
        }
        .width('100%')

        if (this.state.coreCount > this.visibleCoreLimit()) {
          Text($r('app.string.showing_threads', this.visibleCoreLimit(), this.state.coreCount))
            .fontSize(11)
            .fontColor($r('app.color.text_tertiary'))
            .width('100%')
        }
      }
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.card_border') })
    .borderRadius(16)
  }

  private visibleCoreLimit(): number {
    return 32
  }

  private visibleCores(): number[] {
    return this.state.cores.slice(0, this.visibleCoreLimit())
  }
}
