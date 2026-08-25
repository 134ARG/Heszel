export enum PageHeaderTone {
  Neutral = 'neutral',
  Success = 'success',
  Warning = 'warning',
  Error = 'error'
}

@Component
export struct PageHeader {
  @Prop title: ResourceStr = ''
  @Prop subtitle: ResourceStr = ''
  @Prop showSubtitle: boolean = false
  @Prop showBack: boolean = false
  @Prop backLabel: ResourceStr = ''
  @Prop showBadge: boolean = false
  @Prop badgeLabel: ResourceStr = ''
  @Prop badgeTone: PageHeaderTone = PageHeaderTone.Neutral
  onBack: () => void = () => {}

  build() {
    Row({ space: 12 }) {
      if (this.showBack) {
        Button(this.backLabel)
          .height(38)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.action'))
          .backgroundColor($r('app.color.action_surface'))
          .borderRadius(10)
          .onClick(() => this.onBack())
      }

      Column({ space: 2 }) {
        Text(this.title)
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.showSubtitle) {
          Text(this.subtitle)
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.showBadge) {
        Row({ space: 6 }) {
          Row()
            .width(7)
            .height(7)
            .borderRadius(4)
            .backgroundColor(this.badgeDotColor())
          Text(this.badgeLabel)
            .fontSize(10)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.badgeTextColor())
            .maxLines(1)
        }
        .padding({ left: 10, right: 10, top: 7, bottom: 7 })
        .backgroundColor(this.badgeSurfaceColor())
        .borderRadius(8)
      }
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 18, bottom: 14 })
    .backgroundColor($r('app.color.surface_header'))
  }

  private badgeDotColor(): ResourceColor {
    if (this.badgeTone === PageHeaderTone.Success) return $r('app.color.status_up')
    if (this.badgeTone === PageHeaderTone.Warning) return $r('app.color.metric_disk')
    if (this.badgeTone === PageHeaderTone.Error) return $r('app.color.status_down')
    return $r('app.color.text_tertiary')
  }

  private badgeTextColor(): ResourceColor {
    if (this.badgeTone === PageHeaderTone.Success) return $r('app.color.action')
    if (this.badgeTone === PageHeaderTone.Warning) return $r('app.color.metric_disk')
    if (this.badgeTone === PageHeaderTone.Error) return $r('app.color.status_down_text')
    return $r('app.color.text_secondary')
  }

  private badgeSurfaceColor(): ResourceColor {
    if (this.badgeTone === PageHeaderTone.Success) return $r('app.color.action_surface')
    if (this.badgeTone === PageHeaderTone.Error) return $r('app.color.status_down_surface')
    return $r('app.color.surface_neutral')
  }
}
