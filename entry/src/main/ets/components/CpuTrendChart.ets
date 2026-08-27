import { MetricTrendState } from '../model/SystemDetailModels'

const CHART_HEIGHT = 62
const PLOT_TOP = 5
const PLOT_BOTTOM_INSET = 5
const LABEL_COLUMN_WIDTH = 24

@Component
export struct CpuTrendChart {
  @ObjectLink trend: MetricTrendState
  @Prop @Watch('onRevisionChanged') revision: number = 0
  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  private ready: boolean = false

  build() {
    Row({ space: 6 }) {


      // Y anchors outside the canvas, vertically centered on the matching gridlines.
      Stack({ alignContent: Alignment.TopStart }) {
        Text('100%')
          .fontSize(9)
          .fontColor($r('app.color.text_tertiary'))
          .position({ x: 0, y: PLOT_TOP })
          .markAnchor({ x: 0, y: '50%' })
        Text('50%')
          .fontSize(9)
          .fontColor($r('app.color.text_tertiary'))
          .position({ x: 0, y: PLOT_TOP + (CHART_HEIGHT - PLOT_TOP - PLOT_BOTTOM_INSET) / 2 })
          .markAnchor({ x: 0, y: '50%' })
        Text('0%')
          .fontSize(9)
          .fontColor($r('app.color.text_tertiary'))
          .position({ x: 0, y: PLOT_TOP + (CHART_HEIGHT - PLOT_TOP - PLOT_BOTTOM_INSET) })
          .markAnchor({ x: 0, y: '50%' })
      }
      .width(LABEL_COLUMN_WIDTH)
      .height(CHART_HEIGHT)

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
      .layoutWeight(1)
    }
    .alignItems(VerticalAlign.Top)
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
    this.drawGrid(width, height)

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
    // Round joins keep steep sample-to-sample turns from growing miter needles,
    // and round caps keep a lone sample visible as a dot.
    this.context.strokeStyle = color
    this.context.lineWidth = 2
    this.context.lineJoin = 'round'
    this.context.lineCap = 'round'
    this.context.stroke()
  }

  private drawGrid(width: number, height: number): void {
    const plotHeight = Math.max(1, height - 10)
    this.context.beginPath()
    // Quarter lines from the 100% ceiling down to the 0% floor; the half-pixel
    // offset keeps 1px lines off the pixel boundary so they stay crisp.
    for (let grid = 0; grid <= 4; grid += 1) {
      const y = 5 + grid * plotHeight / 4 + 0.5
      this.context.moveTo(4, y)
      this.context.lineTo(width - 4, y)
    }
    this.context.strokeStyle = this.resolveColor($r('app.color.divider'), 0xFFE2E8E3)
    this.context.lineWidth = 1
    this.context.stroke()
  }

  // Anchoring the ceiling and midpoint is enough to read the even grid; a 0%
  // label would stack on the "0" (= now) x-axis label in the bottom-right corner.
  private drawScaleLabels(width: number): void {
    const plotHeight = Math.max(1, this.context.height - 10)
    this.context.font = '9px sans-serif'
    this.context.textAlign = 'right'
    this.context.textBaseline = 'middle'
    this.context.fillStyle = this.resolveColor($r('app.color.text_tertiary'), 0xFF7A857D)
    this.context.fillText('100%', width - 7, 5)
    this.context.fillText('50%', width - 7, 5 + plotHeight / 2)
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
