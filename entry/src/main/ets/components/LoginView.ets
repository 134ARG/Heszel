import { BusinessError } from '@kit.BasicServicesKit'
import { ConnectionMode, IrohPairing, LoginRequest } from '../model/ConnectionModels'
import { IrohPairingCodec } from '../service/IrohPairingCodec'
import { IrohPairingService } from '../service/IrohPairingService'
import { HeszelTextInputStyle } from '../styles/HeszelTextInputStyle'

enum LoginInputField {
  NONE,
  SERVER_URL,
  GATEWAY_KEY,
  EMAIL,
  PASSWORD
}

@Component
export struct LoginView {
  @Prop loading: boolean = false
  @Prop errorMessage: string = ''
  @Prop initialConnectionMode: ConnectionMode = ConnectionMode.HTTP
  @Prop initialServerUrl: string = ''
  @Prop initialEmail: string = ''
  @Prop initialGatewayKey: string = ''
  @Prop initialIrohPairingJson: string = ''
  @State private connectionMode: ConnectionMode = ConnectionMode.HTTP
  @State private serverUrl: string = ''
  @State private email: string = ''
  @State private password: string = ''
  @State private gatewayKey: string = ''
  @State private pairing: IrohPairing = new IrohPairing()
  @State private scanning: boolean = false
  @State private scanError: string = ''
  @State private focusedInput: LoginInputField = LoginInputField.NONE
  onLogin: (request: LoginRequest) => void = () => {}

  aboutToAppear(): void {
    this.connectionMode = this.initialConnectionMode
    this.serverUrl = this.initialServerUrl
    this.email = this.initialEmail
    this.gatewayKey = this.initialGatewayKey
    if (this.initialIrohPairingJson.length > 0) {
      try {
        this.pairing = IrohPairingCodec.parse(this.initialIrohPairingJson)
      } catch (_) {
        this.pairing = new IrohPairing()
      }
    }
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Column({ space: 6 }) {
          Text('Heszel')
            .fontSize(38)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))

