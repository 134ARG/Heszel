import { SystemDetailState } from '../model/SystemDetailModels'
import { formatBytes } from './DetailFormatting'
import { DetailValueRow } from './DetailValueRow'

@Component
export struct HardwareCard {
  @ObjectLink detail: SystemDetailState
  @Prop agentVersion: string = ''
  @Prop compact: boolean = false

  build() {
    Column({ space: 10 }) {
      Text($r('app.string.system_detail'))
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      if (this.detail.hardware.cpuModel.length > 0) {
        DetailValueRow({ label: $r('app.string.processor'), value: this.detail.hardware.cpuModel })
      }

      if (this.compact) {
        Column({ space: 10 }) {
          this.primaryDetails()
          this.secondaryDetails()
        }
        .width('100%')
      } else {
        Row({ space: 24 }) {
          Column({ space: 10 }) {
            this.primaryDetails()
          }
          .layoutWeight(1)
          Column({ space: 10 }) {
            this.secondaryDetails()
          }
          .layoutWeight(1)
        }
        .alignItems(VerticalAlign.Top)
        .width('100%')
      }
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.card_border') })
    .borderRadius(16)
  }

  @Builder
  private primaryDetails() {
    if (this.detail.hardware.hostname.length > 0) {
      DetailValueRow({ label: $r('app.string.hostname'), value: this.detail.hardware.hostname })
    }
    if (this.detail.hardware.osName.length > 0) {
      DetailValueRow({ label: $r('app.string.operating_system'), value: this.detail.hardware.osName })
    }
    if (this.detail.hardware.kernel.length > 0) {
      DetailValueRow({ label: $r('app.string.kernel'), value: this.detail.hardware.kernel })
    }
  }

  @Builder
  private secondaryDetails() {
    if (this.detail.hardware.cores > 0) {
      DetailValueRow({
        label: $r('app.string.cpu_topology'),
        value: $r('app.string.cpu_topology_value', this.detail.hardware.cores, this.detail.hardware.threads)
      })
    }
    if (this.detail.hardware.memoryBytes > 0) {
      DetailValueRow({ label: $r('app.string.installed_memory'), value: formatBytes(this.detail.hardware.memoryBytes) })
    }
    if (this.detail.hardware.architecture.length > 0) {
      DetailValueRow({ label: $r('app.string.architecture'), value: this.detail.hardware.architecture })
    }
    if (this.agentVersion.length > 0) {
      DetailValueRow({ label: $r('app.string.agent'), value: this.agentVersion })
    }
    if (this.detail.hardware.podman) {
      DetailValueRow({ label: $r('app.string.containers'), value: 'Podman' })
    }
  }
}
