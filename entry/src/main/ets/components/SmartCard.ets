import { SmartDeviceMetric, SmartHealthState } from '../model/SmartModels'
import { formatCapacityBytes } from './DetailFormatting'
import { DetailCardHeader } from './DetailCardHeader'

@Component
struct SmartDeviceSummary {
  @ObjectLink device: SmartDeviceMetric

  build() {
    Row({ space: 10 }) {
      Row()
        .width(8)
        .height(8)
        .borderRadius(4)
        .backgroundColor(this.statusColor())

      Column({ space: 3 }) {
        Text(this.device.displayName())
          .fontSize(13)
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
        if (this.device.powerOnHours > 0) {
          Text($r('app.string.smart_power_on_value', this.device.powerOnHours.toLocaleString()))
            .fontSize(11)
            .fontColor($r('app.color.text_tertiary'))
            .width('100%')
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Column({ space: 3 }) {
        if (this.device.temperatureCelsius > 0) {
          Text(`${this.device.temperatureCelsius.toFixed(0)} °C`)
            .fontSize(13)
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
export struct SmartCard {
  @ObjectLink state: SmartHealthState
  onViewDetails: () => void = () => {}

  build() {
    Column({ space: 11 }) {
      DetailCardHeader({ title: $r('app.string.drive_health_count', this.state.devices.length) })

      ForEach(this.state.summaryDevices(), (device: SmartDeviceMetric, index: number) => {
        Column() {
          if (index > 0) {
            Divider()
              .color($r('app.color.divider'))
              .margin({ bottom: 10 })
          }
          SmartDeviceSummary({ device: device })
        }
        .width('100%')
      }, (device: SmartDeviceMetric) => device.id)

      if (this.state.devices.length > 6) {
        Text($r('app.string.smart_more_drives', this.state.devices.length - 6))
          .fontSize(11)
          .fontColor($r('app.color.text_tertiary'))
          .width('100%')
      }

      Button($r('app.string.view_details'))
        .height(38)
        .width('100%')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.action'))
        .backgroundColor($r('app.color.action_surface'))
        .borderRadius(10)
        .onClick(() => this.onViewDetails())
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.card_border') })
    .borderRadius(16)
  }
}
