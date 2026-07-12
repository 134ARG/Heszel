@Component
export struct DetailValueRow {
  @Prop label: string = ''
  @Prop value: string = ''
  @Prop warning: boolean = false

  build() {
    Row({ space: 12 }) {
      Text(this.label)
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(this.value)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.warning ? $r('app.color.error') : $r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
  }
}
