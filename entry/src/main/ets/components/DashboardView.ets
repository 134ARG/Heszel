import { SystemSummary } from '../model/BeszelModels'
import { SystemCard } from './SystemCard'
import { SystemDetail } from './SystemDetail'

@Component
export struct DashboardView {
  @Link systems: SystemSummary[]
  @Link selectedId: string
  @Prop loading: boolean = false
  @Prop errorMessage: string = ''
  @Prop lastRefresh: string = ''
  @Prop expanded: boolean = false
  @Link compactDetailVisible: boolean
  @Prop liveMetrics: boolean = false
  @Prop realtimeConnected: boolean = false
  onRefresh: () => void = () => {}
  onOpenSettings: () => void = () => {}
  onLiveMetricsChange: (enabled: boolean) => void = () => {}

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
            .fontColor($r('app.color.error_text'))
            .layoutWeight(1)
          Text('Retry')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.action'))
            .onClick(() => this.onRefresh())
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 10, bottom: 10 })
        .backgroundColor($r('app.color.error_surface'))
      }

      if (this.systems.length === 0) {
        Column({ space: 12 }) {
          Text(this.loading ? 'Loading systems…' : 'No shared systems')
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          Text(this.loading ? 'Connecting to your Beszel hub.' :
            'Share a system with this Beszel account, then refresh.')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
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
            .color($r('app.color.divider'))
          ForEach(
            this.systems.filter((system: SystemSummary) => system.id === this.selectedId),
            (system: SystemSummary) => {
              SystemDetail({ system: system, compact: false })
            },
            (system: SystemSummary) => system.id
          )
        }
        .layoutWeight(1)
        .width('100%')
      } else if (this.compactDetailVisible) {
        this.compactDetail()
      } else {
        this.systemList(false)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }

  @Builder
  private header() {
    if (this.expanded) {
      Row({ space: 12 }) {
        this.titleBlock()
        this.liveControl()
        this.refreshButton()
        this.settingsButton()
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 18, bottom: 14 })
      .backgroundColor($r('app.color.surface_header'))
    } else {
      Column({ space: 10 }) {
        Row({ space: 12 }) {
          this.titleBlock()
          this.settingsButton()
        }
        .width('100%')

        Row({ space: 12 }) {
          this.liveControl()
          Blank()
            .layoutWeight(1)
          this.refreshButton()
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 16, bottom: 12 })
      .backgroundColor($r('app.color.surface_header'))
    }
  }

  @Builder
  private titleBlock() {
    Column({ space: 2 }) {
      Text('Heszel')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text(`${this.onlineCount()} of ${this.systems.length} systems online`)
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
  }

  @Builder
  private liveControl() {
    Row({ space: 7 }) {
      Row()
        .width(7)
        .height(7)
        .borderRadius(4)
        .backgroundColor(this.liveMetrics && this.realtimeConnected &&
          (this.expanded || this.compactDetailVisible) ?
          $r('app.color.status_up') : $r('app.color.text_tertiary'))
      Text('Live')
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
      Toggle({ type: ToggleType.Switch, isOn: this.liveMetrics })
        .onChange((enabled: boolean) => this.onLiveMetricsChange(enabled))
    }
  }

  @Builder
  private refreshButton() {
    Button(this.loading ? '…' : 'Refresh')
      .height(36)
      .fontSize(13)
      .fontColor($r('app.color.action'))
      .backgroundColor($r('app.color.action_surface'))
      .borderRadius(10)
      .enabled(!this.loading)
      .onClick(() => this.onRefresh())
  }

  @Builder
  private settingsButton() {
    Button('Settings')
      .height(36)
      .fontSize(13)
      .fontColor($r('app.color.neutral_action_text'))
      .backgroundColor($r('app.color.surface_neutral'))
      .borderRadius(10)
      .onClick(() => this.onOpenSettings())
  }

  @Builder
  private systemList(showSelection: boolean) {
    Column({ space: 10 }) {
      if (this.lastRefresh.length > 0) {
        Text(`Updated ${this.lastRefresh}`)
          .fontSize(11)
          .fontColor($r('app.color.text_tertiary'))
          .width('100%')
      }

      List({ space: 10 }) {
        ForEach(this.systems, (system: SystemSummary) => {
          ListItem() {
            SystemCard({
              system: system,
              selected: showSelection && system.id === this.selectedId,
              onSelect: () => this.selectSystem(system.id)
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
  private compactDetail() {
    Column() {
      Row() {
        Button('‹  Systems')
          .height(38)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.action'))
          .backgroundColor($r('app.color.action_surface'))
          .borderRadius(10)
          .onClick(() => {
            this.compactDetailVisible = false
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 2 })

      ForEach(
        this.systems.filter((system: SystemSummary) => system.id === this.selectedId),
        (system: SystemSummary) => {
          SystemDetail({ system: system, compact: true })
        },
        (system: SystemSummary) => system.id
      )
    }
    .layoutWeight(1)
    .width('100%')
  }

  private selectSystem(id: string): void {
    this.selectedId = id
    if (!this.expanded) {
      this.compactDetailVisible = true
    }
  }
}
