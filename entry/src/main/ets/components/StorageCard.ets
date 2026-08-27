import { FilesystemMetric, StorageMetricsState } from '../model/SystemDetailModels'
import { formatGigabytes, formatRate } from './DetailFormatting'
import { DetailCardHeader } from './DetailCardHeader'
import { DetailValueRow } from './DetailValueRow'
import { PressureBar } from './PressureBar'

@Component
struct FilesystemSection {
  @ObjectLink filesystem: FilesystemMetric

  build() {
    Column({ space: 12 }) {
      Divider().color($r('app.color.divider'))
      Column({ space: 9 }) {
        PressureBar({
          value: this.percent(),
          label: this.filesystem.name,
          color: $r('app.color.metric_disk')
        })
        DetailValueRow({
          label: $r('app.string.used'),
          value: `${formatGigabytes(this.filesystem.usedGb)} / ${formatGigabytes(this.filesystem.totalGb)}`
        })
        DetailValueRow({
          label: $r('app.string.read_write'),
          value: `${formatRate(this.filesystem.readBytesPerSecond)} · ${formatRate(this.filesystem.writeBytesPerSecond)}`
        })
      }
      .width('100%')
    }
    .width('100%')
  }

  private percent(): number {
    return this.filesystem.totalGb > 0 ? this.filesystem.usedGb / this.filesystem.totalGb * 100 : 0
  }
}

@Component
export struct StorageCard {
  @ObjectLink state: StorageMetricsState

  build() {
    Column({ space: 12 }) {
      DetailCardHeader({ title: $r('app.string.storage') })
      PressureBar({
        value: this.state.percent,
        label: $r('app.string.root_filesystem'),
        color: $r('app.color.metric_disk')
      })
      DetailValueRow({
        label: $r('app.string.root_used'),
        value: `${formatGigabytes(this.state.usedGb)} / ${formatGigabytes(this.state.totalGb)}`
      })
      DetailValueRow({ label: $r('app.string.read'), value: formatRate(this.state.readBytesPerSecond) })
      DetailValueRow({ label: $r('app.string.write'), value: formatRate(this.state.writeBytesPerSecond) })
      if (this.state.diskIoVisible()) {
        DetailValueRow({ label: $r('app.string.io_utilization'), value: `${this.state.ioPercent.toFixed(0)}%` })
      }
      if (this.state.latencyVisible()) {
        DetailValueRow({
          label: $r('app.string.read_write_latency'),
          value: `${this.state.readAwaitMs.toFixed(1)} / ${this.state.writeAwaitMs.toFixed(1)} ms`
        })
      }

      ForEach(this.state.filesystems, (filesystem: FilesystemMetric) => {
        FilesystemSection({ filesystem: filesystem })
      }, (filesystem: FilesystemMetric) => filesystem.name)
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.card_border') })
    .borderRadius(16)
  }
}
