import { SystemMetric, SystemSummary } from '../model/BeszelModels'

@Component
export struct MetricChip {
  @ObjectLink system: SystemSummary
  @Prop metric: SystemMetric = SystemMetric.CPU
  @Prop label: string = ''
  @Prop selected: boolean = false

  build() {
    Row({ space: 4 }) {
      Text(this.label)
        .fontSize(10)
        .fontColor($r('app.color.text_tertiary'))
      Text(`${this.system.metricValue(this.metric).toFixed(0)}%`)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.system.metricValue(this.metric) >= 90 ?
          $r('app.color.error') : $r('app.color.text_primary'))
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding({ top: 7, bottom: 7 })
    .borderRadius(9)
    .backgroundColor(this.selected ? $r('app.color.surface_selected_soft') : $r('app.color.surface_input'))
  }
}