          Text($r('app.string.login_tagline'))
            .fontSize(15)
            .fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
        }
        .alignItems(HorizontalAlign.Center)
        .margin({ bottom: 10 })

        Row({ space: 6 }) {
          this.modeButton($r('app.string.login_mode_http'), ConnectionMode.HTTP)
          this.modeButton($r('app.string.login_mode_iroh'), ConnectionMode.IROH)
        }
        .width('100%')
        .padding(4)
        .backgroundColor($r('app.color.surface_input'))
        .borderRadius(14)

        if (this.connectionMode === ConnectionMode.HTTP) {
          this.httpConnectionFields()
        } else {
          this.irohConnectionFields()
        }

        this.credentialsFields()

        if (this.scanError.length > 0 || this.errorMessage.length > 0) {
          Text(this.scanError.length > 0 ? this.scanError : this.errorMessage)
            .fontSize(14)
            .fontColor($r('app.color.error'))
            .width('100%')
            .padding(12)
            .backgroundColor($r('app.color.error_surface'))
            .borderRadius(12)
        }

        Button(this.loading ? $r('app.string.connecting') : $r('app.string.connect_to_beszel'))
          .width('100%')
          .height(52)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_on_action'))
          .backgroundColor($r('app.color.action'))
          .borderRadius(14)
          .enabled(!this.loading && !this.scanning)
          .onClick(() => this.submit())

        Text($r('app.string.credentials_security_note'))
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'))
          .textAlign(TextAlign.Center)
          .lineHeight(18)
          .margin({ top: 2 })
      }
      .width('100%')
      .constraintSize({ maxWidth: 440 })
      .padding({ left: 24, right: 24, top: 48, bottom: 40 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.surface_header'))
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
  }

  @Builder
  private modeButton(label: ResourceStr, mode: ConnectionMode) {
    Button(label)
      .layoutWeight(1)
      .height(42)
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.connectionMode === mode ?
        $r('app.color.text_on_action') : $r('app.color.text_secondary'))
      .backgroundColor(this.connectionMode === mode ? $r('app.color.action') : Color.Transparent)
      .borderRadius(10)
      .onClick(() => {
        this.connectionMode = mode
        this.scanError = ''
      })
  }

  @Builder
  private httpConnectionFields() {
    Column({ space: 18 }) {
      Column({ space: 8 }) {
        Text($r('app.string.hub_address'))
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_label'))
          .width('100%')

        TextInput({ placeholder: 'https://beszel.example.com', text: this.serverUrl })
          .attributeModifier(new HeszelTextInputStyle(this.focusedInput === LoginInputField.SERVER_URL))
          .onFocus(() => {
            this.focusedInput = LoginInputField.SERVER_URL
          })
          .onBlur(() => {
            this.clearFocusedInput(LoginInputField.SERVER_URL)
          })
          .onChange((value: string) => {
            this.serverUrl = value
          })
      }

      Column({ space: 8 }) {
        Text($r('app.string.gateway_key_optional'))
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_label'))
          .width('100%')

        TextInput({ placeholder: $r('app.string.gateway_key_placeholder'), text: this.gatewayKey })
          .type(InputType.Password)
          .attributeModifier(new HeszelTextInputStyle(this.focusedInput === LoginInputField.GATEWAY_KEY))
          .onFocus(() => {
            this.focusedInput = LoginInputField.GATEWAY_KEY
          })
          .onBlur(() => {
            this.clearFocusedInput(LoginInputField.GATEWAY_KEY)
          })
          .onChange((value: string) => {
            this.gatewayKey = value
          })
      }
    }
    .width('100%')
  }

  @Builder
  private irohConnectionFields() {
    Column({ space: 12 }) {
      Text($r('app.string.iroh_pairing'))
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_label'))
        .width('100%')

      if (this.pairing.isUsable()) {
        Column({ space: 6 }) {
          Text(this.pairing.displayName.length > 0 ?
            this.pairing.displayName : $r('app.string.iroh_gateway'))
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
          Text(this.pairing.shortEndpointId())
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.routeDescription())
            .fontSize(11)
            .fontColor($r('app.color.text_tertiary'))
            .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(16)
        .backgroundColor($r('app.color.surface'))
        .borderRadius(14)
      } else {
        Text($r('app.string.iroh_scan_hint'))
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(19)
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.surface'))
          .borderRadius(14)
      }

      Button(this.scanning ? $r('app.string.scanning_qr') :
        (this.pairing.isUsable() ? $r('app.string.rescan_qr') : $r('app.string.scan_gateway_qr')))
        .height(48)
        .width('100%')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.action'))
        .backgroundColor($r('app.color.action_surface'))
        .borderRadius(12)
        .enabled(!this.loading && !this.scanning)
        .onClick(() => this.scanPairing())
    }
    .width('100%')
  }

  @Builder
  private credentialsFields() {
    Column({ space: 18 }) {
      Column({ space: 8 }) {
        Text($r('app.string.email'))
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_label'))
          .width('100%')

        TextInput({ placeholder: 'you@example.com', text: this.email })
          .type(InputType.Email)
          .attributeModifier(new HeszelTextInputStyle(this.focusedInput === LoginInputField.EMAIL))
          .onFocus(() => {
            this.focusedInput = LoginInputField.EMAIL
          })
          .onBlur(() => {
            this.clearFocusedInput(LoginInputField.EMAIL)
          })
          .onChange((value: string) => {
            this.email = value
          })
      }

      Column({ space: 8 }) {
        Text($r('app.string.password'))
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_label'))
          .width('100%')

        TextInput({ placeholder: $r('app.string.password_placeholder'), text: this.password })
          .type(InputType.Password)
          .attributeModifier(new HeszelTextInputStyle(this.focusedInput === LoginInputField.PASSWORD))
          .onFocus(() => {
            this.focusedInput = LoginInputField.PASSWORD
          })
          .onBlur(() => {
            this.clearFocusedInput(LoginInputField.PASSWORD)
          })
          .onChange((value: string) => {
            this.password = value
          })
      }
    }
    .width('100%')
  }

  private async scanPairing(): Promise<void> {
    const context = this.getUIContext().getHostContext()
    if (context === undefined) {
      this.scanError = 'Unable to open the system QR scanner.'
      return
    }
    this.scanning = true
    this.scanError = ''
    try {
      this.pairing = await IrohPairingService.scan(context)
    } catch (error) {
      const businessError = error as BusinessError
      if (businessError.code !== 1000500002) {
        this.scanError = error instanceof Error && error.message.length > 0 ?
          error.message : 'Unable to scan the Iroh pairing QR code.'
      }
    } finally {
      this.scanning = false
    }
  }

  private submit(): void {
    const request = new LoginRequest()
    request.mode = this.connectionMode
    request.serverUrl = this.serverUrl
    request.gatewayKey = this.gatewayKey
    request.pairing = this.pairing
    request.email = this.email
    request.password = this.password
    this.onLogin(request)
  }

  private clearFocusedInput(field: LoginInputField): void {
    if (this.focusedInput === field) {
      this.focusedInput = LoginInputField.NONE
    }
  }

  private routeDescription(): ResourceStr {
    if (this.pairing.serverDirectAddresses.length > 0 && this.pairing.serverRelayUrl.length > 0) {
      return $r('app.string.iroh_route_direct_relay')
    }
    if (this.pairing.serverDirectAddresses.length > 0) {
      return $r('app.string.iroh_route_direct')
    }
    return $r('app.string.iroh_route_relay')
  }
}
