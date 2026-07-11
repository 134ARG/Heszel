@Component
export struct LoginView {
  @Prop loading: boolean = false
  @Prop errorMessage: string = ''
  @State private serverUrl: string = ''
  @State private email: string = ''
  @State private password: string = ''
  onLogin: (serverUrl: string, email: string, password: string) => void = () => {}

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Column({ space: 6 }) {
          Text('Heszel')
            .fontSize(38)
            .fontWeight(FontWeight.Bold)
            .fontColor('#17211B')

          Text('Your Beszel dashboard, shaped for the fold.')
            .fontSize(15)
            .fontColor('#647067')
            .textAlign(TextAlign.Center)
        }
        .alignItems(HorizontalAlign.Center)
        .margin({ bottom: 18 })

        Column({ space: 8 }) {
          Text('HUB ADDRESS')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor('#5C695F')
            .width('100%')

          TextInput({
            placeholder: 'https://beszel.example.com',
            text: this.serverUrl
          })
            .height(52)
            .width('100%')
            .backgroundColor('#F2F5F2')
            .borderRadius(14)
            .onChange((value: string) => {
              this.serverUrl = value
            })
        }

        Column({ space: 8 }) {
          Text('EMAIL')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor('#5C695F')
            .width('100%')

          TextInput({ placeholder: 'you@example.com', text: this.email })
            .type(InputType.Email)
            .height(52)
            .width('100%')
            .backgroundColor('#F2F5F2')
            .borderRadius(14)
            .onChange((value: string) => {
              this.email = value
            })
        }

        Column({ space: 8 }) {
          Text('PASSWORD')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor('#5C695F')
            .width('100%')

          TextInput({ placeholder: 'Beszel password', text: this.password })
            .type(InputType.Password)
            .height(52)
            .width('100%')
            .backgroundColor('#F2F5F2')
            .borderRadius(14)
            .onChange((value: string) => {
              this.password = value
            })
        }

        if (this.errorMessage.length > 0) {
          Text(this.errorMessage)
            .fontSize(14)
            .fontColor('#B3261E')
            .width('100%')
            .padding(12)
            .backgroundColor('#FFF0EE')
            .borderRadius(12)
        }

        Button(this.loading ? 'Connecting…' : 'Connect to Beszel')
          .width('100%')
          .height(52)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .backgroundColor('#176B45')
          .borderRadius(14)
          .enabled(!this.loading)
          .onClick(() => {
            this.onLogin(this.serverUrl, this.email, this.password)
          })

        Text('Credentials are used only to sign in and are not stored in this first build.')
          .fontSize(12)
          .fontColor('#7A857D')
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
    .backgroundColor('#FCFDFC')
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
  }
}
