@Component
export struct DetailValueRow {
  @Prop label: ResourceStr = ''
  @Prop value: ResourceStr = ''
  @Prop warning: boolean = false

  build() {
    Row({ space: 12 }) {
      Text(this.label)
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .layoutWeight(1)
        .wordBreak(WordBreak.BREAK_WORD)
      Text(this.value)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.warning ? $r('app.color.error') : $r('app.color.text_primary'))
        .constraintSize({ maxWidth: '65%' })
        .textAlign(TextAlign.End)
        .wordBreak(WordBreak.BREAK_WORD)
    }
    .alignItems(VerticalAlign.Top)
    .width('100%')
  }
}
