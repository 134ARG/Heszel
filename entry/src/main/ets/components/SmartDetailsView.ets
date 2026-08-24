import { SmartAttributeMetric, SmartDeviceMetric, SmartHealthState } from '../model/SmartModels'
import { formatCapacityBytes } from './DetailFormatting'
import { DetailValueRow } from './DetailValueRow'

@Component
struct SmartIndicatorRow {
  @ObjectLink attribute: SmartAttributeMetric

  build() {
    DetailValueRow({
      label: this.label(),
      value: this.value(),
      warning: this.attribute.isWarning()
    })
  }

  private label(): ResourceStr {
    const key = this.attribute.normalizedName()
    if (key.includes('criticalwarning')) return $r('app.string.smart_critical_warning')
    if (key.includes('percentageused')) return $r('app.string.smart_life_used')
    if (key.includes('availablespare')) return $r('app.string.smart_available_spare')
    if (key.includes('mediaerror')) return $r('app.string.smart_media_errors')
    if (key.includes('unsafeshutdown')) return $r('app.string.smart_unsafe_shutdowns')
    if (key.includes('reallocatedsector')) return $r('app.string.smart_reallocated_sectors')
    if (key.includes('pendingsector')) return $r('app.string.smart_pending_sectors')
    if (key.includes('offlineuncorrectable')) return $r('app.string.smart_uncorrectable_sectors')
    return this.attribute.name
  }

  private value(): string {
    const key = this.attribute.normalizedName()
    const raw = this.attribute.rawString.length > 0 ? this.attribute.rawString :
      this.attribute.rawValue.toLocaleString()
    return key.includes('percentageused') || key.includes('availablespare') ? `${raw}%` : raw
  }
}

@Component
struct SmartAttributeRow {
  @ObjectLink attribute: SmartAttributeMetric

  build() {
    Column({ space: 4 }) {
      Row({ space: 12 }) {
        Text(this.title())
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.rawValue())
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.attribute.isWarning() ? $r('app.color.error') : $r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')

      if (this.attribute.currentAvailable || this.attribute.worstAvailable || this.attribute.thresholdAvailable) {
        Text($r('app.string.smart_normalized_values',
          this.numberOrDash(this.attribute.current, this.attribute.currentAvailable),
          this.numberOrDash(this.attribute.worst, this.attribute.worstAvailable),
          this.numberOrDash(this.attribute.threshold, this.attribute.thresholdAvailable)))
          .fontSize(10)
          .fontColor($r('app.color.text_tertiary'))
          .width('100%')
      }
    }
    .width('100%')
  }

  private title(): string {
    return this.attribute.id > 0 ? `${this.attribute.id} · ${this.attribute.name}` : this.attribute.name
  }

  private rawValue(): string {
    if (this.attribute.rawString.length > 0) return this.attribute.rawString
    return this.attribute.rawAvailable ? this.attribute.rawValue.toLocaleString() : '—'
  }

  private numberOrDash(value: number, available: boolean): string {
    return available ? value.toLocaleString() : '—'
  }
}

@Component
struct SmartDeviceDetailsCard {
  @ObjectLink device: SmartDeviceMetric
  @State private showAttributes: boolean = false

