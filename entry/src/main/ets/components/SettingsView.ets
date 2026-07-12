@Component
export struct SettingsView {
  @Prop baseUrl: string = ''
  @Prop email: string = ''
  @Prop expanded: boolean = false
  @Prop errorMessage: string = ''
  @State private gatewayKeyInput: string = ''
  onBack: () => void = () => {}
  onSignOut: () => void = () => {}
  onGatewayKeyChange: (gatewayKey: string) => void = () => {}

  build() {
    Column() {
      Row({ space: 12 }) {
        Button('‹  Dashboard')
          .height(38)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.action'))
          .backgroundColor($r('app.color.action_surface'))
          .borderRadius(10)
          .onClick(() => this.onBack())

        Text('Settings')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 18, bottom: 14 })
      .backgroundColor($r('app.color.surface_header'))

      if (this.errorMessage.length > 0) {
        Text(this.errorMessage)
          .fontSize(13)
          .fontColor($r('app.color.error_text'))
          .width('100%')
          .padding({ left: 18, right: 18, top: 10, bottom: 10 })
          .backgroundColor($r('app.color.error_surface'))
      }

      Scroll() {
        Column({ space: 18 }) {
          Column({ space: 12 }) {
            Text('GATEWAY ACCESS')
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_tertiary'))
              .width('100%')

            Column({ space: 12 }) {
              Text('Saved gateway keys are never displayed. A replacement is stored only after the hub accepts it.')
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .width('100%')

              TextInput({ placeholder: 'Enter replacement key', text: this.gatewayKeyInput })
                .type(InputType.Password)
                .showPasswordIcon(false)
                .height(48)
                .width('100%')
                .fontColor($r('app.color.text_primary'))
                .placeholderColor($r('app.color.text_tertiary'))
                .caretColor($r('app.color.action'))
                .backgroundColor($r('app.color.surface_input'))
                .borderRadius(12)
                .onChange((value: string) => {
                  this.gatewayKeyInput = value
                })

              Button('Verify and update')
                .height(44)
                .width('100%')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_on_action'))
                .backgroundColor($r('app.color.action'))
                .borderRadius(12)
                .enabled(this.gatewayKeyInput.trim().length > 0)
                .onClick(() => {
                  const replacement = this.gatewayKeyInput.trim()
                  this.gatewayKeyInput = ''
                  this.onGatewayKeyChange(replacement)
                })
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.surface'))
            .borderRadius(16)
          }
          .width('100%')

          Column({ space: 12 }) {
            Text('ACCOUNT')
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_tertiary'))
              .width('100%')

            Column() {
              Column({ space: 4 }) {
                Text('Beszel hub')
                  .fontSize(11)
                  .fontColor($r('app.color.text_tertiary'))
                Text(this.baseUrl)
                  .fontSize(14)
                  .fontColor($r('app.color.text_primary'))
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .alignItems(HorizontalAlign.Start)
              .width('100%')
              .padding(16)

              Divider()
                .color($r('app.color.divider'))
                .margin({ left: 16, right: 16 })

              Column({ space: 4 }) {
                Text('Signed in as')
                  .fontSize(11)
                  .fontColor($r('app.color.text_tertiary'))
                Text(this.email)
                  .fontSize(14)
                  .fontColor($r('app.color.text_primary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .alignItems(HorizontalAlign.Start)
              .width('100%')
              .padding(16)

              Divider()
                .color($r('app.color.divider'))
                .margin({ left: 16, right: 16 })

              Button('Sign out')
                .width('100%')
                .height(48)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.error'))
                .backgroundColor(Color.Transparent)
                .onClick(() => this.onSignOut())
            }
            .width('100%')
            .backgroundColor($r('app.color.surface'))
            .borderRadius(16)
          }
          .width('100%')
        }
        .width(this.expanded ? 620 : '100%')
        .padding({ left: 18, right: 18, top: 18, bottom: 30 })
      }
      .layoutWeight(1)
      .width('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor($r('app.color.background'))
  }
}
