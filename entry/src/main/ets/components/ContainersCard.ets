import { ContainerMetric, ContainerMetricsState } from '../model/SystemDetailModels'
import { formatGigabytes, formatRate } from './DetailFormatting'
import { DetailCardHeader } from './DetailCardHeader'
import { DetailValueRow } from './DetailValueRow'

@Component
export struct ContainersCard {
  @ObjectLink state: ContainerMetricsState

  build() {
    Column({ space: 11 }) {
      DetailCardHeader({ title: `Containers · ${this.state.containers.length}` })

      if (this.state.containers.length === 0) {
        Text('No running containers')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      }

      ForEach(this.state.containers, (container: ContainerMetric, index: number) => {
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
          if (container.hasNetwork) {
            DetailValueRow({
              label: 'Network up / down',
              value: `${formatRate(container.uploadBytesPerSecond)} · ${formatRate(container.downloadBytesPerSecond)}`
            })
          }
        }
        .width('100%')
      }, (container: ContainerMetric) =>
        `${container.name}:${container.cpuPercent.toFixed(1)}:${formatGigabytes(container.memoryGb)}:` +
          `${formatRate(container.uploadBytesPerSecond)}:${formatRate(container.downloadBytesPerSecond)}:` +
          `${container.hasNetwork}`)
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(16)
  }
}
