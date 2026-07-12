@Component
export struct MetricTile {
  @Prop value: number = 0
  @Prop label: string = ''
  @Prop suffix: string = ''

  build() {
    Column({ space: 8 }) {
      Text(this.label.toUpperCase())
        .fontSize(11)
        .fontColor($r('app.color.text_tertiary'))

      Text(`${this.value.toFixed(0)}${this.suffix}`)
        .fontSize(23)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.value >= 90
          ? $r('app.color.error')
          : $r('app.color.text_primary'))
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
    .padding(16)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.card_border') })
    .borderRadius(15)
  }
}
