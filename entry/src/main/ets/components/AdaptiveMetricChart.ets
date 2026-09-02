import {
  AppColorMode,
  ChartLineOpacity,
  ChartLineWidth,
  chartLineOpacityValue,
  chartLineWidthVp,
  MetricInspectionSort
} from '../model/AppearanceModels'
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
const INSPECTION_POPUP_WIDTH = 172
const INSPECTION_POPUP_WIDE_WIDTH = 348
const INSPECTION_POPUP_WIDE_THRESHOLD = 520
const INSPECTION_POPUP_MARGIN = 8
const INSPECTION_POPUP_ROW_HEIGHT = 18
const INSPECTION_POPUP_MAX_ROWS = 8
const INSPECTION_POPUP_CHROME_HEIGHT = 37
const INSPECTION_POPUP_SCROLLBAR_GUTTER = 8
class MetricChartBounds {
  minimum: number = 0
  maximum: number = 1
  step: number = 0.25
}

@Component
export struct AdaptiveMetricChart {
  @ObjectLink @Watch('onChartStateChanged') state: AdaptiveMetricChartState
  @Prop @Watch('onPaletteChanged') colorMode: AppColorMode = AppColorMode.SYSTEM
  @Prop @Watch('onPaletteChanged') primarySeriesColor: Resource = $r('app.color.chart_series_start')
  @Prop @Watch('onLineStyleChanged') chartLineWidth: ChartLineWidth = ChartLineWidth.DEFAULT
  @Prop @Watch('onLineStyleChanged') chartLineOpacity: ChartLineOpacity = ChartLineOpacity.DEFAULT
  @Prop @Watch('onInspectionDismissRequested') inspectionDismissToken: number = 0
  @Prop metricInspectionSort: MetricInspectionSort = MetricInspectionSort.VALUE
  @Prop chartHeight: number = 230
  @Prop loading: boolean = false
  @Prop showNoData: boolean = true
  @Prop showLegend: boolean = true
  onPlotAreaChange: (left: number, top: number, width: number, height: number) => void =
    (_left: number, _top: number, _width: number, _height: number) => {}
  @State private chartWidth: number = 0
  @State private inspectedTimestampMs: number = 0
  @State private inspectionPopupAtTop: boolean = true
  @State private inspectionRange: MetricChartRange = MetricChartRange.HOUR_1
  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  private ready: boolean = false
  private drawnRevision: number = -1
  private cachedBoundsRevision: number = -1
  private cachedBounds: MetricChartBounds = new MetricChartBounds()
  // Canvas colors are resolved once per color mode instead of per draw.
  private cachedColorMode: AppColorMode = AppColorMode.SYSTEM
  private cachedPaletteReady: boolean = false
  private cachedDividerColor: number = 0xFFE2E8E3
  private cachedSeriesStartColor: number = 0xFFD83B4B
  private cachedSeriesEndColor: number = 0xFF844BC5
  private cachedSeriesStartHsl: number[] = [0, 0, 0]
  private cachedSeriesEndHsl: number[] = [0, 0, 0]

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.chartContent()

