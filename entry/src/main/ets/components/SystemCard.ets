import { SystemSummary } from '../model/BeszelModels'

@Component
export struct SystemCard {
  @Prop system: SystemSummary = new SystemSummary()
  @Prop selected: boolean = false
  onSelect: () => void = () => {}

  build() {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        Row()
          .width(9)
          .height(9)
          .borderRadius(5)
          .backgroundColor(this.system.isUp() ? $r('app.color.status_up') : $r('app.color.status_down'))

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
        this.metricChip('CPU', this.system.cpuPercent)
        this.metricChip('RAM', this.system.memoryPercent)
        this.metricChip('DISK', this.system.diskPercent)
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .borderRadius(16)
    .backgroundColor(this.selected ? $r('app.color.surface_selected') : $r('app.color.surface'))
    .border({
      width: this.selected ? 1 : 0,
      color: $r('app.color.selected_border')
    })
    .onClick(() => {
      this.onSelect()
    })
  }

  @Builder
  private metricChip(label: string, value: number) {
    Row({ space: 4 }) {
      Text(label)
        .fontSize(10)
        .fontColor($r('app.color.text_tertiary'))
      Text(`${value.toFixed(0)}%`)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(value >= 90 ? $r('app.color.error') : $r('app.color.text_primary'))
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding({ top: 7, bottom: 7 })
    .borderRadius(9)
    .backgroundColor(this.selected ? $r('app.color.surface_selected_soft') : $r('app.color.surface_input'))
  }
}
