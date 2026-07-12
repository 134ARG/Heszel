@Component
export struct PressureBar {
  @Prop value: number = 0
  @Prop label: string = ''
  @Prop color: ResourceColor = Color.Green

  build() {
    Column({ space: 6 }) {
      Row() {
        Text(this.label).layoutWeight(1)
        Text(`${this.value.toFixed(0)}%`)
      }

      Progress({
        value: Math.min(this.value, 100),
        total: 100, type: ProgressType.Linear
      })
        .width('100%')
        .color(this.value >= 90 ? $r('app.color.metric_danger') : this.color)
        .backgroundColor($r('app.color.progress_track'))
        .style({
          strokeWidth: 7,
          strokeRadius: 4,
          // enableSmoothEffect: false
        })
        // .animation({ duration: 220, curve: Curve.EaseOut })
    }
  }
}
