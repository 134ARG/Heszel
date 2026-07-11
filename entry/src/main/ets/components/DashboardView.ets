import { SystemSummary } from '../model/BeszelModels'
import { SystemCard } from './SystemCard'
import { SystemDetail } from './SystemDetail'

@Component
export struct DashboardView {
  @Prop systems: SystemSummary[] = []
  @Link selectedId: string
  @Prop loading: boolean = false
  @Prop errorMessage: string = ''
  @Prop lastRefresh: string = ''
  @Prop expanded: boolean = false
  @State private compactDetailVisible: boolean = false
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
          SystemDetail({ system: this.selectedSystem(), compact: false })
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
          .fontColor('#176B45')
          .backgroundColor('#E4F3EA')
          .borderRadius(10)
          .onClick(() => {
            this.compactDetailVisible = false
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 2 })

      SystemDetail({ system: this.selectedSystem(), compact: true })
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
