import { SystemMetric, SystemSummary } from '../model/BeszelModels'

@Component
export struct PressureBar {
  @ObjectLink system: SystemSummary
  @Prop metric: SystemMetric = SystemMetric.CPU
  @Prop label: string = ''
  @Prop color: ResourceColor = Color.Green

  build() {
    Column({ space: 6 }) {
      Row() {
        Text(this.label).layoutWeight(1)
        Text(`${this.system.metricValue(this.metric).toFixed(0)}%`)
      }

      Progress({
        value: Math.min(this.system.metricValue(this.metric), 100),
        total: 100, type: ProgressType.Linear
      })
        .width('100%')
        .color(this.system.metricValue(this.metric) >= 90 ? $r('app.color.metric_danger') : this.color)
        .backgroundColor($r('app.color.progress_track'))
        .style({
          strokeWidth: 7,
          strokeRadius: 4,
          enableSmoothEffect: false
        })
    }
  }
}
