import { NetworkInterfaceMetric, SystemDetailState } from '../model/SystemDetailModels'
import { formatBytes, formatRate } from './DetailFormatting'
import { DetailValueRow } from './DetailValueRow'

@Component
export struct NetworkCard {
  @ObjectLink detail: SystemDetailState

  build() {
    Column({ space: 11 }) {
      Text('Network')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      DetailValueRow({ label: 'Upload', value: formatRate(this.detail.metrics.uploadBytesPerSecond) })
      DetailValueRow({ label: 'Download', value: formatRate(this.detail.metrics.downloadBytesPerSecond) })

      ForEach(this.detail.metrics.interfaces, (networkInterface: NetworkInterfaceMetric) => {
        Divider().color($r('app.color.divider'))
        Column({ space: 8 }) {
          Text(networkInterface.name)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
          DetailValueRow({
            label: 'Up / down',
            value: `${formatRate(networkInterface.uploadBytesPerSecond)} · ${formatRate(networkInterface.downloadBytesPerSecond)}`
          })
          if (networkInterface.totalUploadBytes > 0 || networkInterface.totalDownloadBytes > 0) {
            DetailValueRow({
              label: 'Session total',
              value: `${formatBytes(networkInterface.totalUploadBytes)} · ${formatBytes(networkInterface.totalDownloadBytes)}`
            })
          }
        }
        .width('100%')
      }, (networkInterface: NetworkInterfaceMetric) => networkInterface.name)
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(16)
  }
}
