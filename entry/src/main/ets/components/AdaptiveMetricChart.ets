import { AppColorMode } from '../model/AppearanceModels'
import {
  AdaptiveMetricChartState,
  MetricChartAxisPolicy,
  MetricChartPoint,
  MetricChartRange,
  MetricChartSeries,
  MetricChartValueFormat
} from '../model/MetricChartModels'

const PLOT_INSET = 6
const Y_LABEL_WIDTH = 38

class MetricChartBounds {
  minimum: number = 0
  maximum: number = 1
  step: number = 0.25
}

@Component
export struct AdaptiveMetricChart {
  @ObjectLink @Watch('onChartStateChanged') state: AdaptiveMetricChartState
  @Prop @Watch('onColorModeChanged') colorMode: AppColorMode = AppColorMode.SYSTEM
  @Prop chartHeight: number = 230
  @Prop loading: boolean = false
  @Prop showNoData: boolean = true
  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  private ready: boolean = false
  private drawnRevision: number = -1
  private cachedBoundsRevision: number = -1
  private cachedBounds: MetricChartBounds = new MetricChartBounds()

  build() {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        Stack({ alignContent: Alignment.TopEnd }) {
          Text(this.yLabel(this.bounds().maximum))
            .fontSize(9)
            .fontColor($r('app.color.text_tertiary'))
            .width(Y_LABEL_WIDTH - 4)
            .textAlign(TextAlign.End)
            .position({ x: 0, y: PLOT_INSET })
            .markAnchor({ x: 0, y: '50%' })
          Text(this.yLabel((this.bounds().minimum + this.bounds().maximum) / 2))
            .fontSize(9)
            .fontColor($r('app.color.text_tertiary'))
            .width(Y_LABEL_WIDTH - 4)
            .textAlign(TextAlign.End)
            .position({ x: 0, y: this.chartHeight / 2 })
            .markAnchor({ x: 0, y: '50%' })
          Text(this.yLabel(this.bounds().minimum))
            .fontSize(9)
            .fontColor($r('app.color.text_tertiary'))
            .width(Y_LABEL_WIDTH - 4)
            .textAlign(TextAlign.End)
            .position({ x: 0, y: this.chartHeight - PLOT_INSET })
            .markAnchor({ x: 0, y: '50%' })
        }
        .width(Y_LABEL_WIDTH)
        .height(this.chartHeight)

        Column({ space: 4 }) {
          Stack({ alignContent: Alignment.Center }) {
            Canvas(this.context)
              .width('100%')
              .height(this.chartHeight)
              .backgroundColor($r('app.color.surface_input'))
              .borderRadius(4)
              .onReady(() => {
                this.ready = true
                this.drawnRevision = this.state.revision
                this.draw()
              })
              .onAreaChange(() => this.draw())

            if (this.loading) {
              Column({ space: 7 }) {
                LoadingProgress()
                  .width(24)
                  .height(24)
                  .color($r('app.color.action'))
                Text($r('app.string.chart_loading_history'))
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
              }
            } else if (this.state.selectedCount() === 0) {
              Text($r('app.string.chart_select_metric_hint'))
                .fontSize(12)
                .fontColor($r('app.color.text_tertiary'))
            } else if (this.showNoData && !this.state.hasSelectedData()) {
              Text($r('app.string.chart_no_data'))
                .fontSize(12)
                .fontColor($r('app.color.text_tertiary'))
            }
          }
          .width('100%')
          .height(this.chartHeight)

          Row() {
            Text(this.xLabel(this.state.windowStartMs))
              .fontSize(9)
              .fontColor($r('app.color.text_tertiary'))
              .layoutWeight(1)
              .textAlign(TextAlign.Start)
            Text(this.xLabel((this.state.windowStartMs + this.state.windowEndMs) / 2))
              .fontSize(9)
              .fontColor($r('app.color.text_tertiary'))
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
            Text(this.xLabel(this.state.windowEndMs))
              .fontSize(9)
              .fontColor($r('app.color.text_tertiary'))
              .layoutWeight(1)
              .textAlign(TextAlign.End)
          }
          .width('100%')
          .padding({ left: 4, right: 4 })
        }
        .layoutWeight(1)
      }
      .alignItems(VerticalAlign.Top)
      .width('100%')

