import { pasteboard } from '@kit.BasicServicesKit'

@Component
export struct IrohEndpointIdentity {
  @Prop endpointId: string = ''

  build() {
    Column({ space: 8 }) {
      Row({ space: 12 }) {
        Text($r('app.string.iroh_client_endpoint_id'))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)

        Button($r('app.string.copy'))
          .height(32)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.action'))
          .backgroundColor($r('app.color.action_surface'))
          .borderRadius(10)
          .onClick(() => {
            this.copyEndpointId()
          })
      }
      .width('100%')

      Text(this.endpointId)
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(18)
        .width('100%')
        .wordBreak(WordBreak.BREAK_ALL)
        .copyOption(CopyOptions.LocalDevice)

      Text($r('app.string.iroh_client_endpoint_hint'))
        .fontSize(11)
        .fontColor($r('app.color.text_tertiary'))
        .lineHeight(17)
        .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.card_border') })
    .borderRadius(14)
  }

  private async copyEndpointId(): Promise<void> {
    if (this.endpointId.length === 0) {
      return
    }
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.endpointId)
      await pasteboard.getSystemPasteboard().setData(data)
      this.getUIContext().getPromptAction().showToast({ message: $r('app.string.endpoint_id_copied') })
    } catch (_) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: $r('app.string.endpoint_id_copy_failed') })
      } catch (_) {
        // Clipboard failure needs no further fallback if the toast service is also unavailable.
      }
    }
  }
}
