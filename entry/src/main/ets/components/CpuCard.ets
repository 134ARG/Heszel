import { CpuCoreMetric, CpuMetricsState } from '../model/SystemDetailModels'
import { DetailValueRow } from './DetailValueRow'
import { DetailCardHeader } from './DetailCardHeader'

@Component
struct CpuCoreChip {
  @ObjectLink core: CpuCoreMetric

  build() {
    Text(`${this.core.index}  ${this.fixedPercent()}%`)
      .fontSize(11)
      .fontColor(this.core.usagePercent >= 90 ? $r('app.color.error') : $r('app.color.text_primary'))
      .textAlign(TextAlign.Center)
      .width(66)
      .height(27)
      .margin({ right: 6, bottom: 6 })
      .backgroundColor($r('app.color.surface_input'))
      .borderRadius(8)
      .maxLines(1)
  }

  private fixedPercent(): string {
    const percent = this.core.usagePercent.toFixed(0)
    if (percent.length === 1) return `  ${percent}`
    if (percent.length === 2) return ` ${percent}`
    return percent
  }
}

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
          ForEach(this.state.cores, (core: CpuCoreMetric) => {
            CpuCoreChip({ core: core })
          }, (core: CpuCoreMetric) => core.index.toString())
        }
        .width('100%')

        if (this.state.coreCount > this.state.cores.length) {
          Text($r('app.string.showing_threads', this.state.cores.length, this.state.coreCount))
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

}
