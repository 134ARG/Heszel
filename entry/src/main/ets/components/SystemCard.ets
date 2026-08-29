import { SystemMetric, SystemSummary } from '../model/BeszelModels'
import { MetricChip } from './MetricChip'

@Component
export struct SystemCard {
  @ObjectLink system: SystemSummary
  @Prop selected: boolean = false
  onSelect: () => void = () => {}

  build() {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        Row()
          .width(9)
          .height(9)
          .borderRadius(5)
          .backgroundColor(this.system.status === 'up' ?
            $r('app.color.status_up') : $r('app.color.status_down'))

        Column({ space: 2 }) {
          Text(this.system.name)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.system.host.length > 0 ? this.system.host : this.system.status.toUpperCase())
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        if (this.system.temperatureCelsius > 0) {
          Text(`${this.system.temperatureCelsius.toFixed(0)}°`)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.system.temperatureCelsius >= 75 ?
              $r('app.color.error') : $r('app.color.text_primary'))
        }
      }
      .width('100%')

      Row({ space: 8 }) {
        MetricChip({ system: this.system, metric: SystemMetric.CPU, label: 'CPU', selected: this.selected })
        MetricChip({ system: this.system, metric: SystemMetric.Memory, label: 'RAM', selected: this.selected })
        MetricChip({ system: this.system, metric: SystemMetric.Disk, label: 'DISK', selected: this.selected })
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .borderRadius(16)
    .backgroundColor(this.selected ? $r('app.color.surface_selected') : $r('app.color.surface'))
    .border({
      width: 1,
      color: this.selected ? $r('app.color.selected_border') : Color.Transparent
    })
    .onClick(() => {
      this.onSelect()
    })
  }

}
