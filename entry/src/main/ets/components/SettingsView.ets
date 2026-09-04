import { i18n } from '@kit.LocalizationKit'
import {
  AppColorMode,
  ChartLineOpacity,
  ChartLineWidth,
  CpuChartHeight,
  MetricChartHeight,
  MetricInspectionSort,
  PAGE_CONTENT_BOTTOM_PADDING
} from '../model/AppearanceModels'
import { ConnectionMode } from '../model/ConnectionModels'
import { HeszelTextInputStyle } from '../styles/HeszelTextInputStyle'
import { PageHeader } from './PageHeader'

@Component
export struct SettingsView {
  @Prop signedIn: boolean = true
  @Prop connectionMode: ConnectionMode = ConnectionMode.HTTP
  @Prop connectionLabel: string = ''
  @Prop connectionDetail: string = ''
  @Prop irohRoute: string = 'unknown'
  @Prop email: string = ''
  @Prop expanded: boolean = false
  @Prop errorMessage: string = ''
  @Prop updateWhileScrolling: boolean = false
  @Prop colorMode: AppColorMode = AppColorMode.SYSTEM
  @Prop cpuChartHeight: CpuChartHeight = CpuChartHeight.DEFAULT
  @Prop metricChartHeight: MetricChartHeight = MetricChartHeight.DEFAULT
  @Prop metricInspectionSort: MetricInspectionSort = MetricInspectionSort.VALUE
  @Prop chartLineWidth: ChartLineWidth = ChartLineWidth.DEFAULT
  @Prop chartLineOpacity: ChartLineOpacity = ChartLineOpacity.DEFAULT
  @State private gatewayKeyInput: string = ''
  @State private gatewayKeyInputFocused: boolean = false
  @State private languageCode: string = 'default'
  onBack: () => void = () => {}
  onSignOut: () => void = () => {}
  onGatewayKeyChange: (gatewayKey: string) => void = () => {}
  onUpdateWhileScrollingChange: (enabled: boolean) => void = () => {}
  onColorModeChange: (mode: AppColorMode) => void = () => {}
  onCpuChartHeightChange: (height: CpuChartHeight) => void = () => {}
  onMetricChartHeightChange: (height: MetricChartHeight) => void = () => {}
  onMetricInspectionSortChange: (sort: MetricInspectionSort) => void = () => {}
  onChartLineWidthChange: (width: ChartLineWidth) => void = () => {}
  onChartLineOpacityChange: (opacity: ChartLineOpacity) => void = () => {}
  onLanguageChange: () => void = () => {}

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
        Column({ space: 14 }) {
          Column({ space: 10 }) {
            Text($r('app.string.language_section'))
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_tertiary'))
              .width('100%')

            Column({ space: 8 }) {
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
                  .height(36)
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
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .backgroundColor($r('app.color.surface'))
            .border({ width: 1, color: $r('app.color.card_border') })
            .borderRadius(16)
          }
          .width('100%')

          Column({ space: 10 }) {
            Text($r('app.string.appearance_section'))
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_tertiary'))
              .width('100%')

            Column() {
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
                  .height(36)
                  .font({ size: 13 })
                  .fontColor($r('app.color.text_primary'))
                  .backgroundColor($r('app.color.surface_input'))
                  .onSelect((index: number) => this.changeColorMode(index))
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })

              Divider()
                .color($r('app.color.divider'))
                .margin({ left: 16, right: 16 })

              Row({ space: 12 }) {
                this.settingLabel($r('app.string.cpu_chart_height'), $r('app.string.cpu_chart_height_hint'))

                Select([
                  { value: $r('app.string.cpu_chart_height_default') },
                  { value: $r('app.string.cpu_chart_height_spacious') }
                ])
                  .selected(this.cpuChartHeightIndex())
                  .value(this.cpuChartHeightValue())
                  .height(36)
                  .font({ size: 13 })
                  .fontColor($r('app.color.text_primary'))
                  .backgroundColor($r('app.color.surface_input'))
                  .onSelect((index: number) => this.changeCpuChartHeight(index))
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })

              Divider()
                .color($r('app.color.divider'))
                .margin({ left: 16, right: 16 })

              Row({ space: 12 }) {
                this.settingLabel($r('app.string.metric_chart_height'), $r('app.string.metric_chart_height_hint'))

                Select([
                  { value: $r('app.string.metric_chart_height_compact') },
                  { value: $r('app.string.metric_chart_height_default') },
                  { value: $r('app.string.metric_chart_height_spacious') }
                ])
                  .selected(this.metricChartHeightIndex())
                  .value(this.metricChartHeightValue())
                  .height(36)
                  .font({ size: 13 })
                  .fontColor($r('app.color.text_primary'))
                  .backgroundColor($r('app.color.surface_input'))
                  .onSelect((index: number) => this.changeMetricChartHeight(index))
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })

              Divider()
                .color($r('app.color.divider'))
                .margin({ left: 16, right: 16 })

