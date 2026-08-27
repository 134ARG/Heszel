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

@Component
export struct SystemDetail {
  @ObjectLink detail: SystemDetailState
  @Prop systemName: string = ''
  @Prop host: string = ''
  @Prop status: string = 'unknown'
  @Prop agentVersion: string = ''
  @Prop compact: boolean = false
  @Prop liveSampling: boolean = false
  onBack: () => void = () => {}
  onScrollingChange: (scrolling: boolean) => void = () => {}
  onOpenSmartDetails: () => void = () => {}

  build() {
    Column() {
      PageHeader({
        title: this.systemName,
        subtitle: this.host.length > 0 ? this.host : $r('app.string.no_host_label'),
        showSubtitle: true,
        showBack: this.compact,
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
            compact: this.compact,
            liveSampling: this.liveSampling
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
            HardwareCard({ detail: this.detail, agentVersion: this.agentVersion, compact: this.compact })
          }

          if (this.detail.layoutVersion >= 0 && this.compact) {
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
          left: this.compact ? 16 : 22,
          right: this.compact ? 16 : 22,
          top: 14,
          bottom: 30
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
  }

  @Builder
  private primaryDetailCards() {
    if (this.detail.memoryMetrics.isVisible()) {
      MemoryCard({ state: this.detail.memoryMetrics })
    }
    if (this.detail.storageMetrics.isVisible()) {
      StorageCard({ state: this.detail.storageMetrics })
    }
    if (this.detail.smartHealth.isVisible()) {
      SmartCard({
        state: this.detail.smartHealth,
        onViewDetails: () => this.onOpenSmartDetails()
      })
    }
    if (this.detail.healthMetrics.cardVisible()) {
      HealthCard({ state: this.detail.healthMetrics })
    }
  }

  @Builder
  private secondaryDetailCards() {
    if (this.detail.cpuMetrics.isVisible()) {
      CpuCard({ state: this.detail.cpuMetrics })
    }
    if (this.detail.networkMetrics.isVisible()) {
      NetworkCard({ state: this.detail.networkMetrics })
    }
    if (this.detail.gpuMetrics.isVisible()) {
      GpuCard({ state: this.detail.gpuMetrics })
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
