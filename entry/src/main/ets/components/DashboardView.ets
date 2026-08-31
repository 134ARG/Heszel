import { DashboardController } from '../controller/DashboardController'
import { SystemSummary } from '../model/BeszelModels'
import { AppColorMode, CpuChartHeight } from '../model/AppearanceModels'
import { SettingsView } from './SettingsView'
import { SmartDetailsView } from './SmartDetailsView'
import { SystemCard } from './SystemCard'
import { SystemDetail } from './SystemDetail'

class DashboardDestinationParam {
  systemId: string

  constructor(systemId: string = '') {
    this.systemId = systemId
  }
}

@Component
export struct DashboardView {
  // The controller is passed by reference so list items reach SystemCard as the
  // live @Observed instances; @Prop would deep-copy the array and freeze cards.
  @ObjectLink @Watch('onModelChanged') controller: DashboardController
  @Prop @Watch('onExpandedChanged') expanded: boolean = false
  @State private detailVisible: boolean = false
  private pathStack: NavPathStack = new NavPathStack()

  private onlineCount(): number {
    return this.controller.systems.filter((system: SystemSummary) => system.isUp()).length
  }

  build() {
    Column() {
      this.header()

      if (this.controller.dashboardError.length > 0) {
        Row({ space: 10 }) {
          Text(this.controller.dashboardError)
            .fontSize(13)
            .fontColor($r('app.color.error_text'))
            .layoutWeight(1)
          Text($r('app.string.retry'))
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.action'))
            .onClick(() => this.controller.refresh())
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 10, bottom: 10 })
        .backgroundColor($r('app.color.error_surface'))
      }

      Navigation(this.pathStack) {
        this.navigationRoot()
      }
        .mode(this.expanded ? NavigationMode.Split : NavigationMode.Stack)
        .navBarWidth(340)
        .hideTitleBar(true)
        .navDestination(this.destinationBuilder)
        .onNavigationModeChange((mode: NavigationMode) => {
          if (mode === NavigationMode.Split) {
            this.ensureDetailForSplit()
          }
        })
        .layoutWeight(1)
        .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }

  @Builder
  private navigationRoot() {
    if (this.controller.systems.length === 0) {
      Column({ space: 12 }) {
        Text(this.controller.refreshing ? $r('app.string.loading_systems') : $r('app.string.no_shared_systems'))
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text(this.controller.refreshing ? $r('app.string.connecting_hub') : $r('app.string.share_system_hint'))
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .padding(32)
    } else {
      this.systemList()
    }
  }

  @Builder
  private destinationBuilder(name: string, param: Object) {
    NavDestination() {
      if (name === 'detail') {
        this.detailDestination(param)
      } else if (name === 'smart') {
        SmartDetailsView({
          state: this.controller.detailState.smartHealth,
          compact: !this.expanded,
          onBack: () => {
            this.pathStack.pop()
          },
          onScrollingChange: (scrolling: boolean) => this.controller.setDetailScrolling(scrolling)
        })
      } else if (name === 'settings') {
        SettingsView({
          connectionMode: this.controller.savedConnectionMode,
          connectionLabel: this.controller.connectionLabel(),
          connectionDetail: this.controller.connectionDetail(),
          email: this.controller.session.email,
          expanded: this.expanded,
          errorMessage: this.controller.dashboardError,
          updateWhileScrolling: this.controller.updateWhileScrolling,
          colorMode: this.controller.colorMode,
          cpuChartHeight: this.controller.cpuChartHeight,
          onBack: () => {
            this.pathStack.pop()
          },
          onSignOut: () => {
            this.controller.signOut()
          },
          onGatewayKeyChange: (gatewayKey: string) => {
            this.controller.updateGatewayKey(gatewayKey)
          },
          onUpdateWhileScrollingChange: (enabled: boolean) => {
            this.controller.updateScrollingPreference(enabled)
          },
          onColorModeChange: (mode: AppColorMode) => {
            this.controller.updateColorMode(mode)
          },
          onCpuChartHeightChange: (height: CpuChartHeight) => {
            this.controller.updateCpuChartHeight(height)
          }
        })
      }
    }
      .hideTitleBar(true)
      .onShown(() => {
        this.syncDetailVisibility()
      })
      .onActive(() => {
        if (name === 'detail') {
          this.trimDetailHistory()
        }
      })
      .onHidden(() => {
        this.syncDetailVisibility()
        if (name === 'settings') {
          this.ensureDetailForSplit()
        }
      })
  }

  @Builder
  private detailDestination(param: Object) {
    Column() {
      ForEach(
        this.detailSystems(param),
        (system: SystemSummary) => {
          SystemDetail({
            detail: this.controller.detailState,
            systemName: system.name,
            host: system.host,
            status: system.status,
            agentVersion: system.agentVersion,
            compact: !this.expanded,
            liveSampling: this.controller.liveMetrics && this.controller.realtimeConnected,
            cpuChartHeight: this.controller.cpuChartHeight,
            colorMode: this.controller.colorMode,
            onBack: () => this.pathStack.pop(),
            onScrollingChange: (scrolling: boolean) => this.controller.setDetailScrolling(scrolling),
            onOpenSmartDetails: () => this.openSmartDetails()
          })
        },
        (system: SystemSummary) => system.id
      )
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private header() {
    Row({ space: 8 }) {
      this.titleBlock()
      this.liveControl()
      this.refreshButton()
      this.settingsButton()
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 18, bottom: 14 })
    .backgroundColor($r('app.color.surface_header'))
  }

  @Builder
  private titleBlock() {
    Column({ space: 2 }) {
      Text($r('app.string.app_name'))
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text($r('app.string.systems_online', this.onlineCount(), this.controller.systems.length))
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
        .backgroundColor(this.controller.liveMetrics && this.controller.realtimeConnected && this.detailVisible ?
          $r('app.color.status_up') : $r('app.color.text_tertiary'))
      Text($r('app.string.live'))
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
      Toggle({ type: ToggleType.Switch, isOn: this.controller.liveMetrics })
        .onChange((enabled: boolean) => this.controller.setLiveMetrics(enabled))
    }
  }

  @Builder
  private refreshButton() {
    Button() {
      if (this.controller.refreshing) {
        LoadingProgress()
          .width(18)
          .height(18)
          .color($r('app.color.action'))
      } else {
        SymbolGlyph($r('sys.symbol.arrow_clockwise'))
          .fontSize(20)
          .fontColor([$r('app.color.action')])
      }
    }
      .width(38)
      .height(36)
      .backgroundColor($r('app.color.action_surface'))
      .borderRadius(10)
      .enabled(!this.controller.refreshing)
      .accessibilityText($r('app.string.refresh'))
      .onClick(() => this.controller.refresh())
  }

  @Builder
  private settingsButton() {
    Button() {
      SymbolGlyph($r('sys.symbol.gearshape'))
        .fontSize(20)
        .fontColor([$r('app.color.neutral_action_text')])
    }
      .width(38)
      .height(36)
      .backgroundColor($r('app.color.surface_neutral'))
      .borderRadius(10)
      .accessibilityText($r('app.string.settings'))
      .onClick(() => this.openSettings())
  }

  @Builder
  private systemList() {
    Column({ space: 10 }) {
      if (this.controller.lastRefresh.length > 0) {
        Text($r('app.string.updated', this.controller.lastRefresh))
          .fontSize(11)
          .fontColor($r('app.color.text_tertiary'))
          .width('100%')
      }

      List({ space: 10 }) {
        ForEach(this.controller.systems, (system: SystemSummary) => {
          ListItem() {
            SystemCard({
              system: system,
              selected: this.expanded && system.id === this.controller.selectedId,
              onSelect: () => this.selectSystem(system.id)
            })
          }
        }, (system: SystemSummary) => system.id)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
  }

  private selectSystem(id: string): void {
    if (id === this.controller.selectedId && this.topDestinationName() === 'detail') {
      return
    }
    this.controller.selectSystem(id)
    if (this.expanded) {
      if (this.topDestinationName() === 'detail') {
        this.pathStack.pushPath({ name: 'detail', param: new DashboardDestinationParam(id) })
        return
      }
      this.pathStack.clear(false)
      this.pathStack.pushPath({ name: 'detail', param: new DashboardDestinationParam(id) })
    } else {
      this.pathStack.pushPath({ name: 'detail', param: new DashboardDestinationParam(id) })
    }
  }

  private openSettings(): void {
    if (this.topDestinationName() !== 'settings') {
      this.pathStack.pushPath({ name: 'settings', param: new DashboardDestinationParam() })
    }
  }

  private openSmartDetails(): void {
    if (this.controller.detailState.smartHealth.isVisible() && this.topDestinationName() !== 'smart') {
      this.pathStack.pushPath({ name: 'smart', param: new DashboardDestinationParam(this.controller.selectedId) })
    }
  }

  private detailSystems(param: Object): SystemSummary[] {
    const requestedId = (param as DashboardDestinationParam).systemId
    const requested = this.controller.systems.filter((system: SystemSummary) => system.id === requestedId)
    if (requested.length > 0) {
      return requested
    }
    return this.controller.systems.filter((system: SystemSummary) => system.id === this.controller.selectedId)
  }

  private topDestinationName(): string {
    const pathNames = this.pathStack.getAllPathName()
    return pathNames.length > 0 ? pathNames[pathNames.length - 1] : ''
  }

  private trimDetailHistory(): void {
    if (!this.expanded || this.topDestinationName() !== 'detail') {
      return
    }
    const pathNames = this.pathStack.getAllPathName()
    const staleIndexes: number[] = []
    for (let index = 0; index < pathNames.length - 1; index += 1) {
      if (pathNames[index] === 'detail') {
        staleIndexes.push(index)
      }
    }
    if (staleIndexes.length > 0) {
      this.pathStack.removeByIndexes(staleIndexes)
    }
  }

  private ensureDetailForSplit(): void {
    if (!this.expanded || this.controller.selectedId.length === 0 || this.pathStack.size() > 0) {
      return
    }
    this.pathStack.pushPath({
      name: 'detail',
      param: new DashboardDestinationParam(this.controller.selectedId)
    }, false)
  }

  private syncDetailVisibility(): void {
    const visible = this.topDestinationName() === 'detail'
    if (this.detailVisible === visible) {
      return
    }
    this.detailVisible = visible
    this.controller.setDetailVisible(visible)
  }

  // Fires on every controller write; both branches are cheap guards.
  private onModelChanged(): void {
    if (this.controller.systems.length === 0) {
      this.pathStack.removeByName('detail')
      this.syncDetailVisibility()
      return
    }
    this.ensureDetailForSplit()
  }

  private onExpandedChanged(): void {
    if (!this.expanded && this.topDestinationName() === 'detail' && this.controller.selectedId.length > 0) {
      this.pathStack.replacePath({
        name: 'detail',
        param: new DashboardDestinationParam(this.controller.selectedId)
      }, false)
      return
    }
    this.ensureDetailForSplit()
  }
}
