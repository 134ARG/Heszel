import { ContainerMetric, ContainerMetricsState } from '../model/SystemDetailModels'
import { formatGigabytes, formatRate } from './DetailFormatting'
import { DetailCardHeader } from './DetailCardHeader'
import { DetailValueRow } from './DetailValueRow'

@Component
struct ContainerSection {
  @ObjectLink container: ContainerMetric
  @Prop showDivider: boolean = false

  build() {
    Column() {
      if (this.showDivider) {
        Divider().color($r('app.color.divider'))
      }
      Column({ space: 7 }) {
        Text(this.container.name)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        DetailValueRow({ label: 'CPU', value: `${this.container.cpuPercent.toFixed(1)}%` })
        DetailValueRow({ label: $r('app.string.memory'), value: formatGigabytes(this.container.memoryGb) })
        if (this.container.hasNetwork) {
          DetailValueRow({
            label: $r('app.string.network_up_down'),
            value: `${formatRate(this.container.uploadBytesPerSecond)} · ` +
              `${formatRate(this.container.downloadBytesPerSecond)}`
          })
        }
      }
      .width('100%')
    }
    .width('100%')
  }
}

@Component
export struct ContainersCard {
  @ObjectLink state: ContainerMetricsState

  build() {
    Column({ space: 11 }) {
      DetailCardHeader({ title: $r('app.string.containers_count', this.state.containers.length) })

      if (this.state.containers.length === 0) {
        Text($r('app.string.no_running_containers'))
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      }

      ForEach(this.state.containers, (container: ContainerMetric, index: number) => {
        ContainerSection({ container: container, showDivider: index > 0 })
      }, (container: ContainerMetric) => container.name)
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.card_border') })
    .borderRadius(16)
  }
}
