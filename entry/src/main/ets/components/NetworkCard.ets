import { NetworkInterfaceMetric, NetworkMetricsState } from '../model/SystemDetailModels'
import { formatBytes, formatRate } from './DetailFormatting'
import { DetailCardHeader } from './DetailCardHeader'
import { DetailValueRow } from './DetailValueRow'

@Component
struct NetworkInterfaceSection {
  @ObjectLink networkInterface: NetworkInterfaceMetric

  build() {
    Column({ space: 12 }) {
      Divider().color($r('app.color.divider'))
      Column({ space: 8 }) {
        Text(this.networkInterface.name)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
        DetailValueRow({
          label: $r('app.string.up_down'),
          value: `${formatRate(this.networkInterface.uploadBytesPerSecond)} · ` +
            `${formatRate(this.networkInterface.downloadBytesPerSecond)}`
        })
        DetailValueRow({
          label: $r('app.string.session_total'),
          value: `${formatBytes(this.networkInterface.totalUploadBytes)} · ` +
            `${formatBytes(this.networkInterface.totalDownloadBytes)}`
        })
      }
      .width('100%')
    }
    .width('100%')
  }
}

@Component
export struct NetworkCard {
  @ObjectLink state: NetworkMetricsState

  build() {
    Column({ space: 11 }) {
      DetailCardHeader({ title: $r('app.string.network') })
      DetailValueRow({ label: $r('app.string.upload'), value: formatRate(this.state.uploadBytesPerSecond) })
      DetailValueRow({ label: $r('app.string.download'), value: formatRate(this.state.downloadBytesPerSecond) })

      ForEach(this.state.interfaces, (networkInterface: NetworkInterfaceMetric) => {
        NetworkInterfaceSection({ networkInterface: networkInterface })
      }, (networkInterface: NetworkInterfaceMetric) => networkInterface.name)
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.card_border') })
    .borderRadius(16)
  }
}
