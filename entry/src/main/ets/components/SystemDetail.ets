import { SystemSummary } from '../model/BeszelModels'

@Component
export struct SystemDetail {
  @Prop system: SystemSummary = new SystemSummary()
  @Prop compact: boolean = false

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Row({ space: 12 }) {
          Row()
            .width(11)
            .height(11)
            .borderRadius(6)
            .backgroundColor(this.system.isUp() ? $r('app.color.status_up') : $r('app.color.status_down'))
          Column({ space: 3 }) {
            Text(this.system.name)
              .fontSize(this.compact ? 24 : 28)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.system.host.length > 0 ? this.system.host : 'No host label')
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Text(this.system.status.toUpperCase())
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.system.isUp() ? $r('app.color.action') : $r('app.color.status_down_text'))
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor(this.system.isUp() ?
              $r('app.color.action_surface') : $r('app.color.status_down_surface'))
            .borderRadius(8)
        }
        .width('100%')

        if (this.compact) {
          Column({ space: 12 }) {
            Row({ space: 12 }) {
              this.metricTile('CPU', this.system.cpuPercent, '%')
              this.metricTile('Memory', this.system.memoryPercent, '%')
            }
            .width('100%')
            Row({ space: 12 }) {
              this.metricTile('Disk', this.system.diskPercent, '%')
              this.metricTile('GPU', this.system.gpuPercent, '%')
            }
            .width('100%')
          }
          .width('100%')
        } else {
          Row({ space: 12 }) {
            this.metricTile('CPU', this.system.cpuPercent, '%')
            this.metricTile('Memory', this.system.memoryPercent, '%')
            this.metricTile('Disk', this.system.diskPercent, '%')
            this.metricTile('GPU', this.system.gpuPercent, '%')
          }
          .width('100%')
        }

        Column({ space: 14 }) {
          Text('Resource pressure')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
          this.pressureBar('CPU', this.system.cpuPercent, $r('app.color.metric_cpu'))
          this.pressureBar('Memory', this.system.memoryPercent, $r('app.color.metric_memory'))
          this.pressureBar('Disk', this.system.diskPercent, $r('app.color.metric_disk'))
        }
        .width('100%')
        .padding(18)
        .backgroundColor($r('app.color.surface'))
        .borderRadius(16)

        if (this.compact) {
          Column({ space: 18 }) {
            this.loadAverage()
            Divider()
              .color($r('app.color.divider'))
            this.temperature()
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(18)
          .backgroundColor($r('app.color.surface'))
          .borderRadius(16)
        } else {
          Row({ space: 12 }) {
            Row() {
              this.loadAverage()
            }
            .layoutWeight(1)

            Row() {
              this.temperature()
            }
            .layoutWeight(1)
          }
          .width('100%')
          .padding(18)
          .backgroundColor($r('app.color.surface'))
          .borderRadius(16)
        }
      }
      .width('100%')
      .padding({
        left: this.compact ? 16 : 22,
        right: this.compact ? 16 : 22,
        top: this.compact ? 14 : 20,
        bottom: 30
      })
    }
    .layoutWeight(1)
    .height('100%')
    .scrollBar(BarState.Off)
  }

  @Builder
  private metricTile(label: string, value: number, suffix: string) {
    Column({ space: 8 }) {
      Text(label.toUpperCase())
        .fontSize(11)
        .fontColor($r('app.color.text_tertiary'))
      Text(`${value.toFixed(0)}${suffix}`)
        .fontSize(23)
        .fontWeight(FontWeight.Medium)
        .fontColor(value >= 90 ? $r('app.color.error') : $r('app.color.text_primary'))
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
    .padding(16)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(15)
  }

  @Builder
  private pressureBar(label: string, value: number, color: ResourceColor) {
    Column({ space: 6 }) {
      Row() {
        Text(label)
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .layoutWeight(1)
        Text(`${value.toFixed(0)}%`)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
      }
      Progress({ value: Math.min(value, 100), total: 100, type: ProgressType.Linear })
        .width('100%')
        .height(7)
        .color(value >= 90 ? $r('app.color.metric_danger') : color)
        .backgroundColor($r('app.color.progress_track'))
        .borderRadius(4)
    }
    .width('100%')
  }

  @Builder
  private loadAverage() {
    Column({ space: 8 }) {
      Text('LOAD AVERAGE')
        .fontSize(11)
        .fontColor($r('app.color.text_tertiary'))
      Text(`${this.system.loadOne.toFixed(2)}  ${this.system.loadFive.toFixed(2)}  ${this.system.loadFifteen.toFixed(2)}`)
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      Text('1m       5m       15m')
        .fontSize(11)
        .fontColor($r('app.color.text_tertiary'))
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  private temperature() {
    Column({ space: 8 }) {
      Text('TEMPERATURE')
        .fontSize(11)
        .fontColor($r('app.color.text_tertiary'))
      Text(this.system.temperatureCelsius > 0 ? `${this.system.temperatureCelsius.toFixed(0)} °C` : '—')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      Text(`Uptime ${this.formatUptime(this.system.uptimeSeconds)}`)
        .fontSize(11)
        .fontColor($r('app.color.text_tertiary'))
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  private formatUptime(seconds: number): string {
    if (seconds <= 0) {
      return '—'
    }
    const days = Math.floor(seconds / 86400)
    if (days > 0) {
      return `${days}d`
    }
    return `${Math.max(1, Math.floor(seconds / 3600))}h`
  }
}
