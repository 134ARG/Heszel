import { FrameCallback } from '@kit.ArkUI'
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
const RETAINED_DATA_EXTRA_RATIO = 0.5
class MetricChartBounds {
  minimum: number = 0
  maximum: number = 1
  step: number = 0.25
}

class MetricChartFrameCallback extends FrameCallback {
  private action: () => void

  constructor(action: () => void) {
    super()
    this.action = action
  }

  onFrame(_frameTimeInNano: number): void {
    this.action()
  }

  onIdle(_timeLeftInNano: number): void {}
}

@Component
export struct AdaptiveMetricChart {
  @ObjectLink @Watch('onChartStateChanged') state: AdaptiveMetricChartState
  @Prop @Watch('onPaletteChanged') colorMode: AppColorMode = AppColorMode.SYSTEM
  @Prop @Watch('onPaletteChanged') primarySeriesColor: Resource = $r('app.color.chart_series_start')
  @Prop @Watch('onLineStyleChanged') chartLineWidth: ChartLineWidth = ChartLineWidth.DEFAULT
  @Prop @Watch('onLineStyleChanged') chartLineOpacity: ChartLineOpacity = ChartLineOpacity.DEFAULT
  @Prop @Watch('onStackModeChanged') stacked: boolean = false
  @Prop @Watch('onStackModeChanged') stackNormalize: boolean = false
  @Prop @Watch('onStackModeChanged') stackOutlineKey: string = ''
  @Prop @Watch('onInspectionDismissRequested') inspectionDismissToken: number = 0
  @Prop metricInspectionSort: MetricInspectionSort = MetricInspectionSort.VALUE
  @Prop chartHeight: number = 230
  @Prop loading: boolean = false
  @Prop showNoData: boolean = true
  @Prop showLegend: boolean = true
  @Prop sparseYAxisLabels: boolean = false
  onPlotAreaChange: (left: number, top: number, width: number, height: number) => void =
    (_left: number, _top: number, _width: number, _height: number) => {}
  @State private chartWidth: number = 0
  @State private inspectedTimestampMs: number = 0
  @State private inspectionPopupAtTop: boolean = true
  @State private inspectionRange: MetricChartRange = MetricChartRange.HOUR_1
  @State private dataLayerOffsetX: number = 0
  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  private dataContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  private ready: boolean = false
  private dataReady: boolean = false
  private chartVisible: boolean = true
  private drawPending: boolean = false
  private canvasHeight: number = 0
  private frameCallback: MetricChartFrameCallback =
    new MetricChartFrameCallback(() => this.drawOnFrame())
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
  private baseLayerNeedsRedraw: boolean = true
  private dataLayerNeedsRebuild: boolean = true
  private dataLayerOriginMs: number = 0
  private dataLayerLastPoint: MetricChartPoint | null = null
  private dataLayerSignature: string = ''
  private dataLayerRevision: number = -1

