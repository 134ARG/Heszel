import { MetricTrendState } from '../model/SystemDetailModels'

const CHART_HEIGHT = 62

@Component
export struct CpuTrendChart {
  @ObjectLink trend: MetricTrendState
  @Prop @Watch('onRevisionChanged') revision: number = 0
  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  private ready: boolean = false

  build() {
    Column({ space: 2 }) {
      Canvas(this.context)
        .width('100%')
        .height(CHART_HEIGHT)
        .backgroundColor($r('app.color.surface_input'))
        .borderRadius(8)
        .onReady(() => {
          this.ready = true
          this.draw()
        })
        .onAreaChange(() => this.draw())

      Stack({ alignContent: Alignment.Start }) {
        Row() {
          this.samplePosition('40')
          this.samplePosition('20')
          this.samplePosition('0')
        }
        .width('100%')

        Text('60')
          .fontSize(9)
          .fontColor($r('app.color.text_tertiary'))
      }
      .width('100%')
      .padding({ left: 4, right: 4 })
    }
    .width('100%')
  }

  @Builder
  private samplePosition(label: string) {
    Text(label)
      .fontSize(9)
      .fontColor($r('app.color.text_tertiary'))
      .textAlign(TextAlign.End)
      .layoutWeight(1)
  }

  private onRevisionChanged(): void {
    if (this.ready) this.draw()
  }

  private draw(): void {
    const width = this.context.width
    const height = this.context.height
    if (width <= 0 || height <= 0) return
    this.context.clearRect(0, 0, width, height)
    this.drawGrid(width)

    const count = this.trend.samples.length
    if (count === 0) return
    const capacity = this.trend.capacity()
    const offset = capacity - count
    const plotWidth = Math.max(1, width - 8)
    const plotHeight = Math.max(1, height - 10)
    const color = this.resolveColor($r('app.color.metric_cpu'), 0xFF267454)
    if (count > 1) this.drawFill(height, count, capacity, offset, plotWidth, plotHeight, color)
    this.drawLine(height, count, capacity, offset, plotWidth, plotHeight, color)
  }

  private drawFill(height: number, count: number, capacity: number, offset: number,
    plotWidth: number, plotHeight: number, color: number): void {
    const bottom = height - 5
    const firstX = 4 + offset * plotWidth / (capacity - 1)
    const lastX = 4 + (offset + count - 1) * plotWidth / (capacity - 1)
    this.context.beginPath()
    this.context.moveTo(firstX, bottom)
    for (let index = 0; index < count; index += 1) {
      const x = 4 + (offset + index) * plotWidth / (capacity - 1)
      const y = bottom - this.trend.samples[index] * plotHeight / 100
      this.context.lineTo(x, y)
    }
    this.context.lineTo(lastX, bottom)
    this.context.closePath()
    this.context.save()
    this.context.globalAlpha = 0.30
    this.context.fillStyle = color
    this.context.fill()
    this.context.restore()
  }

  private drawLine(height: number, count: number, capacity: number, offset: number,
    plotWidth: number, plotHeight: number, color: number): void {
    this.context.beginPath()
    for (let index = 0; index < count; index += 1) {
      const x = 4 + (offset + index) * plotWidth / (capacity - 1)
      const y = height - 5 - this.trend.samples[index] * plotHeight / 100
      if (index === 0) this.context.moveTo(x, y)
      else this.context.lineTo(x, y)
    }
    if (count === 1) this.context.lineTo(4.1 + offset * plotWidth / (capacity - 1),
      height - 5 - this.trend.samples[0] * plotHeight / 100)
    this.context.strokeStyle = color
    this.context.lineWidth = 2
    this.context.stroke()
  }

  private drawGrid(width: number): void {
    this.context.beginPath()
    this.context.moveTo(4, 18)
    this.context.lineTo(width - 4, 18)
    this.context.moveTo(4, 31)
    this.context.lineTo(width - 4, 31)
    this.context.moveTo(4, 44)
    this.context.lineTo(width - 4, 44)
    this.context.strokeStyle = this.resolveColor($r('app.color.divider'), 0xFFE2E8E3)
    this.context.lineWidth = 1
    this.context.stroke()
  }

  private resolveColor(resource: Resource, fallback: number): number {
    const hostContext = this.getUIContext().getHostContext()
    if (hostContext === undefined) return fallback
    try {
      return hostContext.resourceManager.getColorSync(resource.id)
    } catch (_) {
      return fallback
    }
  }
}
