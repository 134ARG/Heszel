import {
  AppColorMode,
  ChartLineOpacity,
  ChartLineWidth,
  CpuChartHeight,
  PAGE_CONTENT_BOTTOM_PADDING
} from '../model/AppearanceModels'
import { SystemDetailState } from '../model/SystemDetailModels'
import { ContainersCard } from './ContainersCard'
import { CpuCard } from './CpuCard'
import { GpuCard } from './GpuCard'
import { HardwareCard } from './HardwareCard'
import { HealthCard } from './HealthCard'
import { MemoryCard } from './MemoryCard'
import { NetworkCard } from './NetworkCard'
import { StorageCard } from './StorageCard'
import { SystemOverview } from './SystemOverview'
import { SmartCard } from './SmartCard'
import { PageHeader, PageHeaderTone } from './PageHeader'

const DETAIL_COLUMNS_BREAKPOINT_VP = 500

@Component
export struct SystemDetail {
  @ObjectLink detail: SystemDetailState
  @Prop systemName: string = ''
  @Prop host: string = ''
  @Prop status: string = 'unknown'
  @Prop agentVersion: string = ''
  @Prop compact: boolean = false
  @Prop showBack: boolean = false
  @Prop liveSampling: boolean = false
  @Prop cpuChartHeight: CpuChartHeight = CpuChartHeight.DEFAULT
  @Prop colorMode: AppColorMode = AppColorMode.SYSTEM
  @Prop chartLineWidth: ChartLineWidth = ChartLineWidth.DEFAULT
  @Prop chartLineOpacity: ChartLineOpacity = ChartLineOpacity.DEFAULT
  @State private viewWidth: number = 0
  onBack: () => void = () => {}
  onScrollingChange: (scrolling: boolean) => void = () => {}
  onOpenSmartDetails: () => void = () => {}
  onOpenHealthCharts: () => void = () => {}
  onOpenCpuCharts: () => void = () => {}
  onOpenMemoryCharts: () => void = () => {}
  onOpenStorageCharts: () => void = () => {}
  onOpenNetworkCharts: () => void = () => {}
  onOpenGpuCharts: () => void = () => {}

  build() {
    Column() {
      PageHeader({
        title: this.systemName,
        subtitle: this.host.length > 0 ? this.host : $r('app.string.no_host_label'),
        showSubtitle: true,
        showBack: this.showBack,
        backLabel: $r('app.string.back_systems'),
        showBadge: true,
        badgeLabel: this.statusLabel(),
        badgeTone: this.headerTone(),
        onBack: () => this.onBack()
      })

      Scroll() {
        Column({ space: 18 }) {
          SystemOverview({
            metrics: this.detail.overview,
            health: this.detail.healthMetrics,
            gpu: this.detail.gpuMetrics,
            cpuTrend: this.detail.cpuTrend,
            compact: this.compactLayout(),
            liveSampling: this.liveSampling,
            cpuChartHeight: this.cpuChartHeight,
            colorMode: this.colorMode,
            chartLineWidth: this.chartLineWidth,
            chartLineOpacity: this.chartLineOpacity
          })

          if (this.detail.loading && !this.detail.loaded) {
            Row({ space: 10 }) {
              LoadingProgress()
                .width(20)
                .height(20)
                .color($r('app.color.action'))
              Text($r('app.string.loading_detailed_metrics'))
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.surface'))
            .border({ width: 1, color: $r('app.color.card_border') })
            .borderRadius(14)
          }

          if (this.detail.errorMessage.length > 0) {
            Text(this.detail.errorMessage)
              .fontSize(12)
              .fontColor($r('app.color.error_text'))
              .width('100%')
              .padding(14)
              .backgroundColor($r('app.color.error_surface'))
              .borderRadius(12)
          }

          if (this.detail.hardware.hasData()) {
            HardwareCard({ detail: this.detail, agentVersion: this.agentVersion, compact: this.compactLayout() })
          }

          if (this.detail.layoutVersion >= 0 && this.compactLayout()) {
            Column({ space: 14 }) {
              this.primaryDetailCards()
              this.secondaryDetailCards()
            }
            .width('100%')
          } else {
            Row({ space: 14 }) {
              Column({ space: 14 }) {
                this.primaryDetailCards()
              }
              .layoutWeight(1)

              Column({ space: 14 }) {
                this.secondaryDetailCards()
              }
              .layoutWeight(1)
            }
            .alignItems(VerticalAlign.Top)
            .width('100%')
          }
        }
        .width('100%')
        .padding({
          left: this.compactLayout() ? 16 : 22,
          right: this.compactLayout() ? 16 : 22,
          top: 14,
          bottom: PAGE_CONTENT_BOTTOM_PADDING
        })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .onScrollStart(() => this.onScrollingChange(true))
      .onScrollStop(() => this.onScrollingChange(false))
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      const width = this.areaLength(newValue.width)
      if (Math.abs(width - this.viewWidth) > 0.5) this.viewWidth = width
    })
  }

  private compactLayout(): boolean {
    return this.viewWidth > 0 ? this.viewWidth <= DETAIL_COLUMNS_BREAKPOINT_VP : this.compact
  }

  private areaLength(length: Length | undefined): number {
    if (typeof length === 'number') return length
    if (typeof length === 'string') {
      const parsed = Number.parseFloat(length)
      if (Number.isFinite(parsed)) return parsed
    }
    return 0
  }

  @Builder
  private primaryDetailCards() {
    if (this.detail.memoryMetrics.isVisible()) {
      MemoryCard({
        state: this.detail.memoryMetrics,
        onOpenHistory: () => this.onOpenMemoryCharts()
      })
    }
    if (this.detail.storageMetrics.isVisible()) {
      StorageCard({
        state: this.detail.storageMetrics,
        onOpenHistory: () => this.onOpenStorageCharts()
      })
    }
    if (this.detail.smartHealth.isVisible()) {
      SmartCard({
        state: this.detail.smartHealth,
        onViewDetails: () => this.onOpenSmartDetails()
      })
    }
    if (this.detail.healthMetrics.cardVisible()) {
      HealthCard({
        state: this.detail.healthMetrics,
        onOpenHistory: () => this.onOpenHealthCharts()
      })
    }
  }

  @Builder
  private secondaryDetailCards() {
    if (this.detail.cpuMetrics.isVisible()) {
      CpuCard({
        state: this.detail.cpuMetrics,
        onOpenHistory: () => this.onOpenCpuCharts()
      })
    }
    if (this.detail.networkMetrics.isVisible()) {
      NetworkCard({
        state: this.detail.networkMetrics,
        onOpenHistory: () => this.onOpenNetworkCharts()
      })
    }
    if (this.detail.gpuMetrics.isVisible()) {
      GpuCard({
        state: this.detail.gpuMetrics,
        onOpenHistory: () => this.onOpenGpuCharts()
      })
    }
    if (this.detail.containerMetrics.isVisible()) {
      ContainersCard({ state: this.detail.containerMetrics })
    }
  }

  private headerTone(): PageHeaderTone {
    if (this.status === 'up') return PageHeaderTone.Success
    if (this.status === 'down') return PageHeaderTone.Error
    return PageHeaderTone.Neutral
  }

  private statusLabel(): ResourceStr {
    if (this.status === 'up') {
      return $r('app.string.status_up')
    }
    if (this.status === 'down') {
      return $r('app.string.status_down')
    }
    return $r('app.string.status_unknown')
  }
}