  build() {
    this.chartContent()
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
          if (!this.sparseYAxisLabels) {
            Text(this.yLabel(this.bounds().minimum +
              (this.bounds().maximum - this.bounds().minimum) * 0.75))
              .fontSize(9)
              .fontColor($r('app.color.text_tertiary'))
              .width(Y_LABEL_WIDTH - 4)
              .textAlign(TextAlign.End)
              .position({ x: 0, y: PLOT_INSET + (this.chartHeight - PLOT_INSET * 2) / 4 })
              .markAnchor({ x: 0, y: '50%' })
          }
          Text(this.yLabel((this.bounds().minimum + this.bounds().maximum) / 2))
            .fontSize(9)
            .fontColor($r('app.color.text_tertiary'))
            .width(Y_LABEL_WIDTH - 4)
            .textAlign(TextAlign.End)
            .position({ x: 0, y: this.chartHeight / 2 })
            .markAnchor({ x: 0, y: '50%' })
          if (!this.sparseYAxisLabels) {
            Text(this.yLabel(this.bounds().minimum +
              (this.bounds().maximum - this.bounds().minimum) * 0.25))
              .fontSize(9)
              .fontColor($r('app.color.text_tertiary'))
              .width(Y_LABEL_WIDTH - 4)
              .textAlign(TextAlign.End)
              .position({ x: 0, y: PLOT_INSET + (this.chartHeight - PLOT_INSET * 2) * 3 / 4 })
              .markAnchor({ x: 0, y: '50%' })
          }
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
            Stack({ alignContent: Alignment.TopStart }) {
              Canvas(this.context)
                .width('100%')
                .height(this.chartHeight)
                .onReady(() => {
                  this.ready = true
                  this.canvasHeight = this.context.height
                  this.chartWidth = this.context.width
                  this.baseLayerNeedsRedraw = true
                  this.scheduleDraw()
                })
                .onAreaChange((oldValue: Area, newValue: Area) => {
                  const width = this.areaLength(newValue.width, this.context.width)
                  const height = this.areaLength(newValue.height, this.context.height)
                  const widthChanged = Math.abs(width - this.chartWidth) > 0.5
                  const sizeChanged = widthChanged ||
                    Math.abs(height - this.canvasHeight) > 0.5
                  if (widthChanged) this.chartWidth = width
                  this.onPlotAreaChange(
                    this.areaLength(newValue.globalPosition.x, 0),
                    this.areaLength(newValue.globalPosition.y, 0),
                    width,
                    height
                  )
                  if (sizeChanged) {
                    this.canvasHeight = height
                    this.baseLayerNeedsRedraw = true
                    this.invalidateDataLayer()
                    this.scheduleDraw()
                  }
                })
                .onVisibleAreaChange([0.01], (isExpanding: boolean, _currentRatio: number) => {
                  this.onChartVisibilityChanged(isExpanding)
                })
                .onTouch((event: TouchEvent) => this.onChartTouch(event))

              Canvas(this.dataContext)
                .width(this.retainedDataCanvasWidth())
                .height(this.chartHeight)
                .position({ x: 0, y: 0 })
                .translate({ x: this.dataLayerOffsetX })
                .hitTestBehavior(HitTestMode.None)
                .onReady(() => {
                  this.dataReady = true
                  this.baseLayerNeedsRedraw = true
                  this.invalidateDataLayer()
                  this.scheduleDraw()
                })
                .onDisAppear(() => {
                  this.dataReady = false
                  this.dataLayerNeedsRebuild = true
                })
            }
              .width('100%')
              .height(this.chartHeight)
              .backgroundColor($r('app.color.surface_input'))
              .borderRadius(4)
              .clip(true)

            if (this.inspectionVisible()) {
              Row()
                .width(1)
                .height(this.chartHeight - PLOT_INSET * 2)
                .backgroundColor($r('app.color.selected_border'))
                .opacity(0.9)
                .position({ x: this.inspectionLineX(), y: PLOT_INSET })
                .hitTestBehavior(HitTestMode.None)

              ForEach(this.selectedSeries(), (series: MetricChartSeries) => {
                if (Number.isFinite(this.inspectionPlotValue(series.key))) {
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

            if (this.inspectionVisible()) {
              this.inspectionPopup()
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
    if (!this.ready || !this.dataReady || this.dataLayerRevision === this.state.revision) return
    this.scheduleDraw()
  }

  private onPaletteChanged(): void {
    this.cachedPaletteReady = false
    this.baseLayerNeedsRedraw = true
    this.invalidateDataLayer()
    this.scheduleDraw()
  }

  private onLineStyleChanged(): void {
    this.invalidateDataLayer()
    this.scheduleDraw()
  }

  private onStackModeChanged(): void {
    this.baseLayerNeedsRedraw = true
    this.invalidateDataLayer()
    this.scheduleDraw()
  }

  private onChartVisibilityChanged(visible: boolean): void {
    if (this.chartVisible === visible) return
    this.chartVisible = visible
    if (visible) {
      this.baseLayerNeedsRedraw = true
      this.invalidateDataLayer()
      this.scheduleDraw()
    }
  }

  private scheduleDraw(): void {
    if (!this.ready || !this.dataReady || !this.chartVisible || this.drawPending) return
    this.drawPending = true
    this.getUIContext().postFrameCallback(this.frameCallback)
  }

  private drawOnFrame(): void {
    this.drawPending = false
    if (!this.ready || !this.dataReady || !this.chartVisible) return
    this.drawRetainedData()
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
    return this.yPosition(this.inspectionPlotValue(key), this.chartHeight, this.bounds())
  }

  private inspectionPlotValue(key: string): number {
    const rawValue = this.inspectionSeriesValue(key)
    if (!this.stacked || key === this.stackOutlineKey) return rawValue
    const seriesIndex = this.state.series.findIndex((series: MetricChartSeries) => series.key === key)
    const stackIndices = this.stackSeriesIndices()
    const stackPosition = stackIndices.indexOf(seriesIndex)
    const point = this.inspectionPoint()
    if (point === null || stackPosition < 0) return rawValue
    let cumulative = 0
    for (let index = 0; index <= stackPosition; index += 1) {
      const value = point.values[stackIndices[index]]
      if (!Number.isFinite(value)) return Number.NaN
      cumulative += value
    }
    return cumulative / this.stackDivisor(stackIndices)
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

  private inspectionPopupMaximumRows(): number {
    const availableHeight = this.chartHeight - INSPECTION_POPUP_MARGIN * 2 -
      INSPECTION_POPUP_CHROME_HEIGHT
    return Math.max(1, Math.min(INSPECTION_POPUP_MAX_ROWS,
      Math.floor(availableHeight / INSPECTION_POPUP_ROW_HEIGHT)))
  }

  private inspectionPopupBodyHeight(): number {
    return Math.min(this.inspectionPopupMaximumRows(), this.inspectionPopupRows()) *
      INSPECTION_POPUP_ROW_HEIGHT
  }

  private inspectionPopupScrollable(): boolean {
    return this.inspectionPopupRows() > this.inspectionPopupMaximumRows()
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
    return plotX
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

  private retainedDataCanvasWidth(): number {
    const width = this.effectiveChartWidth()
    const plotWidth = Math.max(1, width - PLOT_INSET * 2)
    const extraRatio = this.state.range === MetricChartRange.LIVE ? RETAINED_DATA_EXTRA_RATIO : 0
    return PLOT_INSET * 2 + plotWidth * (1 + extraRatio)
  }

  private invalidateDataLayer(): void {
    this.dataLayerNeedsRebuild = true
    this.dataLayerOriginMs = 0
    this.dataLayerLastPoint = null
    this.dataLayerSignature = ''
    this.dataLayerRevision = -1
    if (Math.abs(this.dataLayerOffsetX) > 0.05) this.dataLayerOffsetX = 0
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
    if (this.state.valueFormat === MetricChartValueFormat.INTEGER) {
      return `${value.toFixed(0)}${this.state.unit}`
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

  private drawRetainedData(): void {
    const width = this.context.width
    const height = this.context.height
    const dataWidth = this.dataContext.width
    if (width <= 0 || height <= 0 || dataWidth <= 0 || this.dataContext.height <= 0) return
    if (this.baseLayerNeedsRedraw) {
      this.context.clearRect(0, 0, width, height)
      this.drawGrid(width, height)
      this.baseLayerNeedsRedraw = false
    }

    const indices = this.selectedIndices()
    const bounds = this.bounds()
    const signature = this.retainedDataSignature(indices, bounds, width, height)
    const lastPoint = this.state.points.length > 0 ?
      this.state.points[this.state.points.length - 1] : null
    if (this.dataLayerNeedsRebuild || this.dataLayerSignature !== signature) {
      this.rebuildRetainedData(indices, bounds, width, height, signature, lastPoint)
      return
    }
    if (this.dataLayerRevision === this.state.revision) return
    if (this.state.range !== MetricChartRange.LIVE || this.dataLayerLastPoint === null ||
      lastPoint === null || lastPoint === this.dataLayerLastPoint) {
      this.rebuildRetainedData(indices, bounds, width, height, signature, lastPoint)
      return
    }

    const previousIndex = this.state.points.indexOf(this.dataLayerLastPoint)
    const lastIndex = this.state.points.length - 1
    const durationMs = Math.max(1, this.state.windowEndMs - this.state.windowStartMs)
    const offsetX = (this.state.windowStartMs - this.dataLayerOriginMs) / durationMs *
      Math.max(1, width - PLOT_INSET * 2)
    const maximumOffsetX = Math.max(0, dataWidth - width)
    if (previousIndex < 0 || previousIndex >= lastIndex || offsetX < 0 ||
      offsetX > maximumOffsetX) {
      this.rebuildRetainedData(indices, bounds, width, height, signature, lastPoint)
      return
    }
    this.appendRetainedData(indices, bounds, width, height, signature,
      previousIndex, lastIndex, offsetX, lastPoint)
  }

  private retainedDataSignature(indices: number[], bounds: MetricChartBounds,
    width: number, height: number): string {
    const keys = indices.map((seriesIndex: number) => this.state.series[seriesIndex].key).join(',')
    return `${keys}|${bounds.minimum}|${bounds.maximum}|${width}|${height}|` +
      `${this.state.range}|${this.stacked}|${this.stackNormalize}|${this.stackOutlineKey}|` +
      `${this.state.expectedIntervalMs}|` +
      `${this.chartLineWidth}|${this.chartLineOpacity}`
  }

  private rebuildRetainedData(indices: number[], bounds: MetricChartBounds,
    width: number, height: number, signature: string, lastPoint: MetricChartPoint | null): void {
    this.dataContext.clearRect(0, 0, this.dataContext.width, this.dataContext.height)
    const durationMs = Math.max(1, this.state.windowEndMs - this.state.windowStartMs)
    this.dataLayerOriginMs = this.state.windowStartMs
    this.drawDataRange(this.dataContext, indices, width, height, bounds, 0,
      this.state.points.length - 1, this.dataLayerOriginMs, durationMs, true)
    this.dataLayerLastPoint = lastPoint
    this.dataLayerSignature = signature
    this.dataLayerRevision = this.state.revision
    this.dataLayerNeedsRebuild = false
    if (Math.abs(this.dataLayerOffsetX) > 0.05) this.dataLayerOffsetX = 0
  }

  private appendRetainedData(indices: number[], bounds: MetricChartBounds,
    width: number, height: number, signature: string, previousIndex: number,
    lastIndex: number, offsetX: number, lastPoint: MetricChartPoint): void {
    const durationMs = Math.max(1, this.state.windowEndMs - this.state.windowStartMs)
    const clearPointIndex = Math.max(0, previousIndex - 1)
    const renderPointIndex = Math.max(0, clearPointIndex - 1)
    const drawingPadding = Math.max(2, chartLineWidthVp(this.chartLineWidth))
    const clearX = Math.max(0, this.renderXPosition(
      this.state.points[clearPointIndex].timestampMs, this.dataLayerOriginMs,
      durationMs, width) - drawingPadding)
    const clearRight = Math.min(this.dataContext.width, this.renderXPosition(
      this.state.points[lastIndex].timestampMs, this.dataLayerOriginMs,
      durationMs, width) + drawingPadding)
    const clearWidth = Math.max(0, clearRight - clearX)
    this.dataContext.clearRect(clearX, 0, clearWidth, height)
    this.dataContext.save()
    this.dataContext.beginPath()
    this.dataContext.rect(clearX, 0, clearWidth, height)
    this.dataContext.clip()
    this.drawDataRange(this.dataContext, indices, width, height, bounds,
      renderPointIndex, lastIndex, this.dataLayerOriginMs, durationMs, false)
    this.dataContext.restore()
    this.dataLayerLastPoint = lastPoint
    this.dataLayerSignature = signature
    this.dataLayerRevision = this.state.revision
    if (Math.abs(this.dataLayerOffsetX + offsetX) > 0.05) this.dataLayerOffsetX = -offsetX
  }

  private drawDataRange(context: CanvasRenderingContext2D, selectedIndices: number[],
    width: number, height: number, bounds: MetricChartBounds, pointStart: number, pointEnd: number,
    windowStartMs: number, durationMs: number, drawSingleSample: boolean): void {
    if (this.stacked) {
      this.drawStackedRange(context, selectedIndices, width, height, bounds, pointStart, pointEnd,
        windowStartMs, durationMs, drawSingleSample)
      return
    }
    if (selectedIndices.length === 1) {
      this.drawFillRange(context, selectedIndices[0], pointStart, pointEnd, width, height, bounds,
        windowStartMs, durationMs)
    }
    selectedIndices.forEach((seriesIndex: number) => {
      this.drawLineRange(context, seriesIndex, pointStart, pointEnd, width, height, bounds,
        windowStartMs, durationMs, drawSingleSample)
    })
  }

  private drawStackedRange(context: CanvasRenderingContext2D, selectedIndices: number[],
    width: number, height: number, bounds: MetricChartBounds, pointStart: number, pointEnd: number,
    windowStartMs: number, durationMs: number, drawSingleSample: boolean): void {
    if (pointStart < 0 || pointEnd < pointStart || pointEnd >= this.state.points.length) return
    const stackIndices = selectedIndices.filter((seriesIndex: number) =>
      this.state.series[seriesIndex].key !== this.stackOutlineKey)
    if (stackIndices.length > 0) {
      const xCoordinates: number[] = []
      const baselineCoordinates: number[] = []
      const cumulativeCoordinates: number[][] = stackIndices.map(() => [])
      const validPoints: boolean[] = []
      const divisor = this.stackDivisor(stackIndices)
      for (let pointIndex = pointStart; pointIndex <= pointEnd; pointIndex += 1) {
        const point = this.state.points[pointIndex]
        const valid = stackIndices.every((seriesIndex: number) =>
          Number.isFinite(point.values[seriesIndex]))
        validPoints.push(valid)
        xCoordinates.push(this.renderXPosition(point.timestampMs, windowStartMs, durationMs, width))
        baselineCoordinates.push(this.yPosition(0, height, bounds))
        let cumulative = 0
        stackIndices.forEach((seriesIndex: number, stackPosition: number) => {
          if (valid) cumulative += point.values[seriesIndex]
          cumulativeCoordinates[stackPosition].push(valid ?
            this.yPosition(cumulative / divisor, height, bounds) : 0)
        })
      }
      const segmentStarts: number[] = []
      const segmentEnds: number[] = []
      this.stackSegments(validPoints, pointStart, segmentStarts, segmentEnds)
      stackIndices.forEach((seriesIndex: number, stackPosition: number) => {
        const lowerCoordinates = stackPosition === 0 ?
          baselineCoordinates : cumulativeCoordinates[stackPosition - 1]
        this.drawStackBand(context, seriesIndex, xCoordinates, lowerCoordinates,
          cumulativeCoordinates[stackPosition], segmentStarts, segmentEnds)
      })
      if (drawSingleSample) {
        this.drawSingleStackSample(context, stackIndices, xCoordinates,
          cumulativeCoordinates, validPoints)
      }
    }
    const outlineIndex = selectedIndices.find((seriesIndex: number) =>
      this.state.series[seriesIndex].key === this.stackOutlineKey)
    if (outlineIndex !== undefined) {
      this.drawLineRange(context, outlineIndex, pointStart, pointEnd, width, height, bounds,
        windowStartMs, durationMs, drawSingleSample)
    }
  }

  private stackSeriesIndices(): number[] {
    return this.selectedIndices().filter((seriesIndex: number) =>
      this.state.series[seriesIndex].key !== this.stackOutlineKey)
  }

  private stackDivisor(stackIndices: number[]): number {
    return this.stackNormalize ? Math.max(1, stackIndices.length) : 1
  }

  private stackSegments(validPoints: boolean[], pointStart: number,
    starts: number[], ends: number[]): void {
    const gapThreshold = this.state.expectedIntervalMs * 1.5
    let segmentStart = -1
    for (let index = 0; index <= validPoints.length; index += 1) {
      const point = index < validPoints.length ? this.state.points[pointStart + index] : undefined
      const previous = index > 0 ? this.state.points[pointStart + index - 1] : undefined
      const gap = point !== undefined && previous !== undefined &&
        point.timestampMs - previous.timestampMs > gapThreshold
      const valid = point !== undefined && validPoints[index]
      if (valid && !gap) {
        if (segmentStart < 0) segmentStart = index
        continue
      }
      if (segmentStart >= 0 && index - segmentStart > 1) {
        starts.push(segmentStart)
        ends.push(index - 1)
      }
      segmentStart = valid ? index : -1
    }
  }

  private drawStackBand(context: CanvasRenderingContext2D, seriesIndex: number,
    xCoordinates: number[], lowerCoordinates: number[], upperCoordinates: number[],
    segmentStarts: number[], segmentEnds: number[]): void {
    for (let segment = 0; segment < segmentStarts.length; segment += 1) {
      this.fillStackSegment(context, seriesIndex, xCoordinates, lowerCoordinates, upperCoordinates,
        segmentStarts[segment], segmentEnds[segment])
    }
  }

  private fillStackSegment(context: CanvasRenderingContext2D, seriesIndex: number,
    xCoordinates: number[], lowerCoordinates: number[], upperCoordinates: number[],
    start: number, end: number): void {
    const segmentX = this.coordinateSegment(xCoordinates, start, end)
    const segmentLower = this.coordinateSegment(lowerCoordinates, start, end)
    const segmentUpper = this.coordinateSegment(upperCoordinates, start, end)
    context.beginPath()
    this.traceSmoothCoordinates(context, segmentX, segmentUpper, true)
    context.lineTo(segmentX[segmentX.length - 1], segmentLower[segmentLower.length - 1])
    this.traceSmoothCoordinates(context, segmentX.slice().reverse(),
      segmentLower.slice().reverse(), false)
    context.closePath()
    const color = this.seriesColor(this.state.series[seriesIndex].key)
    context.save()
    context.globalAlpha = chartLineOpacityValue(this.chartLineOpacity) * 0.55
    context.fillStyle = color
    context.fill()
    context.restore()

    context.beginPath()
    this.traceSmoothCoordinates(context, segmentX, segmentUpper, true)
    context.save()
    context.globalAlpha = chartLineOpacityValue(this.chartLineOpacity)
    context.strokeStyle = color
    context.lineWidth = chartLineWidthVp(this.chartLineWidth)
    context.lineJoin = 'round'
    context.lineCap = 'round'
    context.stroke()
    context.restore()
  }

  private coordinateSegment(coordinates: number[], start: number, end: number): number[] {
    if (start === 0 && end === coordinates.length - 1) return coordinates
    return coordinates.slice(start, end + 1)
  }

  private drawSingleStackSample(context: CanvasRenderingContext2D, stackIndices: number[],
    xCoordinates: number[], cumulativeCoordinates: number[][], validPoints: boolean[]): void {
    let pointIndex = -1
    for (let index = 0; index < validPoints.length; index += 1) {
      if (!validPoints[index]) continue
      if (pointIndex >= 0) return
      pointIndex = index
    }
    if (pointIndex < 0) return
    const lineWidth = chartLineWidthVp(this.chartLineWidth)
    stackIndices.forEach((seriesIndex: number, stackPosition: number) => {
      context.beginPath()
      context.arc(xCoordinates[pointIndex], cumulativeCoordinates[stackPosition][pointIndex],
        lineWidth / 2, 0, Math.PI * 2)
      context.save()
      context.globalAlpha = chartLineOpacityValue(this.chartLineOpacity)
      context.fillStyle = this.seriesColor(this.state.series[seriesIndex].key)
      context.fill()
      context.restore()
    })
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

  private drawLineRange(context: CanvasRenderingContext2D, seriesIndex: number,
    pointStart: number, pointEnd: number, width: number, height: number, bounds: MetricChartBounds,
    windowStartMs: number, durationMs: number, drawSingleSample: boolean): void {
    if (pointStart < 0 || pointEnd < pointStart || pointEnd >= this.state.points.length) return
    const color = this.seriesColor(this.state.series[seriesIndex].key)
    const lineWidth = chartLineWidthVp(this.chartLineWidth)
    const gapThreshold = this.state.expectedIntervalMs * 1.5
    let segmentStart = -1
    let validCount = 0
    context.beginPath()
    for (let index = pointStart; index <= pointEnd + 1; index += 1) {
      const point = index <= pointEnd ? this.state.points[index] : undefined
      const value = point?.values[seriesIndex]
      const previous = index > pointStart ? this.state.points[index - 1] : undefined
      const gap = point !== undefined && previous !== undefined &&
        point.timestampMs - previous.timestampMs > gapThreshold
      const valid = point !== undefined && Number.isFinite(value)
      if (valid) validCount += 1
      if (valid && !gap) {
        if (segmentStart < 0) segmentStart = index
        continue
      }
      if (segmentStart >= 0) {
        this.traceSmoothSeriesRange(context, seriesIndex, segmentStart, index - 1,
          width, height, bounds, windowStartMs, durationMs, true)
      }
      segmentStart = valid ? index : -1
    }
    context.save()
    context.globalAlpha = chartLineOpacityValue(this.chartLineOpacity)
    context.strokeStyle = color
    context.lineWidth = lineWidth
    context.lineJoin = 'round'
    context.lineCap = 'round'
    context.stroke()

    if (drawSingleSample && validCount === 1) {
      let point: MetricChartPoint | undefined = undefined
      for (let index = pointStart; index <= pointEnd; index += 1) {
        if (Number.isFinite(this.state.points[index].values[seriesIndex])) {
          point = this.state.points[index]
          break
        }
      }
      if (point !== undefined) {
        context.beginPath()
        context.arc(this.renderXPosition(point.timestampMs, windowStartMs, durationMs, width),
          this.yPosition(point.values[seriesIndex], height, bounds), lineWidth / 2, 0, Math.PI * 2)
        context.fillStyle = color
        context.fill()
      }
    }
    context.restore()
  }

  private drawFillRange(context: CanvasRenderingContext2D, seriesIndex: number,
    pointStart: number, pointEnd: number, width: number, height: number, bounds: MetricChartBounds,
    windowStartMs: number, durationMs: number): void {
    if (pointStart < 0 || pointEnd < pointStart || pointEnd >= this.state.points.length) return
    const bottom = height - PLOT_INSET
    const gapThreshold = this.state.expectedIntervalMs * 1.5
    let segmentStart = -1
    for (let index = pointStart; index <= pointEnd + 1; index += 1) {
      const point = index <= pointEnd ? this.state.points[index] : undefined
      const value = point?.values[seriesIndex]
      const previous = index > pointStart ? this.state.points[index - 1] : undefined
      const gap = point !== undefined && previous !== undefined &&
        point.timestampMs - previous.timestampMs > gapThreshold
      if (point !== undefined && Number.isFinite(value) && !gap) {
        if (segmentStart < 0) segmentStart = index
        continue
      }
      if (segmentStart >= 0 && index - segmentStart > 1) {
        this.fillSeriesSegment(context, seriesIndex, segmentStart, index - 1,
          width, height, bottom, bounds, windowStartMs, durationMs)
      }
      segmentStart = point !== undefined && Number.isFinite(value) ? index : -1
    }
  }

  private fillSeriesSegment(context: CanvasRenderingContext2D, seriesIndex: number,
    start: number, end: number, width: number, height: number, bottom: number,
    bounds: MetricChartBounds, windowStartMs: number, durationMs: number): void {
    const first = this.state.points[start]
    const last = this.state.points[end]
    const firstX = this.renderXPosition(first.timestampMs, windowStartMs, durationMs, width)
    const lastX = this.renderXPosition(last.timestampMs, windowStartMs, durationMs, width)
    context.beginPath()
    context.moveTo(firstX, bottom)
    context.lineTo(firstX, this.yPosition(first.values[seriesIndex], height, bounds))
    this.traceSmoothSeriesRange(context, seriesIndex, start, end, width, height, bounds,
      windowStartMs, durationMs, false)
    context.lineTo(lastX, bottom)
    context.closePath()
    context.save()
    context.globalAlpha = 0.18
    context.fillStyle = this.seriesColor(this.state.series[seriesIndex].key)
    context.fill()
    context.restore()
  }

  private traceSmoothSeriesRange(context: CanvasRenderingContext2D, seriesIndex: number,
    start: number, end: number, width: number, height: number, bounds: MetricChartBounds,
    windowStartMs: number, durationMs: number, moveToStart: boolean): void {
    const xCoordinates: number[] = []
    const yCoordinates: number[] = []
    for (let index = start; index <= end; index += 1) {
      const point = this.state.points[index]
      xCoordinates.push(this.renderXPosition(point.timestampMs, windowStartMs, durationMs, width))
      yCoordinates.push(this.yPosition(point.values[seriesIndex], height, bounds))
    }
    if (xCoordinates.length === 0) return
    this.traceSmoothCoordinates(context, xCoordinates, yCoordinates, moveToStart)
  }

  private traceSmoothCoordinates(context: CanvasRenderingContext2D,
    xCoordinates: number[], yCoordinates: number[], moveToStart: boolean): void {
    if (xCoordinates.length === 0 || xCoordinates.length !== yCoordinates.length) return
    if (moveToStart) context.moveTo(xCoordinates[0], yCoordinates[0])
    if (xCoordinates.length === 1) return
    if (xCoordinates.length === 2) {
      context.lineTo(xCoordinates[1], yCoordinates[1])
      return
    }
    const tangents = this.monotoneTangents(xCoordinates, yCoordinates)
    for (let index = 0; index < xCoordinates.length - 1; index += 1) {
      const interval = xCoordinates[index + 1] - xCoordinates[index]
      if (interval === 0) {
        context.lineTo(xCoordinates[index + 1], yCoordinates[index + 1])
        continue
      }
      context.bezierCurveTo(
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
      slopes.push(interval !== 0 ? (yCoordinates[index + 1] - yCoordinates[index]) / interval : 0)
    }
    const tangents: number[] = [slopes[0]]
    for (let index = 1; index < xCoordinates.length - 1; index += 1) {
      const previousSlope = slopes[index - 1]
      const nextSlope = slopes[index]
      if (previousSlope * nextSlope <= 0) {
        tangents.push(0)
        continue
      }
      const previousInterval = Math.abs(xCoordinates[index] - xCoordinates[index - 1])
      const nextInterval = Math.abs(xCoordinates[index + 1] - xCoordinates[index])
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

  private renderXPosition(timestampMs: number, windowStartMs: number,
    durationMs: number, width: number): number {
    const ratio = (timestampMs - windowStartMs) / Math.max(1, durationMs)
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
    if (this.state.valueFormat === MetricChartValueFormat.INTEGER) return `${value.toFixed(0)}${this.state.unit}`
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
