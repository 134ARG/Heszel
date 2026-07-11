import { SystemSummary } from '../model/BeszelModels'
import { SystemCard } from './SystemCard'

@Component
export struct DashboardView {
  @Prop systems: SystemSummary[] = []
  @Prop selectedId: string = ''
  @Prop loading: boolean = false
  @Prop errorMessage: string = ''
  @Prop lastRefresh: string = ''
  @Prop expanded: boolean = false
  onSelect: (id: string) => void = () => {}
  onRefresh: () => void = () => {}
  onSignOut: () => void = () => {}

  private selectedSystem(): SystemSummary {
    const match = this.systems.find((system: SystemSummary) => system.id === this.selectedId)
    return match ?? new SystemSummary()
  }

  private onlineCount(): number {
    return this.systems.filter((system: SystemSummary) => system.isUp()).length
  }

  build() {
    Column() {
      this.header()

      if (this.errorMessage.length > 0) {
        Row({ space: 10 }) {
          Text(this.errorMessage)
            .fontSize(13)
            .fontColor('#8A201A')
            .layoutWeight(1)
          Text('Retry')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#176B45')
            .onClick(() => this.onRefresh())
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 10, bottom: 10 })
        .backgroundColor('#FFF0EE')
      }

      if (this.systems.length === 0) {
        Column({ space: 12 }) {
          Text(this.loading ? 'Loading systems…' : 'No shared systems')
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor('#27362D')
          Text(this.loading ? 'Connecting to your Beszel hub.' :
            'Share a system with this Beszel account, then refresh.')
            .fontSize(14)
            .fontColor('#718078')
            .textAlign(TextAlign.Center)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding(32)
      } else if (this.expanded) {
        Row() {
          this.systemList(true)
          Divider()
            .vertical(true)
            .width(1)
            .height('100%')
            .color('#E2E8E3')
          this.detail(this.selectedSystem())
        }
        .layoutWeight(1)
        .width('100%')
      } else {
        this.systemList(false)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F7F5')
  }

  @Builder
  private header() {
    Row({ space: 12 }) {
      Column({ space: 2 }) {
        Text('Heszel')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#17211B')
        Text(`${this.onlineCount()} of ${this.systems.length} systems online`)
          .fontSize(12)
          .fontColor('#6B786F')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Button(this.loading ? '…' : 'Refresh')
        .height(36)
        .fontSize(13)
        .fontColor('#176B45')
        .backgroundColor('#E4F3EA')
        .borderRadius(10)
        .enabled(!this.loading)
        .onClick(() => this.onRefresh())

      Button('Sign out')
        .height(36)
        .fontSize(13)
        .fontColor('#5B665F')
        .backgroundColor('#ECEFEC')
        .borderRadius(10)
        .onClick(() => this.onSignOut())
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 18, bottom: 14 })
    .backgroundColor('#FCFDFC')
  }

  @Builder
  private systemList(showSelection: boolean) {
    Column({ space: 10 }) {
      if (this.lastRefresh.length > 0) {
        Text(`Updated ${this.lastRefresh}`)
          .fontSize(11)
          .fontColor('#7C8880')
          .width('100%')
      }

      List({ space: 10 }) {
        ForEach(this.systems, (system: SystemSummary) => {
          ListItem() {
            SystemCard({
              system: system,
              selected: showSelection && system.id === this.selectedId,
              onSelect: () => this.onSelect(system.id)
            })
          }
        }, (system: SystemSummary) => system.id)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
    }
    .width(showSelection ? 340 : '100%')
    .height('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
  }

  @Builder
  private detail(system: SystemSummary) {
    Scroll() {
      Column({ space: 18 }) {
        Row({ space: 12 }) {
          Row()
            .width(11)
            .height(11)
            .borderRadius(6)
            .backgroundColor(system.isUp() ? '#20A465' : '#D8483E')
          Column({ space: 3 }) {
            Text(system.name)
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor('#17211B')
            Text(system.host.length > 0 ? system.host : 'No host label')
              .fontSize(13)
              .fontColor('#718078')
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Text(system.status.toUpperCase())
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(system.isUp() ? '#176B45' : '#A12D26')
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor(system.isUp() ? '#E4F3EA' : '#FFE9E6')
            .borderRadius(8)
        }
        .width('100%')

        Row({ space: 12 }) {
          this.metricTile('CPU', system.cpuPercent, '%')
          this.metricTile('Memory', system.memoryPercent, '%')
          this.metricTile('Disk', system.diskPercent, '%')
          this.metricTile('GPU', system.gpuPercent, '%')
        }
        .width('100%')

        Column({ space: 14 }) {
          Text('Resource pressure')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor('#26342B')
            .width('100%')
          this.pressureBar('CPU', system.cpuPercent, '#267454')
          this.pressureBar('Memory', system.memoryPercent, '#4673A7')
          this.pressureBar('Disk', system.diskPercent, '#9B6B2F')
        }
        .width('100%')
        .padding(18)
        .backgroundColor('#FFFFFF')
        .borderRadius(16)

        Row({ space: 12 }) {
          Column({ space: 8 }) {
            Text('LOAD AVERAGE')
              .fontSize(11)
              .fontColor('#748077')
            Text(`${system.loadOne.toFixed(2)}  ${system.loadFive.toFixed(2)}  ${system.loadFifteen.toFixed(2)}`)
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
              .fontColor('#26342B')
            Text('1m       5m       15m')
              .fontSize(11)
              .fontColor('#89928C')
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Column({ space: 8 }) {
            Text('TEMPERATURE')
              .fontSize(11)
              .fontColor('#748077')
            Text(system.temperatureCelsius > 0 ? `${system.temperatureCelsius.toFixed(0)} °C` : '—')
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
              .fontColor('#26342B')
            Text(`Uptime ${this.formatUptime(system.uptimeSeconds)}`)
              .fontSize(11)
              .fontColor('#89928C')
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .padding(18)
        .backgroundColor('#FFFFFF')
        .borderRadius(16)
      }
      .width('100%')
      .padding({ left: 22, right: 22, top: 20, bottom: 30 })
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
        .fontColor('#748077')
      Text(`${value.toFixed(0)}${suffix}`)
        .fontSize(23)
        .fontWeight(FontWeight.Medium)
        .fontColor(value >= 90 ? '#B3261E' : '#223128')
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(15)
  }

  @Builder
  private pressureBar(label: string, value: number, color: string) {
    Column({ space: 6 }) {
      Row() {
        Text(label)
          .fontSize(13)
          .fontColor('#526158')
          .layoutWeight(1)
        Text(`${value.toFixed(0)}%`)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#29372E')
      }
      Progress({ value: Math.min(value, 100), total: 100, type: ProgressType.Linear })
        .width('100%')
        .height(7)
        .color(value >= 90 ? '#C93C32' : color)
        .backgroundColor('#E8ECE8')
        .borderRadius(4)
    }
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
