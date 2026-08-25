import { i18n } from '@kit.LocalizationKit'
import { AppColorMode } from '../model/AppearanceModels'
import { ConnectionMode } from '../model/ConnectionModels'
import { PageHeader } from './PageHeader'

@Component
export struct SettingsView {
  @Prop connectionMode: ConnectionMode = ConnectionMode.HTTP
  @Prop connectionLabel: string = ''
  @Prop connectionDetail: string = ''
  @Prop email: string = ''
  @Prop expanded: boolean = false
  @Prop errorMessage: string = ''
  @Prop updateWhileScrolling: boolean = false
  @Prop colorMode: AppColorMode = AppColorMode.SYSTEM
  @State private gatewayKeyInput: string = ''
  @State private languageCode: string = 'default'
  onBack: () => void = () => {}
  onSignOut: () => void = () => {}
  onGatewayKeyChange: (gatewayKey: string) => void = () => {}
  onUpdateWhileScrollingChange: (enabled: boolean) => void = () => {}
  onColorModeChange: (mode: AppColorMode) => void = () => {}

  aboutToAppear(): void {
    try {
      this.languageCode = this.normalizeLanguage(i18n.System.getAppPreferredLanguage())
    } catch (_) {
      this.languageCode = 'default'
    }
  }

  build() {
    Column() {
      PageHeader({
        title: $r('app.string.settings'),
        showBack: true,
        backLabel: $r('app.string.back_dashboard'),
        onBack: () => this.onBack()
      })

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
            Text($r('app.string.language_section'))
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_tertiary'))
              .width('100%')

            Column({ space: 10 }) {
              Row({ space: 12 }) {
                Text($r('app.string.language'))
                  .fontSize(14)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)

                Select([
                  { value: $r('app.string.language_system') },
                  { value: $r('app.string.language_english') },
                  { value: $r('app.string.language_chinese') }
                ])
                  .selected(this.languageIndex())
                  .value(this.languageValue())
                  .height(42)
                  .font({ size: 13 })
                  .fontColor($r('app.color.text_primary'))
                  .backgroundColor($r('app.color.surface_input'))
                  .onSelect((index: number) => this.changeLanguage(index))
              }
              .width('100%')

              // Text($r('app.string.language_restart_hint'))
              //   .fontSize(11)
              //   .fontColor($r('app.color.text_tertiary'))
              //   .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.surface'))
            .border({ width: 1, color: $r('app.color.card_border') })
            .borderRadius(16)
          }
          .width('100%')

          Column({ space: 12 }) {
            Text($r('app.string.appearance_section'))
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_tertiary'))
              .width('100%')

            Row({ space: 12 }) {
              Text($r('app.string.color_mode'))
                .fontSize(14)
                .fontColor($r('app.color.text_primary'))
                .layoutWeight(1)

              Select([
                { value: $r('app.string.color_mode_system') },
                { value: $r('app.string.color_mode_dark') },
                { value: $r('app.string.color_mode_light') }
              ])
                .selected(this.colorModeIndex())
                .value(this.colorModeValue())
                .height(42)
                .font({ size: 13 })
                .fontColor($r('app.color.text_primary'))
                .backgroundColor($r('app.color.surface_input'))
                .onSelect((index: number) => this.changeColorMode(index))
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.surface'))
            .border({ width: 1, color: $r('app.color.card_border') })
            .borderRadius(16)
          }
          .width('100%')

          Column({ space: 12 }) {
            Text($r('app.string.live_metrics_section'))
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_tertiary'))
              .width('100%')

            Row({ space: 12 }) {
              Column({ space: 4 }) {
                Text($r('app.string.update_while_scrolling'))
                  .fontSize(14)
                  .fontColor($r('app.color.text_primary'))
                Text($r('app.string.update_while_scrolling_hint'))
                  .fontSize(11)
                  .fontColor($r('app.color.text_tertiary'))
                  .maxLines(2)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Toggle({ type: ToggleType.Switch, isOn: this.updateWhileScrolling })
                .onChange((enabled: boolean) => this.onUpdateWhileScrollingChange(enabled))
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.surface'))
            .border({ width: 1, color: $r('app.color.card_border') })
            .borderRadius(16)
          }
          .width('100%')

          if (this.connectionMode === ConnectionMode.HTTP) {
            Column({ space: 12 }) {
              Text($r('app.string.gateway_access'))
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_tertiary'))
                .width('100%')

              Column({ space: 12 }) {
                Text($r('app.string.gateway_security_note'))
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
                  .width('100%')

                TextInput({ placeholder: $r('app.string.enter_replacement_key'), text: this.gatewayKeyInput })
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

                Button($r('app.string.verify_and_update'))
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
              .border({ width: 1, color: $r('app.color.card_border') })
              .borderRadius(16)
            }
            .width('100%')
          }

          Column({ space: 12 }) {
            Text($r('app.string.account'))
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_tertiary'))
              .width('100%')

            Column() {
              Column({ space: 4 }) {
                Text($r('app.string.connection'))
                  .fontSize(11)
                  .fontColor($r('app.color.text_tertiary'))
                Text(this.connectionMode === ConnectionMode.IROH ?
                  $r('app.string.connection_iroh') : $r('app.string.connection_http'))
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

              Column({ space: 4 }) {
                Text(this.connectionMode === ConnectionMode.IROH ?
                  $r('app.string.iroh_gateway') : $r('app.string.beszel_hub'))
                  .fontSize(11)
                  .fontColor($r('app.color.text_tertiary'))
                Text(this.connectionLabel)
                  .fontSize(14)
                  .fontColor($r('app.color.text_primary'))
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                if (this.connectionDetail.length > 0) {
                  Text(this.connectionDetail)
                    .fontSize(11)
                    .fontColor($r('app.color.text_tertiary'))
                    .width('100%')
                    .wordBreak(WordBreak.BREAK_ALL)
                }
              }
              .alignItems(HorizontalAlign.Start)
              .width('100%')
              .padding(16)

              Divider()
                .color($r('app.color.divider'))
                .margin({ left: 16, right: 16 })

              Column({ space: 4 }) {
                Text($r('app.string.signed_in_as'))
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

              Button($r('app.string.sign_out'))
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
            .border({ width: 1, color: $r('app.color.card_border') })
            .borderRadius(16)
          }
          .width('100%')

          Text($r('app.string.app_version'))
            .fontSize(11)
            .fontColor($r('app.color.text_tertiary'))
            .textAlign(TextAlign.Center)
            .width('100%')
        }
        .width(this.expanded ? 620 : '100%')
        .padding({
          left: this.expanded ? 22 : 16,
          right: this.expanded ? 22 : 16,
          top: 14,
          bottom: 30
        })
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

  private normalizeLanguage(language: string): string {
    if (language.startsWith('zh')) {
      return 'zh-CN'
    }
    if (language.startsWith('en')) {
      return 'en'
    }
    return 'default'
  }

  private languageIndex(): number {
    if (this.languageCode === 'en') {
      return 1
    }
    if (this.languageCode === 'zh-CN') {
      return 2
    }
    return 0
  }

  private languageValue(): ResourceStr {
    if (this.languageCode === 'en') {
      return $r('app.string.language_english')
    }
    if (this.languageCode === 'zh-CN') {
      return $r('app.string.language_chinese')
    }
    return $r('app.string.language_system')
  }

  private changeLanguage(index: number): void {
    const language = index === 1 ? 'en' : index === 2 ? 'zh-CN' : 'default'
    if (language === this.languageCode) {
      return
    }
    const previous = this.languageCode
    try {
      if (language === 'default') {
        // HarmonyOS applies `default` on cold start; load the current system language now first.
        i18n.System.setAppPreferredLanguage(i18n.System.getSystemLanguage())
      }
      i18n.System.setAppPreferredLanguage(language)
      this.languageCode = language
    } catch (_) {
      try {
        i18n.System.setAppPreferredLanguage(previous)
      } catch (_) {
        // Keep the current resources if HarmonyOS also rejects the rollback.
      }
    }
  }

  private colorModeIndex(): number {
    if (this.colorMode === AppColorMode.DARK) {
      return 1
    }
    if (this.colorMode === AppColorMode.LIGHT) {
      return 2
    }
    return 0
  }

  private colorModeValue(): ResourceStr {
    if (this.colorMode === AppColorMode.DARK) {
      return $r('app.string.color_mode_dark')
    }
    if (this.colorMode === AppColorMode.LIGHT) {
      return $r('app.string.color_mode_light')
    }
    return $r('app.string.color_mode_system')
  }

  private changeColorMode(index: number): void {
    const mode = index === 1 ? AppColorMode.DARK : index === 2 ? AppColorMode.LIGHT : AppColorMode.SYSTEM
    if (mode !== this.colorMode) {
      this.onColorModeChange(mode)
    }
  }
}