      if (this.selectedSeries().length > 0) {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start, alignItems: ItemAlign.Center }) {
          ForEach(this.selectedSeries(), (series: MetricChartSeries) => {
            Row({ space: 5 }) {
              Row()
                .width(8)
                .height(8)
                .borderRadius(4)
                .backgroundColor(this.seriesResourceColor(series.key))
              Text(series.label)
                .fontSize(10)
                .fontColor($r('app.color.text_secondary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .margin({ right: 12, bottom: 5 })
          }, (series: MetricChartSeries) => series.key)
        }
        .width('100%')
        .padding({ left: Y_LABEL_WIDTH + 6 })
      }
    }
    .width('100%')
  }

  private onChartStateChanged(): void {
    if (!this.ready || this.drawnRevision === this.state.revision) return
    this.drawnRevision = this.state.revision
    this.draw()
  }

  private onColorModeChanged(): void {
    if (this.ready) this.draw()
  }

  private selectedSeries(): MetricChartSeries[] {
    return this.state.series.filter((series: MetricChartSeries) => series.selected)
  }

  private selectedIndices(): number[] {
    const indices: number[] = []
    this.state.series.forEach((series: MetricChartSeries, index: number) => {
      if (series.selected) indices.push(index)
    })
    return indices
  }

  private draw(): void {
    const width = this.context.width
    const height = this.context.height
    if (width <= 0 || height <= 0) return
    this.context.clearRect(0, 0, width, height)
    this.drawGrid(width, height)
    const indices = this.selectedIndices()
    const bounds = this.bounds()
    if (indices.length === 1) this.drawFill(indices[0], width, height, bounds)
    indices.forEach((seriesIndex: number) => this.drawLine(seriesIndex, width, height, bounds))
  }

  private drawGrid(width: number, height: number): void {
    const plotHeight = Math.max(1, height - PLOT_INSET * 2)
    this.context.beginPath()
    for (let grid = 0; grid <= 4; grid += 1) {
      const y = PLOT_INSET + grid * plotHeight / 4 + 0.5
      this.context.moveTo(PLOT_INSET, y)
      this.context.lineTo(width - PLOT_INSET, y)
    }
    this.context.strokeStyle = this.resolveColor($r('app.color.divider'), 0xFFE2E8E3)
    this.context.lineWidth = 1
    this.context.stroke()
  }

  private drawLine(seriesIndex: number, width: number, height: number, bounds: MetricChartBounds): void {
    const color = this.seriesColor(this.state.series[seriesIndex].key)
    const gapThreshold = this.state.expectedIntervalMs * 1.5
    let drawing = false
    let validCount = 0
    let lastTimestamp = 0
    this.context.beginPath()
    this.state.points.forEach((point: MetricChartPoint) => {
      const value = point.values[seriesIndex]
      if (!Number.isFinite(value)) {
        drawing = false
        return
      }
      const x = this.xPosition(point.timestampMs, width)
      const y = this.yPosition(value, height, bounds)
      if (!drawing || lastTimestamp === 0 || point.timestampMs - lastTimestamp > gapThreshold) {
        this.context.moveTo(x, y)
      } else {
        this.context.lineTo(x, y)
      }
      drawing = true
      validCount += 1
      lastTimestamp = point.timestampMs
    })
    this.context.strokeStyle = color
    this.context.lineWidth = 2
    this.context.lineJoin = 'round'
    this.context.lineCap = 'round'
    this.context.stroke()

    if (validCount === 1) {
      const point = this.state.points.find((candidate: MetricChartPoint) =>
        Number.isFinite(candidate.values[seriesIndex]))
      if (point !== undefined) {
        this.context.beginPath()
        this.context.arc(this.xPosition(point.timestampMs, width),
          this.yPosition(point.values[seriesIndex], height, bounds), 2, 0, Math.PI * 2)
        this.context.fillStyle = color
        this.context.fill()
      }
    }
  }

  private drawFill(seriesIndex: number, width: number, height: number, bounds: MetricChartBounds): void {
    const bottom = height - PLOT_INSET
    const gapThreshold = this.state.expectedIntervalMs * 1.5
    let segmentStart = -1
    for (let index = 0; index <= this.state.points.length; index += 1) {
      const point = index < this.state.points.length ? this.state.points[index] : undefined
      const value = point?.values[seriesIndex]
      const previous = index > 0 ? this.state.points[index - 1] : undefined
      const gap = point !== undefined && previous !== undefined &&
        point.timestampMs - previous.timestampMs > gapThreshold
      if (point !== undefined && Number.isFinite(value) && !gap) {
        if (segmentStart < 0) segmentStart = index
        continue
      }
      if (segmentStart >= 0 && index - segmentStart > 1) {
        this.fillSegment(seriesIndex, segmentStart, index - 1, width, bottom, bounds)
      }
      segmentStart = point !== undefined && Number.isFinite(value) ? index : -1
    }
  }

  private fillSegment(seriesIndex: number, start: number, end: number, width: number,
    bottom: number, bounds: MetricChartBounds): void {
    const first = this.state.points[start]
    const last = this.state.points[end]
    this.context.beginPath()
    this.context.moveTo(this.xPosition(first.timestampMs, width), bottom)
    for (let index = start; index <= end; index += 1) {
      const point = this.state.points[index]
      this.context.lineTo(this.xPosition(point.timestampMs, width),
        this.yPosition(point.values[seriesIndex], this.chartHeight, bounds))
    }
    this.context.lineTo(this.xPosition(last.timestampMs, width), bottom)
    this.context.closePath()
    this.context.save()
    this.context.globalAlpha = 0.18
    this.context.fillStyle = this.seriesColor(this.state.series[seriesIndex].key)
    this.context.fill()
    this.context.restore()
  }

  private xPosition(timestampMs: number, width: number): number {
    const duration = Math.max(1, this.state.windowEndMs - this.state.windowStartMs)
    const ratio = Math.max(0, Math.min(1, (timestampMs - this.state.windowStartMs) / duration))
    return PLOT_INSET + ratio * Math.max(1, width - PLOT_INSET * 2)
  }

  private yPosition(value: number, height: number, bounds: MetricChartBounds): number {
    const range = Math.max(0.0001, bounds.maximum - bounds.minimum)
    const ratio = Math.max(0, Math.min(1, (value - bounds.minimum) / range))
    return height - PLOT_INSET - ratio * Math.max(1, height - PLOT_INSET * 2)
  }

  private bounds(): MetricChartBounds {
    if (this.cachedBoundsRevision !== this.state.revision) {
      this.cachedBounds = this.calculateBounds()
      this.cachedBoundsRevision = this.state.revision
    }
    return this.cachedBounds
  }

  private calculateBounds(): MetricChartBounds {
    const bounds = new MetricChartBounds()
    if (this.state.axisPolicy === MetricChartAxisPolicy.PERCENT) {
      bounds.minimum = 0
      bounds.maximum = 100
      bounds.step = 25
      return bounds
    }
    let minimum = Number.POSITIVE_INFINITY
    let maximum = Number.NEGATIVE_INFINITY
    const selected = this.selectedIndices()
    this.state.points.forEach((point: MetricChartPoint) => {
      selected.forEach((seriesIndex: number) => {
        const value = point.values[seriesIndex]
        if (Number.isFinite(value)) {
          minimum = Math.min(minimum, value)
          maximum = Math.max(maximum, value)
        }
      })
    })
    if (!Number.isFinite(minimum) || !Number.isFinite(maximum)) {
      bounds.minimum = 0
      bounds.maximum = 100
      bounds.step = 25
      return bounds
    }
    if (this.state.axisPolicy === MetricChartAxisPolicy.ZERO_BASED) minimum = 0
    if (minimum === maximum) {
      const padding = Math.max(1, Math.abs(minimum) * 0.1)
      minimum -= this.state.axisPolicy === MetricChartAxisPolicy.ZERO_BASED ? 0 : padding
      maximum += padding
    } else {
      const padding = (maximum - minimum) * 0.1
      if (this.state.axisPolicy !== MetricChartAxisPolicy.ZERO_BASED) minimum -= padding
      maximum += padding
    }
    const step = this.niceStep((maximum - minimum) / 4)
    bounds.minimum = this.state.axisPolicy === MetricChartAxisPolicy.ZERO_BASED ? 0 : Math.floor(minimum / step) * step
    bounds.maximum = Math.ceil(maximum / step) * step
    bounds.step = step
    if (bounds.maximum <= bounds.minimum) bounds.maximum = bounds.minimum + step * 4
    return bounds
  }

  private niceStep(value: number): number {
    if (!Number.isFinite(value) || value <= 0) return 1
    const exponent = Math.floor(Math.log(value) / Math.LN10)
    const power = Math.pow(10, exponent)
    const fraction = value / power
    if (fraction <= 1) return power
    if (fraction <= 2) return 2 * power
    if (fraction <= 5) return 5 * power
    return 10 * power
  }

  private yLabel(value: number): string {
    if (this.state.valueFormat === MetricChartValueFormat.BYTES) return this.byteLabel(value, false)
    if (this.state.valueFormat === MetricChartValueFormat.BYTES_PER_SECOND) return this.byteLabel(value, true)
    const step = this.bounds().step
    const digits = step < 1 ? 1 : 0
    return `${value.toFixed(digits)}${this.state.unit}`
  }

  private byteLabel(value: number, perSecond: boolean): string {
    const magnitude = Math.abs(value)
    let scale = 1
    let unit = 'B'
    if (magnitude >= 1024 * 1024 * 1024) {
      scale = 1024 * 1024 * 1024
      unit = 'GB'
    } else if (magnitude >= 1024 * 1024) {
      scale = 1024 * 1024
      unit = 'MB'
    } else if (magnitude >= 1024) {
      scale = 1024
      unit = 'KB'
    }
    const scaledStep = Math.abs(this.bounds().step) / scale
    const digits = scaledStep < 1 ? 1 : 0
    return `${(value / scale).toFixed(digits)}${unit}${perSecond ? '/s' : ''}`
  }

  private xLabel(timestampMs: number): string {
    if (!Number.isFinite(timestampMs) || timestampMs <= 0) return '—'
    const date = new Date(timestampMs)
    if (this.state.range === MetricChartRange.LIVE) {
      return `${this.twoDigits(date.getHours())}:${this.twoDigits(date.getMinutes())}:${this.twoDigits(date.getSeconds())}`
    }
    if (this.state.range === MetricChartRange.DAY_7 || this.state.range === MetricChartRange.DAY_30) {
      return `${date.getMonth() + 1}/${date.getDate()}`
    }
    return `${this.twoDigits(date.getHours())}:${this.twoDigits(date.getMinutes())}`
  }

  private twoDigits(value: number): string {
    return value < 10 ? `0${value}` : value.toString()
  }

  private seriesResourceColor(key: string): ResourceColor {
    switch (this.colorIndex(key)) {
      case 0: return $r('app.color.chart_series_1')
      case 1: return $r('app.color.chart_series_2')
      case 2: return $r('app.color.chart_series_3')
      case 3: return $r('app.color.chart_series_4')
      case 4: return $r('app.color.chart_series_5')
      default: return $r('app.color.chart_series_6')
    }
  }

  private seriesColor(key: string): number {
    const resource = this.seriesResourceColor(key) as Resource
    return this.resolveColor(resource, 0xFF267454)
  }

  private colorIndex(key: string): number {
    const index = this.selectedSeries().findIndex((series: MetricChartSeries) => series.key === key)
    return index >= 0 ? index : 0
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
