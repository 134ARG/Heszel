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

@Component
export struct SystemDetail {
  @ObjectLink detail: SystemDetailState
  @Prop systemName: string = ''
  @Prop host: string = ''
  @Prop status: string = 'unknown'
  @Prop agentVersion: string = ''
  @Prop compact: boolean = false

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Row({ space: 12 }) {
          Row()
            .width(11)
            .height(11)
            .borderRadius(6)
            .backgroundColor(this.isUp() ? $r('app.color.status_up') : $r('app.color.status_down'))
          Column({ space: 3 }) {
            Text(this.systemName)
              .fontSize(this.compact ? 24 : 28)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.host.length > 0 ? this.host : 'No host label')
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Text(this.status.toUpperCase())
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.isUp() ? $r('app.color.action') : $r('app.color.status_down_text'))
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor(this.isUp() ?
              $r('app.color.action_surface') : $r('app.color.status_down_surface'))
            .borderRadius(8)
        }
        .width('100%')

        SystemOverview({ metrics: this.detail.overview, compact: this.compact })

        if (this.detail.loading && !this.detail.loaded) {
          Row({ space: 10 }) {
            LoadingProgress()
              .width(20)
              .height(20)
              .color($r('app.color.action'))
            Text('Loading detailed metrics…')
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.surface'))
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
        top: this.compact ? 14 : 20,
        bottom: 30
      })
    }
    .layoutWeight(1)
    .height('100%')
    .scrollBar(BarState.Off)
  }

  @Builder
  private primaryDetailCards() {
    if (this.detail.memoryMetrics.isVisible()) {
      MemoryCard({ state: this.detail.memoryMetrics })
    }
    if (this.detail.storageMetrics.isVisible()) {
      StorageCard({ state: this.detail.storageMetrics })
    }
  }

  @Builder
  private secondaryDetailCards() {
    if (this.detail.cpuMetrics.isVisible()) {
      CpuCard({ state: this.detail.cpuMetrics, compact: this.compact })
    }
    if (this.detail.networkMetrics.isVisible()) {
      NetworkCard({ state: this.detail.networkMetrics })
    }
    if (this.detail.gpuMetrics.isVisible()) {
      GpuCard({ state: this.detail.gpuMetrics })
    }
    if (this.detail.healthMetrics.isVisible()) {
      HealthCard({ state: this.detail.healthMetrics })
    }
    if (this.detail.containerMetrics.isVisible()) {
      ContainersCard({ state: this.detail.containerMetrics })
    }
  }

  private isUp(): boolean {
    return this.status === 'up'
  }
}
