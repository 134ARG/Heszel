@Component
export struct DetailCardHeader {
  @Prop title: ResourceStr = ''
  @Prop showAction: boolean = false
  @Prop actionLabel: ResourceStr = ''
  onAction: () => void = () => {}

  build() {
    Row() {
      Text(this.title)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)

      if (this.showAction) {
        Button(this.actionLabel)
          .height(30)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.action'))
          .backgroundColor($r('app.color.action_surface'))
          .borderRadius(8)
          .onClick(() => this.onAction())
      }
    }
    .width('100%')
  }
}
