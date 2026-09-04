import { FanMetric, FanMetricsState } from '../model/SystemDetailModels'
import { DetailCardHeader } from './DetailCardHeader'
import { DetailValueRow } from './DetailValueRow'

@Component
struct FanRow {
  @ObjectLink fan: FanMetric

  build() {
    DetailValueRow({
      label: this.fan.name,
      value: `${this.fan.rpm.toFixed(0)} RPM`
    })
  }
}

@Component
export struct FanCard {
  @ObjectLink state: FanMetricsState
  onOpenHistory: () => void = () => {}

  build() {
    Column({ space: 11 }) {
      DetailCardHeader({
        title: $r('app.string.fans'),
        showAction: true,
        actionLabel: $r('app.string.history_chart'),
        onAction: () => this.onOpenHistory()
      })

      ForEach(this.state.fans, (fan: FanMetric) => {
        FanRow({ fan: fan })
      }, (fan: FanMetric) => fan.name)
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.card_border') })
    .borderRadius(16)
  }
}
