@Component
export struct LoginView {
  @Prop loading: boolean = false
  @Prop errorMessage: string = ''
  @Prop initialServerUrl: string = ''
  @Prop initialEmail: string = ''
  @State private serverUrl: string = ''
  @State private email: string = ''
  @State private password: string = ''
  onLogin: (serverUrl: string, email: string, password: string) => void = () => {}

  aboutToAppear(): void {
    this.serverUrl = this.initialServerUrl
    this.email = this.initialEmail
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Column({ space: 6 }) {
          Text('Heszel')
            .fontSize(38)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))

          Text('Your Beszel dashboard, shaped for the fold.')
            .fontSize(15)
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
        }
        .alignItems(HorizontalAlign.Center)
        .margin({ bottom: 18 })

        Column({ space: 8 }) {
          Text('HUB ADDRESS')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_label'))
            .width('100%')

          TextInput({
            placeholder: 'https://beszel.example.com',
            text: this.serverUrl
          })
            .height(52)
            .width('100%')
            .fontColor($r('app.color.text_primary'))
            .placeholderColor($r('app.color.text_tertiary'))
            .caretColor($r('app.color.action'))
            .backgroundColor($r('app.color.surface_input'))
            .borderRadius(14)
            .onChange((value: string) => {
              this.serverUrl = value
            })
        }

        Column({ space: 8 }) {
          Text('EMAIL')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_label'))
            .width('100%')

          TextInput({ placeholder: 'you@example.com', text: this.email })
            .type(InputType.Email)
            .height(52)
            .width('100%')
            .fontColor($r('app.color.text_primary'))
            .placeholderColor($r('app.color.text_tertiary'))
            .caretColor($r('app.color.action'))
            .backgroundColor($r('app.color.surface_input'))
            .borderRadius(14)
            .onChange((value: string) => {
              this.email = value
            })
        }

        Column({ space: 8 }) {
          Text('PASSWORD')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_label'))
            .width('100%')

          TextInput({ placeholder: 'Beszel password', text: this.password })
            .type(InputType.Password)
            .height(52)
            .width('100%')
            .fontColor($r('app.color.text_primary'))
            .placeholderColor($r('app.color.text_tertiary'))
            .caretColor($r('app.color.action'))
            .backgroundColor($r('app.color.surface_input'))
            .borderRadius(14)
            .onChange((value: string) => {
              this.password = value
            })
        }

        if (this.errorMessage.length > 0) {
          Text(this.errorMessage)
            .fontSize(14)
            .fontColor($r('app.color.error'))
            .width('100%')
            .padding(12)
            .backgroundColor($r('app.color.error_surface'))
            .borderRadius(12)
        }

        Button(this.loading ? 'Connecting…' : 'Connect to Beszel')
          .width('100%')
          .height(52)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_on_action'))
          .backgroundColor($r('app.color.action'))
          .borderRadius(14)
          .enabled(!this.loading)
          .onClick(() => {
            this.onLogin(this.serverUrl, this.email, this.password)
          })

        Text('Your password is never stored. The session token is protected by HarmonyOS.')
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'))
          .textAlign(TextAlign.Center)
          .lineHeight(18)
          .margin({ top: 2 })
      }
      .width('100%')
      .constraintSize({ maxWidth: 440 })
      .padding({ left: 24, right: 24, top: 56, bottom: 40 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.surface_header'))
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
  }
}