  build() {
    Column({ space: 11 }) {
      Row({ space: 10 }) {
        Row()
          .width(9)
          .height(9)
          .borderRadius(5)
          .backgroundColor(this.statusColor())
        Column({ space: 2 }) {
          Text(this.device.displayName())
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.deviceMeta())
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Column({ space: 2 }) {
          if (this.device.temperatureCelsius > 0) {
            Text(`${this.device.temperatureCelsius.toFixed(0)} °C`)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
          }
          Text(this.statusLabel())
            .fontSize(10)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.statusColor())
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')

      if (this.device.powerOnHours > 0) {
        DetailValueRow({
          label: $r('app.string.smart_power_on'),
          value: $r('app.string.smart_hours_value', this.device.powerOnHours.toLocaleString())
        })
      }
      if (this.device.powerCycles > 0) {
        DetailValueRow({
          label: $r('app.string.smart_power_cycles'),
          value: this.device.powerCycles.toLocaleString()
        })
      }

      if (this.device.featuredAttributes().length > 0) {
        Divider().color($r('app.color.divider'))
        Text($r('app.string.smart_key_indicators'))
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_tertiary'))
          .width('100%')
        ForEach(this.device.featuredAttributes(), (attribute: SmartAttributeMetric) => {
          SmartIndicatorRow({ attribute: attribute })
        }, (attribute: SmartAttributeMetric, index: number) => `${attribute.id}:${attribute.name}:${index}`)
      }

      if (this.device.firmware.length > 0 || this.device.serial.length > 0) {
        Divider().color($r('app.color.divider'))
        Text($r('app.string.smart_device_information'))
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_tertiary'))
          .width('100%')
        if (this.device.firmware.length > 0) {
          DetailValueRow({ label: $r('app.string.smart_firmware'), value: this.device.firmware })
        }
        if (this.device.serial.length > 0) {
          DetailValueRow({ label: $r('app.string.smart_serial'), value: this.device.serial })
        }
      }

      if (this.device.attributes.length > 0) {
        Button($r('app.string.smart_attributes_count', this.device.attributes.length))
          .height(38)
          .width('100%')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.action'))
          .backgroundColor($r('app.color.action_surface'))
          .borderRadius(10)
          .onClick(() => {
            this.showAttributes = !this.showAttributes
          })

        if (this.showAttributes) {
          Column({ space: 9 }) {
            ForEach(this.device.attributes, (attribute: SmartAttributeMetric, index: number) => {
              Column() {
                if (index > 0) {
                  Divider()
                    .color($r('app.color.divider'))
                    .margin({ bottom: 9 })
                }
                SmartAttributeRow({ attribute: attribute })
              }
              .width('100%')
            }, (attribute: SmartAttributeMetric, index: number) => `${attribute.id}:${attribute.name}:${index}`)
          }
          .width('100%')
        }
      }
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.card_border') })
    .borderRadius(16)
  }

  private deviceMeta(): string {
    const parts: string[] = []
    if (this.device.name.length > 0) parts.push(this.device.name)
    parts.push(this.device.typeLabel())
    if (this.device.capacityBytes > 0) parts.push(formatCapacityBytes(this.device.capacityBytes))
    return parts.join(' · ')
  }

  private statusLabel(): ResourceStr {
    if (this.device.isHealthy()) return $r('app.string.smart_status_healthy')
    if (this.device.isWarning()) return $r('app.string.smart_status_warning')
    if (this.device.isFailed()) return $r('app.string.smart_status_failed')
    return $r('app.string.smart_status_unknown')
  }

  private statusColor(): ResourceColor {
    if (this.device.isHealthy()) return $r('app.color.status_up')
    if (this.device.isWarning()) return $r('app.color.metric_disk')
    if (this.device.isFailed()) return $r('app.color.error')
    return $r('app.color.text_tertiary')
  }
}

@Component
export struct SmartDetailsView {
  @ObjectLink state: SmartHealthState
  @Prop compact: boolean = false
  onBack: () => void = () => {}
  onScrollingChange: (scrolling: boolean) => void = () => {}

  build() {
    Column() {
      Row({ space: 12 }) {
        Button($r('app.string.back_system_detail'))
          .height(38)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.action'))
          .backgroundColor($r('app.color.action_surface'))
          .borderRadius(10)
          .onClick(() => this.onBack())
        Column({ space: 2 }) {
          Text($r('app.string.drive_health'))
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
          Text(this.summaryLabel())
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 18, bottom: 14 })
      .backgroundColor($r('app.color.surface_header'))

      Scroll() {
        Column({ space: 14 }) {
          if (this.state.latestUpdated.length > 0) {
            Text($r('app.string.smart_last_checked', this.checkedTime()))
              .fontSize(11)
              .fontColor($r('app.color.text_tertiary'))
              .width('100%')
          }
          ForEach(this.state.devices, (device: SmartDeviceMetric) => {
            SmartDeviceDetailsCard({ device: device })
          }, (device: SmartDeviceMetric) => device.id)
        }
        .width('100%')
        .padding({
          left: this.compact ? 16 : 22,
          right: this.compact ? 16 : 22,
          top: 14,
          bottom: 30
        })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .onScrollStart(() => this.onScrollingChange(true))
      .onScrollStop(() => this.onScrollingChange(false))
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }

  private summaryLabel(): ResourceStr {
    if (this.state.attentionCount() > 0) {
      return $r('app.string.smart_attention_summary', this.state.attentionCount(), this.state.devices.length)
    }
    if (this.state.unknownCount() > 0) {
      return $r('app.string.smart_unknown_summary', this.state.unknownCount(), this.state.devices.length)
    }
    return $r('app.string.smart_healthy_summary', this.state.devices.length)
  }

  private checkedTime(): string {
    const timestamp = new Date(this.state.latestUpdated)
    return Number.isNaN(timestamp.getTime()) ? this.state.latestUpdated : timestamp.toLocaleString()
  }
}