      if (this.inspectionVisible()) {
        this.inspectionPopup()
      }
    }
    .width('100%')
  }

  @Builder
  private chartContent() {
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
        .onClick(() => this.clearInspection())

        Column({ space: 4 }) {
          Stack({ alignContent: Alignment.Center }) {
            Canvas(this.context)
              .width('100%')
              .height(this.chartHeight)
              .backgroundColor($r('app.color.surface_input'))
              .borderRadius(4)
              .onReady(() => {
                this.ready = true
                this.chartWidth = this.context.width
                this.drawnRevision = this.state.revision
                this.draw()
              })
              .onAreaChange((oldValue: Area, newValue: Area) => {
                const width = this.areaLength(newValue.width, this.context.width)
                this.chartWidth = width
                this.onPlotAreaChange(
                  this.areaLength(newValue.globalPosition.x, 0),
                  this.areaLength(newValue.globalPosition.y, 0),
                  width,
                  this.areaLength(newValue.height, this.chartHeight)
                )
                this.draw()
              })
              .onTouch((event: TouchEvent) => this.onChartTouch(event))

            if (this.inspectionVisible()) {
              Row()
                .width(1)
                .height(this.chartHeight - PLOT_INSET * 2)
                .backgroundColor($r('app.color.selected_border'))
                .opacity(0.9)
                .position({ x: this.inspectionLineX(), y: PLOT_INSET })
                .hitTestBehavior(HitTestMode.None)

              ForEach(this.selectedSeries(), (series: MetricChartSeries) => {
                if (Number.isFinite(this.inspectionSeriesValue(series.key))) {
                  Row()
                    .width(7)
                    .height(7)
                    .borderRadius(4)
                    .backgroundColor(this.seriesResourceColor(series.key))
                    .border({ width: 1, color: $r('app.color.surface') })
                    .position({
                      x: this.inspectionLineX() - 3,
                      y: this.inspectionMarkerY(series.key) - 3
                    })
                    .hitTestBehavior(HitTestMode.None)
                }
              }, (series: MetricChartSeries) => series.key)
            }

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
          .onClick(() => this.clearInspection())
        }
        .layoutWeight(1)
      }
      .alignItems(VerticalAlign.Top)
      .width('100%')

      if (this.showLegend && this.selectedSeries().length > 0) {
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
        .onClick(() => this.clearInspection())
      }
    }
    .width('100%')
  }

  private onChartStateChanged(): void {
    this.validateInspection()
    if (!this.ready || this.drawnRevision === this.state.revision) return
    this.drawnRevision = this.state.revision
    this.draw()
  }

  private onPaletteChanged(): void {
    this.cachedPaletteReady = false
    if (this.ready) this.draw()
  }

  private onLineStyleChanged(): void {
    if (this.ready) this.draw()
  }

  private onInspectionDismissRequested(): void {
    this.clearInspection()
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

  @Builder
  private inspectionPopup() {
    Column({ space: 5 }) {
      Text(this.inspectionTimestampLabel())
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      Grid() {
        ForEach(this.inspectionSeries(), (series: MetricChartSeries) => {
          GridItem() {
            Row({ space: 5 }) {
              Row()
                .width(7)
                .height(7)
                .borderRadius(4)
                .backgroundColor(this.seriesResourceColor(series.key))
              Text(series.label)
                .fontSize(10)
                .fontColor($r('app.color.text_secondary'))
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(this.inspectionValueLabel(series.key))
                .fontSize(10)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
                .maxLines(1)
            }
            .width('100%')
            .height(INSPECTION_POPUP_ROW_HEIGHT)
            .padding({ right: 4 })
          }
        }, (series: MetricChartSeries) => series.key)
      }
      .columnsTemplate(this.inspectionPopupColumns() === 2 ? '1fr 1fr' : '1fr')
      .columnsGap(10)
      .width('100%')
      .height(this.inspectionPopupBodyHeight())
      .padding({ right: this.inspectionPopupScrollable() ? INSPECTION_POPUP_SCROLLBAR_GUTTER : 0 })
      .scrollBar(this.inspectionPopupScrollable() ? BarState.On : BarState.Off)
      .clip(true)
    }
    .width(this.inspectionPopupWidth())
    .padding(10)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.selected_border') })
    .borderRadius(9)
    .position({ x: this.inspectionPopupX(), y: this.inspectionPopupY() })
  }

  private onChartTouch(event: TouchEvent): void {
    if (event.type === TouchType.Cancel) {
      this.clearInspection()
      return
    }
    if (event.type !== TouchType.Down && event.type !== TouchType.Move) return
    const touch = event.touches.length > 0 ? event.touches[0] :
      event.changedTouches.length > 0 ? event.changedTouches[0] : undefined
    if (touch === undefined || this.loading || this.state.selectedCount() === 0) return
    const width = this.effectiveChartWidth()
    if (width <= PLOT_INSET * 2) return
    const x = Math.max(PLOT_INSET, Math.min(width - PLOT_INSET, touch.x))
    const ratio = (x - PLOT_INSET) / Math.max(1, width - PLOT_INSET * 2)
    const targetTimestamp = this.state.windowStartMs +
      ratio * (this.state.windowEndMs - this.state.windowStartMs)
    const point = this.nearestInspectionPoint(targetTimestamp)
    if (point === null) {
      this.clearInspection()
      return
    }
    if (this.inspectedTimestampMs !== point.timestampMs) this.inspectedTimestampMs = point.timestampMs
    const popupAtTop = touch.y > this.chartHeight / 2
    if (this.inspectionPopupAtTop !== popupAtTop) this.inspectionPopupAtTop = popupAtTop
    this.inspectionRange = this.state.range
  }

  private nearestInspectionPoint(targetTimestamp: number): MetricChartPoint | null {
    const selected = this.selectedIndices()
    let nearest: MetricChartPoint | null = null
    let nearestDistance = Number.POSITIVE_INFINITY
    this.state.points.forEach((point: MetricChartPoint) => {
      const hasValue = selected.some((index: number) => Number.isFinite(point.values[index]))
      if (!hasValue) return
      const distance = Math.abs(point.timestampMs - targetTimestamp)
      if (distance < nearestDistance) {
        nearest = point
        nearestDistance = distance
      }
    })
    return nearest
  }

  private inspectionPoint(): MetricChartPoint | null {
    if (this.inspectedTimestampMs <= 0) return null
    return this.state.points.find((point: MetricChartPoint) =>
      point.timestampMs === this.inspectedTimestampMs) ?? null
  }

  private inspectionVisible(): boolean {
    if (this.loading || this.inspectionRange !== this.state.range) return false
    const point = this.inspectionPoint()
    if (point === null) return false
    return this.selectedIndices().some((index: number) => Number.isFinite(point.values[index]))
  }

  private validateInspection(): void {
    if (this.inspectedTimestampMs <= 0) return
    if (!this.inspectionVisible()) this.clearInspection()
  }

  private clearInspection(): void {
    if (this.inspectedTimestampMs !== 0) this.inspectedTimestampMs = 0
  }

  private inspectionSeriesValue(key: string): number {
    const point = this.inspectionPoint()
    const index = this.state.series.findIndex((series: MetricChartSeries) => series.key === key)
    if (point === null || index < 0 || index >= point.values.length) return Number.NaN
    return point.values[index]
  }

  private inspectionLineX(): number {
    return this.xPosition(this.inspectedTimestampMs, this.effectiveChartWidth())
  }

  private inspectionMarkerY(key: string): number {
    return this.yPosition(this.inspectionSeriesValue(key), this.chartHeight, this.bounds())
  }

  private inspectionSeries(): MetricChartSeries[] {
    const selected = this.selectedSeries()
    if (this.metricInspectionSort === MetricInspectionSort.LABEL) {
      return selected.sort((left: MetricChartSeries, right: MetricChartSeries) =>
        this.compareSeriesLabels(left, right))
    }
    const point = this.inspectionPoint()
    if (point === null) return selected
    const values = new Map<string, number>()
    this.state.series.forEach((series: MetricChartSeries, index: number) => {
      values.set(series.key, index < point.values.length ? point.values[index] : Number.NaN)
    })
    return selected.sort((left: MetricChartSeries, right: MetricChartSeries) => {
      const leftValue = values.get(left.key) ?? Number.NaN
      const rightValue = values.get(right.key) ?? Number.NaN
      const leftFinite = Number.isFinite(leftValue)
      const rightFinite = Number.isFinite(rightValue)
      if (leftFinite && rightFinite && leftValue !== rightValue) return rightValue - leftValue
      if (leftFinite !== rightFinite) return leftFinite ? -1 : 1
      return this.compareSeriesLabels(left, right)
    })
  }

  private compareSeriesLabels(left: MetricChartSeries, right: MetricChartSeries): number {
    return left.label.localeCompare(right.label, undefined, { numeric: true, sensitivity: 'base' })
  }

  private inspectionPopupColumns(): number {
    return this.effectiveChartWidth() >= INSPECTION_POPUP_WIDE_THRESHOLD ? 2 : 1
  }

  private inspectionPopupRows(): number {
    return Math.ceil(this.selectedSeries().length / this.inspectionPopupColumns())
  }

  private inspectionPopupBodyHeight(): number {
    return Math.min(INSPECTION_POPUP_MAX_ROWS, this.inspectionPopupRows()) * INSPECTION_POPUP_ROW_HEIGHT
  }

  private inspectionPopupScrollable(): boolean {
    return this.inspectionPopupRows() > INSPECTION_POPUP_MAX_ROWS
  }

  private inspectionPopupWidth(): number {
    return this.inspectionPopupColumns() === 2 ? INSPECTION_POPUP_WIDE_WIDTH : INSPECTION_POPUP_WIDTH
  }

  private inspectionPopupX(): number {
    const width = this.effectiveChartWidth()
    const popupWidth = this.inspectionPopupWidth()
    const lineX = this.inspectionLineX()
    const right = lineX + INSPECTION_POPUP_MARGIN
    const plotX = right + popupWidth <= width ?
      right : Math.max(0, lineX - popupWidth - INSPECTION_POPUP_MARGIN)
    return Y_LABEL_WIDTH + 6 + plotX
  }

  private inspectionPopupY(): number {
    const estimatedHeight = INSPECTION_POPUP_CHROME_HEIGHT + this.inspectionPopupBodyHeight()
    if (this.inspectionPopupAtTop) return INSPECTION_POPUP_MARGIN
    return Math.max(INSPECTION_POPUP_MARGIN,
      this.chartHeight - estimatedHeight - INSPECTION_POPUP_MARGIN)
  }

  private effectiveChartWidth(): number {
    return this.chartWidth > 0 ? this.chartWidth : this.context.width
  }

  private areaLength(length: Length | undefined, fallback: number): number {
    if (typeof length === 'number') return length
    if (typeof length === 'string') {
      const parsed = Number.parseFloat(length)
      if (Number.isFinite(parsed)) return parsed
    }
    return fallback
  }

  private inspectionTimestampLabel(): string {
    const date = new Date(this.inspectedTimestampMs)
    return `${date.getFullYear()}-${this.twoDigits(date.getMonth() + 1)}-${this.twoDigits(date.getDate())} ` +
      `${this.twoDigits(date.getHours())}:${this.twoDigits(date.getMinutes())}:${this.twoDigits(date.getSeconds())}`
  }

  private inspectionValueLabel(key: string): string {
    const value = this.inspectionSeriesValue(key)
    if (!Number.isFinite(value)) return '—'
    if (this.state.valueFormat === MetricChartValueFormat.BYTES) {
      return this.inspectionByteLabel(value, false)
    }
    if (this.state.valueFormat === MetricChartValueFormat.BYTES_PER_SECOND) {
      return this.inspectionByteLabel(value, true)
    }
    const digits = Math.abs(value) > 0 && Math.abs(value) < 1 ? 2 : 1
    return `${value.toFixed(digits)}${this.state.unit}`
  }

  private inspectionByteLabel(value: number, perSecond: boolean): string {
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
    const digits = scale === 1 ? 0 : 1
    return `${(value / scale).toFixed(digits)}${unit}${perSecond ? '/s' : ''}`
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
    this.context.strokeStyle = this.dividerColor()
    this.context.lineWidth = 1
    this.context.stroke()
  }

  private drawLine(seriesIndex: number, width: number, height: number, bounds: MetricChartBounds): void {
    const color = this.seriesColor(this.state.series[seriesIndex].key)
    const lineWidth = chartLineWidthVp(this.chartLineWidth)
    const gapThreshold = this.state.expectedIntervalMs * 1.5
    let segmentStart = -1
    let validCount = 0
    this.context.beginPath()
    for (let index = 0; index <= this.state.points.length; index += 1) {
      const point = index < this.state.points.length ? this.state.points[index] : undefined
      const value = point?.values[seriesIndex]
      const previous = index > 0 ? this.state.points[index - 1] : undefined
      const gap = point !== undefined && previous !== undefined &&
        point.timestampMs - previous.timestampMs > gapThreshold
      const valid = point !== undefined && Number.isFinite(value)
      if (valid) validCount += 1
      if (valid && !gap) {
        if (segmentStart < 0) segmentStart = index
        continue
      }
      if (segmentStart >= 0) {
        this.traceSmoothSegment(seriesIndex, segmentStart, index - 1, width, height, bounds, true)
      }
      segmentStart = valid ? index : -1
    }
    this.context.save()
    this.context.globalAlpha = chartLineOpacityValue(this.chartLineOpacity)
    this.context.strokeStyle = color
    this.context.lineWidth = lineWidth
    this.context.lineJoin = 'round'
    this.context.lineCap = 'round'
    this.context.stroke()

    if (validCount === 1) {
      const point = this.state.points.find((candidate: MetricChartPoint) =>
        Number.isFinite(candidate.values[seriesIndex]))
      if (point !== undefined) {
        this.context.beginPath()
        this.context.arc(this.xPosition(point.timestampMs, width),
          this.yPosition(point.values[seriesIndex], height, bounds), lineWidth / 2, 0, Math.PI * 2)
        this.context.fillStyle = color
        this.context.fill()
      }
    }
    this.context.restore()
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
    this.context.lineTo(this.xPosition(first.timestampMs, width),
      this.yPosition(first.values[seriesIndex], this.chartHeight, bounds))
    this.traceSmoothSegment(seriesIndex, start, end, width, this.chartHeight, bounds, false)
    this.context.lineTo(this.xPosition(last.timestampMs, width), bottom)
    this.context.closePath()
    this.context.save()
    this.context.globalAlpha = 0.18
    this.context.fillStyle = this.seriesColor(this.state.series[seriesIndex].key)
    this.context.fill()
    this.context.restore()
  }

  private traceSmoothSegment(seriesIndex: number, start: number, end: number, width: number,
    height: number, bounds: MetricChartBounds, moveToStart: boolean): void {
    const xCoordinates: number[] = []
    const yCoordinates: number[] = []
    for (let index = start; index <= end; index += 1) {
      const point = this.state.points[index]
      xCoordinates.push(this.xPosition(point.timestampMs, width))
      yCoordinates.push(this.yPosition(point.values[seriesIndex], height, bounds))
    }
    if (xCoordinates.length === 0) return
    if (moveToStart) this.context.moveTo(xCoordinates[0], yCoordinates[0])
    if (xCoordinates.length === 1) return
    if (xCoordinates.length === 2) {
      this.context.lineTo(xCoordinates[1], yCoordinates[1])
      return
    }
    const tangents = this.monotoneTangents(xCoordinates, yCoordinates)
    for (let index = 0; index < xCoordinates.length - 1; index += 1) {
      const interval = xCoordinates[index + 1] - xCoordinates[index]
      if (interval <= 0) {
        this.context.lineTo(xCoordinates[index + 1], yCoordinates[index + 1])
        continue
      }
      this.context.bezierCurveTo(
        xCoordinates[index] + interval / 3,
        yCoordinates[index] + tangents[index] * interval / 3,
        xCoordinates[index + 1] - interval / 3,
        yCoordinates[index + 1] - tangents[index + 1] * interval / 3,
        xCoordinates[index + 1],
        yCoordinates[index + 1]
      )
    }
  }

  private monotoneTangents(xCoordinates: number[], yCoordinates: number[]): number[] {
    const slopes: number[] = []
    for (let index = 0; index < xCoordinates.length - 1; index += 1) {
      const interval = xCoordinates[index + 1] - xCoordinates[index]
      slopes.push(interval > 0 ? (yCoordinates[index + 1] - yCoordinates[index]) / interval : 0)
    }
    const tangents: number[] = [slopes[0]]
    for (let index = 1; index < xCoordinates.length - 1; index += 1) {
      const previousSlope = slopes[index - 1]
      const nextSlope = slopes[index]
      if (previousSlope * nextSlope <= 0) {
        tangents.push(0)
        continue
      }
      const previousInterval = xCoordinates[index] - xCoordinates[index - 1]
      const nextInterval = xCoordinates[index + 1] - xCoordinates[index]
      const previousWeight = 2 * nextInterval + previousInterval
      const nextWeight = nextInterval + 2 * previousInterval
      tangents.push((previousWeight + nextWeight) /
        (previousWeight / previousSlope + nextWeight / nextSlope))
    }
    tangents.push(slopes[slopes.length - 1])

    for (let index = 0; index < slopes.length; index += 1) {
      const slope = slopes[index]
      if (slope === 0) {
        tangents[index] = 0
        tangents[index + 1] = 0
        continue
      }
      const startRatio = tangents[index] / slope
      const endRatio = tangents[index + 1] / slope
      const magnitude = startRatio * startRatio + endRatio * endRatio
      if (magnitude <= 9) continue
      const scale = 3 / Math.sqrt(magnitude)
      tangents[index] = scale * startRatio * slope
      tangents[index + 1] = scale * endRatio * slope
    }
    return tangents
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
    return this.seriesColor(key)
  }

  private dividerColor(): number {
    this.refreshColorCache()
    return this.cachedDividerColor
  }

  private seriesColor(key: string): number {
    this.refreshColorCache()
    const selected = this.selectedSeries()
    const index = selected.findIndex((series: MetricChartSeries) => series.key === key)
    if (index < 0) return 0xFF267454
    if (selected.length <= 1 || index === 0) return this.cachedSeriesStartColor
    if (index === selected.length - 1) return this.cachedSeriesEndColor
    const ratio = index / (selected.length - 1)
    const hueDistance = (this.cachedSeriesEndHsl[0] - this.cachedSeriesStartHsl[0] + 360) % 360
    return this.hslColor(
      (this.cachedSeriesStartHsl[0] + hueDistance * ratio) % 360,
      this.cachedSeriesStartHsl[1] +
        (this.cachedSeriesEndHsl[1] - this.cachedSeriesStartHsl[1]) * ratio,
      this.cachedSeriesStartHsl[2] +
        (this.cachedSeriesEndHsl[2] - this.cachedSeriesStartHsl[2]) * ratio
    )
  }

  private refreshColorCache(): void {
    if (this.cachedPaletteReady && this.cachedColorMode === this.colorMode) {
      return
    }
    this.cachedColorMode = this.colorMode
    this.cachedPaletteReady = true
    this.cachedDividerColor = this.resolveColor($r('app.color.divider'), 0xFFE2E8E3)
    this.cachedSeriesStartColor = this.resolveColor(this.primarySeriesColor, 0xFFD83B4B)
    this.cachedSeriesEndColor = this.resolveColor($r('app.color.chart_series_end'), 0xFF844BC5)
    this.cachedSeriesStartHsl = this.colorHsl(this.cachedSeriesStartColor)
    this.cachedSeriesEndHsl = this.colorHsl(this.cachedSeriesEndColor)
  }

  private colorHsl(color: number): number[] {
    const red = (color >>> 16 & 0xFF) / 255
    const green = (color >>> 8 & 0xFF) / 255
    const blue = (color & 0xFF) / 255
    const maximum = Math.max(red, green, blue)
    const minimum = Math.min(red, green, blue)
    const difference = maximum - minimum
    const lightness = (maximum + minimum) / 2
    let hue = 0
    if (difference > 0) {
      if (maximum === red) {
        hue = 60 * ((green - blue) / difference % 6)
      } else if (maximum === green) {
        hue = 60 * ((blue - red) / difference + 2)
      } else {
        hue = 60 * ((red - green) / difference + 4)
      }
    }
    const saturation = difference === 0 ? 0 : difference / (1 - Math.abs(2 * lightness - 1))
    return [(hue + 360) % 360, saturation, lightness]
  }

  private hslColor(hue: number, saturation: number, lightness: number): number {
    const chroma = (1 - Math.abs(2 * lightness - 1)) * saturation
    const sector = hue / 60
    const intermediate = chroma * (1 - Math.abs(sector % 2 - 1))
    let red = 0
    let green = 0
    let blue = 0
    if (sector < 1) {
      red = chroma
      green = intermediate
    } else if (sector < 2) {
      red = intermediate
      green = chroma
    } else if (sector < 3) {
      green = chroma
      blue = intermediate
    } else if (sector < 4) {
      green = intermediate
      blue = chroma
    } else if (sector < 5) {
      red = intermediate
      blue = chroma
    } else {
      red = chroma
      blue = intermediate
    }
    const offset = lightness - chroma / 2
    const redByte = Math.round((red + offset) * 255)
    const greenByte = Math.round((green + offset) * 255)
    const blueByte = Math.round((blue + offset) * 255)
    return 0xFF000000 + redByte * 0x10000 + greenByte * 0x100 + blueByte
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