              Row({ space: 12 }) {
                this.settingLabel($r('app.string.chart_line_width'), $r('app.string.chart_line_width_hint'))

                Select([
                  { value: $r('app.string.chart_line_width_thin') },
                  { value: $r('app.string.chart_line_width_default') },
                  { value: $r('app.string.chart_line_width_thick') }
                ])
                  .selected(this.chartLineWidthIndex())
                  .value(this.chartLineWidthValue())
                  .height(36)
                  .font({ size: 13 })
                  .fontColor($r('app.color.text_primary'))
                  .backgroundColor($r('app.color.surface_input'))
                  .onSelect((index: number) => this.changeChartLineWidth(index))
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })

              Divider()
                .color($r('app.color.divider'))
                .margin({ left: 16, right: 16 })

              Row({ space: 12 }) {
                this.settingLabel($r('app.string.chart_line_opacity'), $r('app.string.chart_line_opacity_hint'))

                Select([
                  { value: $r('app.string.chart_line_opacity_soft') },
                  { value: $r('app.string.chart_line_opacity_default') },
                  { value: $r('app.string.chart_line_opacity_solid') }
                ])
                  .selected(this.chartLineOpacityIndex())
                  .value(this.chartLineOpacityValue())
                  .height(36)
                  .font({ size: 13 })
                  .fontColor($r('app.color.text_primary'))
                  .backgroundColor($r('app.color.surface_input'))
                  .onSelect((index: number) => this.changeChartLineOpacity(index))
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })

              Divider()
                .color($r('app.color.divider'))
                .margin({ left: 16, right: 16 })

              Row({ space: 12 }) {
                this.settingLabel($r('app.string.metric_inspection_sort'),
                  $r('app.string.metric_inspection_sort_hint'))

                Select([
                  { value: $r('app.string.metric_inspection_sort_value') },
                  { value: $r('app.string.metric_inspection_sort_label') }
                ])
                  .selected(this.metricInspectionSortIndex())
                  .value(this.metricInspectionSortValue())
                  .height(36)
                  .font({ size: 13 })
                  .fontColor($r('app.color.text_primary'))
                  .backgroundColor($r('app.color.surface_input'))
                  .onSelect((index: number) => this.changeMetricInspectionSort(index))
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            }
            .width('100%')
            .backgroundColor($r('app.color.surface'))
            .border({ width: 1, color: $r('app.color.card_border') })
            .borderRadius(16)
          }
          .width('100%')

          Column({ space: 10 }) {
            Text($r('app.string.live_metrics_section'))
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_tertiary'))
              .width('100%')

            Row({ space: 12 }) {
              this.settingLabel($r('app.string.update_while_scrolling'),
                $r('app.string.update_while_scrolling_hint'))

              Toggle({ type: ToggleType.Switch, isOn: this.updateWhileScrolling })
                .onChange((enabled: boolean) => this.onUpdateWhileScrollingChange(enabled))
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 12, bottom: 12 })
            .backgroundColor($r('app.color.surface'))
            .border({ width: 1, color: $r('app.color.card_border') })
            .borderRadius(16)
          }
          .width('100%')

          if (this.signedIn && this.connectionMode === ConnectionMode.HTTP) {
            Column({ space: 10 }) {
              Text($r('app.string.gateway_access'))
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_tertiary'))
                .width('100%')

              Column({ space: 10 }) {
                Text($r('app.string.gateway_security_note'))
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
                  .width('100%')

                TextInput({ placeholder: $r('app.string.enter_replacement_key'), text: this.gatewayKeyInput })
                  .type(InputType.Password)
                  .showPasswordIcon(false)
                  .attributeModifier(new HeszelTextInputStyle(this.gatewayKeyInputFocused, 44, 12))
                  .onFocus(() => {
                    this.gatewayKeyInputFocused = true
                  })
                  .onBlur(() => {
                    this.gatewayKeyInputFocused = false
                  })
                  .onChange((value: string) => {
                    this.gatewayKeyInput = value
                  })

                Button($r('app.string.verify_and_update'))
                  .height(40)
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
              .padding({ left: 16, right: 16, top: 12, bottom: 12 })
              .backgroundColor($r('app.color.surface'))
              .border({ width: 1, color: $r('app.color.card_border') })
              .borderRadius(16)
            }
            .width('100%')
          }

          if (this.signedIn) {
            Column({ space: 10 }) {
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
                  Text(this.connectionLabelValue())
                    .fontSize(14)
                    .fontColor($r('app.color.text_primary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .alignItems(HorizontalAlign.Start)
                .width('100%')
                .padding({ left: 16, right: 16, top: 12, bottom: 12 })

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
                .padding({ left: 16, right: 16, top: 12, bottom: 12 })

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
                .padding({ left: 16, right: 16, top: 12, bottom: 12 })

                Divider()
                  .color($r('app.color.divider'))
                  .margin({ left: 16, right: 16 })

                Button($r('app.string.disconnect_hub'))
                  .width('100%')
                  .height(44)
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
          }

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
          bottom: PAGE_CONTENT_BOTTOM_PADDING
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

  @Builder
  private settingLabel(title: ResourceStr, hint: ResourceStr) {
    Column({ space: 4 }) {
      Text(title)
        .fontSize(14)
        .fontColor($r('app.color.text_primary'))
      Text(hint)
        .fontSize(11)
        .fontColor($r('app.color.text_tertiary'))
        .maxLines(2)
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
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

  private connectionLabelValue(): ResourceStr {
    if (this.connectionMode !== ConnectionMode.IROH) return $r('app.string.connection_http')
    if (this.irohRoute === 'direct') return $r('app.string.connection_iroh_direct')
    if (this.irohRoute === 'relay') return $r('app.string.connection_iroh_relay')
    return $r('app.string.connection_iroh_detecting')
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
      this.onLanguageChange()
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

  private cpuChartHeightIndex(): number {
    return this.cpuChartHeight === CpuChartHeight.SPACIOUS ? 1 : 0
  }

  private cpuChartHeightValue(): ResourceStr {
    if (this.cpuChartHeight === CpuChartHeight.SPACIOUS) {
      return $r('app.string.cpu_chart_height_spacious')
    }
    return $r('app.string.cpu_chart_height_default')
  }

  private changeCpuChartHeight(index: number): void {
    const height = index === 1 ? CpuChartHeight.SPACIOUS : CpuChartHeight.DEFAULT
    if (height !== this.cpuChartHeight) {
      this.onCpuChartHeightChange(height)
    }
  }

  private metricChartHeightIndex(): number {
    if (this.metricChartHeight === MetricChartHeight.COMPACT) {
      return 0
    }
    if (this.metricChartHeight === MetricChartHeight.SPACIOUS) {
      return 2
    }
    return 1
  }

  private metricChartHeightValue(): ResourceStr {
    if (this.metricChartHeight === MetricChartHeight.COMPACT) {
      return $r('app.string.metric_chart_height_compact')
    }
    if (this.metricChartHeight === MetricChartHeight.SPACIOUS) {
      return $r('app.string.metric_chart_height_spacious')
    }
    return $r('app.string.metric_chart_height_default')
  }

  private changeMetricChartHeight(index: number): void {
    const height = index === 0 ? MetricChartHeight.COMPACT :
      index === 2 ? MetricChartHeight.SPACIOUS : MetricChartHeight.DEFAULT
    if (height !== this.metricChartHeight) {
      this.onMetricChartHeightChange(height)
    }
  }

  private chartLineWidthIndex(): number {
    if (this.chartLineWidth === ChartLineWidth.THIN) return 0
    if (this.chartLineWidth === ChartLineWidth.THICK) return 2
    return 1
  }

  private chartLineWidthValue(): ResourceStr {
    if (this.chartLineWidth === ChartLineWidth.THIN) return $r('app.string.chart_line_width_thin')
    if (this.chartLineWidth === ChartLineWidth.THICK) return $r('app.string.chart_line_width_thick')
    return $r('app.string.chart_line_width_default')
  }

  private changeChartLineWidth(index: number): void {
    const width = index === 0 ? ChartLineWidth.THIN :
      index === 2 ? ChartLineWidth.THICK : ChartLineWidth.DEFAULT
    if (width !== this.chartLineWidth) this.onChartLineWidthChange(width)
  }

  private chartLineOpacityIndex(): number {
    if (this.chartLineOpacity === ChartLineOpacity.SOFT) return 0
    if (this.chartLineOpacity === ChartLineOpacity.SOLID) return 2
    return 1
  }

  private chartLineOpacityValue(): ResourceStr {
    if (this.chartLineOpacity === ChartLineOpacity.SOFT) return $r('app.string.chart_line_opacity_soft')
    if (this.chartLineOpacity === ChartLineOpacity.SOLID) return $r('app.string.chart_line_opacity_solid')
    return $r('app.string.chart_line_opacity_default')
  }

  private changeChartLineOpacity(index: number): void {
    const opacity = index === 0 ? ChartLineOpacity.SOFT :
      index === 2 ? ChartLineOpacity.SOLID : ChartLineOpacity.DEFAULT
    if (opacity !== this.chartLineOpacity) this.onChartLineOpacityChange(opacity)
  }

  private metricInspectionSortIndex(): number {
    return this.metricInspectionSort === MetricInspectionSort.LABEL ? 1 : 0
  }

  private metricInspectionSortValue(): ResourceStr {
    return this.metricInspectionSort === MetricInspectionSort.LABEL ?
      $r('app.string.metric_inspection_sort_label') : $r('app.string.metric_inspection_sort_value')
  }

  private changeMetricInspectionSort(index: number): void {
    const sort = index === 1 ? MetricInspectionSort.LABEL : MetricInspectionSort.VALUE
    if (sort !== this.metricInspectionSort) {
      this.onMetricInspectionSortChange(sort)
    }
  }
}
