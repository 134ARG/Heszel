import { ContainerMetric, SystemDetailState } from '../model/SystemDetailModels'
import { formatGigabytes, formatRate } from './DetailFormatting'
import { DetailValueRow } from './DetailValueRow'

@Component
export struct ContainersCard {
  @ObjectLink detail: SystemDetailState

  build() {
    Column({ space: 11 }) {
      Row() {
        Text('Containers')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Text(this.detail.containers.length.toString())
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')

      ForEach(this.detail.containers, (container: ContainerMetric, index: number) => {
        if (index > 0) {
          Divider().color($r('app.color.divider'))
        }
        Column({ space: 7 }) {
          Text(container.name)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          DetailValueRow({ label: 'CPU', value: `${container.cpuPercent.toFixed(1)}%` })
          DetailValueRow({ label: 'Memory', value: formatGigabytes(container.memoryGb) })
          if (container.uploadBytesPerSecond > 0 || container.downloadBytesPerSecond > 0) {
            DetailValueRow({
              label: 'Network up / down',
              value: `${formatRate(container.uploadBytesPerSecond)} · ${formatRate(container.downloadBytesPerSecond)}`
            })
          }
        }
        .width('100%')
      }, (container: ContainerMetric) => container.name)
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(16)
  }
}
