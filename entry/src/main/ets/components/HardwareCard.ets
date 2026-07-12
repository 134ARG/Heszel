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
      Text('System')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      if (this.detail.hardware.cpuModel.length > 0) {
        Column({ space: 4 }) {
          Text('Processor')
            .fontSize(11)
            .fontColor($r('app.color.text_tertiary'))
          Text(this.detail.hardware.cpuModel)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
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
    .borderRadius(16)
  }

  @Builder
  private primaryDetails() {
    if (this.detail.hardware.hostname.length > 0) {
      DetailValueRow({ label: 'Hostname', value: this.detail.hardware.hostname })
    }
    if (this.detail.hardware.osName.length > 0) {
      DetailValueRow({ label: 'OS', value: this.detail.hardware.osName })
    }
    if (this.detail.hardware.kernel.length > 0) {
      DetailValueRow({ label: 'Kernel', value: this.detail.hardware.kernel })
    }
  }

  @Builder
  private secondaryDetails() {
    if (this.detail.hardware.cores > 0) {
      DetailValueRow({
        label: 'CPU topology',
        value: `${this.detail.hardware.cores.toFixed(0)} cores · ${this.detail.hardware.threads.toFixed(0)} threads`
      })
    }
    if (this.detail.hardware.memoryBytes > 0) {
      DetailValueRow({ label: 'Installed memory', value: formatBytes(this.detail.hardware.memoryBytes) })
    }
    if (this.detail.hardware.architecture.length > 0) {
      DetailValueRow({ label: 'Architecture', value: this.detail.hardware.architecture })
    }
    if (this.agentVersion.length > 0) {
      DetailValueRow({ label: 'Agent', value: this.agentVersion })
    }
    if (this.detail.hardware.podman) {
      DetailValueRow({ label: 'Containers', value: 'Podman' })
    }
  }
}
