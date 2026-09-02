import { DashboardController } from '../controller/DashboardController'
import { SystemSummary } from '../model/BeszelModels'
import {
  AppColorMode,
  ChartLineOpacity,
  ChartLineWidth,
  CpuChartHeight,
  MetricChartHeight,
  MetricInspectionSort,
  PAGE_CONTENT_BOTTOM_PADDING
} from '../model/AppearanceModels'
import { MetricChartRange } from '../model/MetricChartModels'
import { MetricChartKind, MetricChartPanelKind } from '../model/MetricChartSource'
import { SettingsView } from './SettingsView'
import { SmartDetailsView } from './SmartDetailsView'
import { SystemCard } from './SystemCard'
import { SystemDetail } from './SystemDetail'
import { MetricChartsView } from './MetricChartsView'

const DETAIL_SWITCH_OFFSET_VP = 32
const DETAIL_SWITCH_EXIT_MS = 80
const DETAIL_SWITCH_ENTER_MS = 140
const DETAIL_SWITCH_SWAP_DELAY_MS = 16

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
  @State private detailOffsetY: number = 0
  @State private detailOpacity: number = 1
  private pathStack: NavPathStack = new NavPathStack()
  private detailSwitchSequence: number = 0

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
      } else if (name === 'metricCharts') {
        MetricChartsView({
          state: this.controller.metricChartsState,
          compact: !this.expanded,
          colorMode: this.controller.colorMode,
          metricChartHeight: this.controller.metricChartHeight,
          metricInspectionSort: this.controller.metricInspectionSort,
          chartLineWidth: this.controller.chartLineWidth,
          chartLineOpacity: this.controller.chartLineOpacity,
          onBack: () => {
            this.controller.closeMetricCharts()
            this.pathStack.pop()
          },
          onRangeChange: (kind: MetricChartPanelKind, range: MetricChartRange) =>
            this.controller.setMetricChartRange(kind, range),
          onStackedChange: (kind: MetricChartPanelKind, stacked: boolean) =>
            this.controller.setMetricChartStacked(kind, stacked),
          onSelectionCommit: (kind: MetricChartPanelKind, selectedKeys: string[]) =>
            this.controller.saveMetricChartSelection(kind, selectedKeys),
          onScrollingChange: (scrolling: boolean) => this.controller.setChartsScrolling(scrolling)
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
          metricChartHeight: this.controller.metricChartHeight,
          metricInspectionSort: this.controller.metricInspectionSort,
          chartLineWidth: this.controller.chartLineWidth,
          chartLineOpacity: this.controller.chartLineOpacity,
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
          },
          onMetricChartHeightChange: (height: MetricChartHeight) => {
            this.controller.updateMetricChartHeight(height)
          },
          onMetricInspectionSortChange: (sort: MetricInspectionSort) => {
            this.controller.updateMetricInspectionSort(sort)
          },
          onChartLineWidthChange: (width: ChartLineWidth) => {
            this.controller.updateChartLineWidth(width)
          },
          onChartLineOpacityChange: (opacity: ChartLineOpacity) => {
            this.controller.updateChartLineOpacity(opacity)
          }
        })
      }
    }
      .hideTitleBar(true)
      .backgroundColor($r('app.color.background'))
      .onShown(() => {
        this.syncDetailVisibility()
        if (name === 'metricCharts') this.controller.setMetricChartsVisible(true)
      })
      .onHidden(() => {
        if (name === 'metricCharts') {
          this.controller.setMetricChartsVisible(false)
          if (!this.pathStack.getAllPathName().includes('metricCharts')) {
            this.controller.closeMetricCharts()
          }
        }
        this.syncDetailVisibility()
        if (name === 'settings') {
          this.ensureDetailForSplit()
        }
      })
  }

  @Builder
  private detailDestination(param: Object) {
    Column() {
      Column() {
        if (this.detailSystem(param) !== null) {
          SystemDetail({
            detail: this.controller.detailState,
            systemName: this.detailSystemName(param),
            host: this.detailSystemHost(param),
            status: this.detailSystemStatus(param),
            agentVersion: this.detailSystemAgentVersion(param),
            compact: !this.expanded,
            liveSampling: this.controller.liveMetrics && this.controller.realtimeConnected,
            cpuChartHeight: this.controller.cpuChartHeight,
            colorMode: this.controller.colorMode,
            chartLineWidth: this.controller.chartLineWidth,
            chartLineOpacity: this.controller.chartLineOpacity,
            onBack: () => this.pathStack.pop(),
            onScrollingChange: (scrolling: boolean) => this.controller.setDetailScrolling(scrolling),
            onOpenSmartDetails: () => this.openSmartDetails(),
            onOpenHealthCharts: () => this.openMetricCharts(MetricChartKind.HEALTH),
            onOpenCpuCharts: () => this.openMetricCharts(MetricChartKind.CPU),
            onOpenMemoryCharts: () => this.openMetricCharts(MetricChartKind.MEMORY),
            onOpenStorageCharts: () => this.openMetricCharts(MetricChartKind.STORAGE),
            onOpenNetworkCharts: () => this.openMetricCharts(MetricChartKind.NETWORK),
            onOpenGpuCharts: () => this.openMetricCharts(MetricChartKind.GPU)
          })
        }
      }
      .width('100%')
      .height('100%')
      .opacity(this.detailOpacity)
      .translate({ y: this.detailOffsetY })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
    .clip(true)
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
        .backgroundColor(this.controller.liveSamplingActive() ?
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
    .padding({ left: 14, right: 14, top: 12, bottom: PAGE_CONTENT_BOTTOM_PADDING })
  }

  private selectSystem(id: string): void {
    if (id === this.controller.selectedId && this.topDestinationName() === 'detail') {
      this.cancelDetailSwitchAnimation()
      return
    }
    if (this.expanded) {
      if (this.topDestinationName() === 'detail') {
        this.animateDetailSwitch(id)
        return
      }
      this.cancelDetailSwitchAnimation()
      this.controller.closeMetricCharts()
      this.controller.selectSystem(id)
      this.pathStack.clear(false)
      this.pathStack.pushPath({ name: 'detail', param: new DashboardDestinationParam(id) })
    } else {
      this.cancelDetailSwitchAnimation()
      this.controller.selectSystem(id)
      this.pathStack.pushPath({ name: 'detail', param: new DashboardDestinationParam(id) })
    }
  }

  private animateDetailSwitch(id: string): void {
    const sequence = ++this.detailSwitchSequence
    const direction = this.detailSwitchDirection(id)
    this.getUIContext().animateTo({
      duration: DETAIL_SWITCH_EXIT_MS,
      curve: Curve.EaseIn,
      onFinish: () => {
        if (sequence !== this.detailSwitchSequence) {
          return
        }
        this.controller.selectSystem(id)
        this.detailOffsetY = DETAIL_SWITCH_OFFSET_VP * direction
        this.detailOpacity = 0
        setTimeout(() => {
          if (sequence !== this.detailSwitchSequence) {
            return
          }
          this.getUIContext().animateTo({
            duration: DETAIL_SWITCH_ENTER_MS,
            curve: Curve.EaseOut
          }, () => {
            this.detailOffsetY = 0
            this.detailOpacity = 1
          })
        }, DETAIL_SWITCH_SWAP_DELAY_MS)
      }
    }, () => {
      this.detailOffsetY = -DETAIL_SWITCH_OFFSET_VP * direction
      this.detailOpacity = 0
    })
  }

  private detailSwitchDirection(id: string): number {
    const currentIndex = this.controller.systems.findIndex(
      (system: SystemSummary) => system.id === this.controller.selectedId)
    const nextIndex = this.controller.systems.findIndex((system: SystemSummary) => system.id === id)
    return currentIndex >= 0 && nextIndex >= 0 && nextIndex < currentIndex ? -1 : 1
  }

  private cancelDetailSwitchAnimation(): void {
    this.detailSwitchSequence += 1
    this.detailOffsetY = 0
    this.detailOpacity = 1
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

  private openMetricCharts(kind: MetricChartKind): void {
    if (this.topDestinationName() === 'metricCharts') return
    this.controller.openMetricCharts(kind)
    this.pathStack.pushPath({
      name: 'metricCharts',
      param: new DashboardDestinationParam(this.controller.selectedId)
    })
  }

  private detailSystem(param: Object): SystemSummary | null {
    const destinationId = (param as DashboardDestinationParam).systemId
    const requestedId = this.expanded ? this.controller.selectedId : destinationId
    const requested = this.controller.systems.find((system: SystemSummary) => system.id === requestedId)
    if (requested !== undefined) {
      return requested
    }
    const selected = this.controller.systems.find(
      (system: SystemSummary) => system.id === this.controller.selectedId)
    return selected ?? null
  }

  private detailSystemName(param: Object): string {
    return this.detailSystem(param)?.name ?? ''
  }

  private detailSystemHost(param: Object): string {
    return this.detailSystem(param)?.host ?? ''
  }

  private detailSystemStatus(param: Object): string {
    return this.detailSystem(param)?.status ?? 'unknown'
  }

  private detailSystemAgentVersion(param: Object): string {
    return this.detailSystem(param)?.agentVersion ?? ''
  }

  private topDestinationName(): string {
    const pathNames = this.pathStack.getAllPathName()
    return pathNames.length > 0 ? pathNames[pathNames.length - 1] : ''
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
