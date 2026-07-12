import { NetworkInterfaceMetric, NetworkMetricsState } from '../model/SystemDetailModels'
import { formatBytes, formatRate } from './DetailFormatting'
import { DetailCardHeader } from './DetailCardHeader'
import { DetailValueRow } from './DetailValueRow'

@Component
export struct NetworkCard {
  @ObjectLink state: NetworkMetricsState

  build() {
    Column({ space: 11 }) {
      DetailCardHeader({ title: 'Network' })
      DetailValueRow({ label: 'Upload', value: formatRate(this.state.uploadBytesPerSecond) })
      DetailValueRow({ label: 'Download', value: formatRate(this.state.downloadBytesPerSecond) })

      ForEach(this.state.interfaces, (networkInterface: NetworkInterfaceMetric) => {
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
          DetailValueRow({
            label: 'Session total',
            value: `${formatBytes(networkInterface.totalUploadBytes)} · ${formatBytes(networkInterface.totalDownloadBytes)}`
          })
        }
        .width('100%')
      }, (networkInterface: NetworkInterfaceMetric) =>
        `${networkInterface.name}:${formatRate(networkInterface.uploadBytesPerSecond)}:` +
          `${formatRate(networkInterface.downloadBytesPerSecond)}:${formatBytes(networkInterface.totalUploadBytes)}:` +
          `${formatBytes(networkInterface.totalDownloadBytes)}`)
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.card_border') })
    .borderRadius(16)
  }
}
