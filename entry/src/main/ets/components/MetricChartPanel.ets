import {
  AppColorMode,
  ChartLineOpacity,
  ChartLineWidth,
  chartHeightVp,
  MetricChartHeight,
  MetricInspectionSort
} from '../model/AppearanceModels'
import {
  AdaptiveMetricChartState,
  MAX_SELECTED_METRIC_SERIES,
  MetricChartRange,
  MetricChartSeries
} from '../model/MetricChartModels'
import { AdaptiveMetricChart } from './AdaptiveMetricChart'

const METRIC_CHART_RANGES: MetricChartRange[] = [
  MetricChartRange.LIVE,
  MetricChartRange.HOUR_1,
  MetricChartRange.HOUR_12,
  MetricChartRange.DAY_1,
  MetricChartRange.DAY_7,
  MetricChartRange.DAY_30
]

@Component
struct MetricChartChoice {
  @ObjectLink series: MetricChartSeries
  @Prop limitReached: boolean = false
  onToggle: () => void = () => {}

  build() {
    Row({ space: 10 }) {
      Row() {
        if (this.series.selected) {
          Text('✓')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_on_action'))
        }
      }
      .width(22)
      .height(22)
      .justifyContent(FlexAlign.Center)
      .borderRadius(6)
      .backgroundColor(this.series.selected ? $r('app.color.action') : $r('app.color.surface_neutral'))
      .border({
        width: this.series.selected ? 0 : 1,
        color: this.limitReached ? $r('app.color.card_border') : $r('app.color.selected_border')
      })

      Text(this.series.label)
        .fontSize(13)
        .fontColor(this.limitReached && !this.series.selected ?
          $r('app.color.text_tertiary') : $r('app.color.text_primary'))
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height(40)
    .padding({ left: 8, right: 8 })
    .borderRadius(8)
    .onClick(() => this.onToggle())
  }
}

@Component
export struct MetricChartPanel {
  @ObjectLink chart: AdaptiveMetricChartState
  @Prop title: ResourceStr = ''
  @Prop loading: boolean = false
  @Prop errorMessage: string = ''
  @Prop compact: boolean = false
  @Prop colorMode: AppColorMode = AppColorMode.SYSTEM
  @Prop metricChartHeight: MetricChartHeight = MetricChartHeight.DEFAULT
  @Prop metricInspectionSort: MetricInspectionSort = MetricInspectionSort.VALUE
  @Prop chartLineWidth: ChartLineWidth = ChartLineWidth.DEFAULT
  @Prop chartLineOpacity: ChartLineOpacity = ChartLineOpacity.DEFAULT
  @Prop metricHint: ResourceStr = ''
  @Prop searchPlaceholder: ResourceStr = ''
  @State private metricSheetVisible: boolean = false
  @State private metricFilter: string = ''
  @State private selectionLimitReached: boolean = false
  @State private metricSelectionDirty: boolean = false
  @State private inspectionDismissToken: number = 0
  private cardGlobalLeft: number = 0
  private cardGlobalTop: number = 0
  private plotGlobalLeft: number = 0
  private plotGlobalTop: number = 0
  private plotWidth: number = 0
  private plotHeight: number = 0
  private cardAreaReady: boolean = false
  private plotAreaReady: boolean = false
  onRangeChange: (range: MetricChartRange) => void = () => {}
  onSelectionChange: (selectedKeys: string[]) => void = (_selectedKeys: string[]) => {}
  onSelectionCommit: (selectedKeys: string[]) => void = (_selectedKeys: string[]) => {}

  build() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Column({ space: 2 }) {
          Text(this.title)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          Text(this.rangeDescription())
            .fontSize(11)
            .fontColor($r('app.color.text_tertiary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Row({ space: 6 }) {
          this.metricControl()
          this.rangeControl()
        }
      }
      .width('100%')
      .onClick(() => this.dismissInspection())

      if (this.errorMessage.length > 0) {
        Text(this.errorMessage)
          .fontSize(12)
          .fontColor($r('app.color.error_text'))
          .width('100%')
          .padding(10)
          .backgroundColor($r('app.color.error_surface'))
          .borderRadius(8)
          .onClick(() => this.dismissInspection())
      }

      AdaptiveMetricChart({
        state: this.chart,
        colorMode: this.colorMode,
        chartLineWidth: this.chartLineWidth,
        chartLineOpacity: this.chartLineOpacity,
        metricInspectionSort: this.metricInspectionSort,
        chartHeight: chartHeightVp(this.metricChartHeight, this.compact),
        loading: this.loading,
        showNoData: this.errorMessage.length === 0,
        inspectionDismissToken: this.inspectionDismissToken,
        onPlotAreaChange: (left: number, top: number, width: number, height: number) => {
          this.plotGlobalLeft = left
          this.plotGlobalTop = top
          this.plotWidth = width
          this.plotHeight = height
          this.plotAreaReady = true
        }
      })
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.card_border') })
    .borderRadius(16)
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.cardGlobalLeft = this.areaLength(newValue.globalPosition.x)
      this.cardGlobalTop = this.areaLength(newValue.globalPosition.y)
      this.cardAreaReady = true
    })
    .onClick((event: ClickEvent) => this.onCardClick(event))
  }

  @Builder
  private metricControl() {
    Button($r('app.string.chart_metrics_count', this.chart.selectedCount()))
      .height(32)
      .constraintSize({ minHeight: 32, maxHeight: 32 })
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.action'))
      .backgroundColor($r('app.color.action_surface'))
      .borderRadius(9)
      .accessibilityText($r('app.string.chart_choose_metrics'))
      .onClick(() => {
        this.dismissInspection()
        this.metricSheetVisible = true
        this.selectionLimitReached = false
        this.metricSelectionDirty = false
      })
      .bindSheet(this.metricSheetVisible, this.metricSheet, {
        height: SheetSize.MEDIUM,
        detents: [SheetSize.MEDIUM, SheetSize.LARGE],
        dragBar: true,
        showClose: true,
        backgroundColor: $r('app.color.surface'),
        title: {
          title: $r('app.string.chart_choose_metrics'),
          subtitle: this.metricHint
        },
        onWillDismiss: (action: DismissSheetAction) => {
          // Interactive dismissal starts before onDisappear. Clear the bound
          // visibility now so a render during the exit animation cannot reopen it.
          this.metricSheetVisible = false
          this.selectionLimitReached = false
          action.dismiss()
        },
        onDisappear: () => {
          this.commitMetricSelection()
          this.metricSheetVisible = false
          this.selectionLimitReached = false
        }
      })
  }

  @Builder
  private metricSheet() {
    Column({ space: 10 }) {
      TextInput({ text: this.metricFilter, placeholder: this.searchPlaceholder })
        .height(40)
        .fontSize(13)
        .fontColor($r('app.color.text_primary'))
        .placeholderColor($r('app.color.text_tertiary'))
        .backgroundColor($r('app.color.surface_input'))
        .borderRadius(9)
        .onChange((value: string) => {
          this.metricFilter = value
        })

      Row({ space: 6 }) {
        Text(this.selectionLimitReached ?
          $r('app.string.chart_metric_limit', MAX_SELECTED_METRIC_SERIES) :
          $r('app.string.chart_metrics_selected', this.chart.selectedCount(), this.chart.series.length))
          .fontSize(11)
          .fontColor(this.selectionLimitReached ?
            $r('app.color.error_text') : $r('app.color.text_tertiary'))
          .layoutWeight(1)

        Button($r('app.string.chart_select_all'))
          .height(28)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.action'))
          .backgroundColor($r('app.color.action_surface'))
          .borderRadius(8)
          .enabled(this.chart.selectedCount() < this.chart.series.length)
          .opacity(this.chart.selectedCount() < this.chart.series.length ? 1 : 0.45)
          .onClick(() => {
            const previousCount = this.chart.selectedCount()
            this.selectionLimitReached = this.chart.selectAllSeries()
            if (this.chart.selectedCount() !== previousCount) this.markMetricSelectionChanged()
          })

        Button($r('app.string.chart_deselect_all'))
          .height(28)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.action'))
          .backgroundColor($r('app.color.action_surface'))
          .borderRadius(8)
          .enabled(this.chart.selectedCount() > 0)
          .opacity(this.chart.selectedCount() > 0 ? 1 : 0.45)
          .onClick(() => {
            this.chart.deselectAllSeries()
            this.selectionLimitReached = false
            this.markMetricSelectionChanged()
          })
      }
      .width('100%')

      List({ space: 2 }) {
        ForEach(this.filteredSeries(), (series: MetricChartSeries) => {
          ListItem() {
            MetricChartChoice({
              series: series,
              limitReached: this.chart.selectedCount() >= MAX_SELECTED_METRIC_SERIES && !series.selected,
              onToggle: () => {
                const changed = this.chart.toggleSeries(series.key)
                this.selectionLimitReached = !changed && !series.selected
                if (changed) this.markMetricSelectionChanged()
              }
            })
          }
        }, (series: MetricChartSeries) => series.key)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 18, right: 18, top: 8, bottom: 14 })
  }

  @Builder
  private rangeControl() {
    Select(this.rangeOptions())
      .selected(this.selectedRangeIndex())
      .value(this.rangeLabel(this.chart.range))
      .height(32)
      .constraintSize({ minHeight: 32, maxHeight: 32 })
      .font({ size: 12, weight: FontWeight.Medium })
      .fontColor($r('app.color.action'))
      .selectedOptionBgColor($r('app.color.action_surface'))
      .selectedOptionFontColor($r('app.color.action'))
      .optionBgColor($r('app.color.surface'))
      .optionFontColor($r('app.color.text_primary'))
      .menuBackgroundColor($r('app.color.surface'))
      .menuBackgroundBlurStyle(BlurStyle.NONE)
      .backgroundColor($r('app.color.action_surface'))
      .borderRadius(9)
      .onSelect((index: number) => {
        this.dismissInspection()
        if (index >= 0 && index < METRIC_CHART_RANGES.length) {
          const range = METRIC_CHART_RANGES[index]
          if (this.chart.range !== range) this.onRangeChange(range)
        }
      })
  }

  private filteredSeries(): MetricChartSeries[] {
    const query = this.metricFilter.trim().toLocaleLowerCase()
    if (query.length === 0) return this.chart.series
    return this.chart.series.filter((series: MetricChartSeries) =>
      series.label.toLocaleLowerCase().includes(query))
  }

  private dismissInspection(): void {
    this.inspectionDismissToken += 1
  }

  private markMetricSelectionChanged(): void {
    this.metricSelectionDirty = true
    this.onSelectionChange(this.chart.selectedKeys())
  }

  private commitMetricSelection(): void {
    if (!this.metricSelectionDirty) return
    this.metricSelectionDirty = false
    this.onSelectionCommit(this.chart.selectedKeys())
  }

  private onCardClick(event: ClickEvent): void {
    if (!this.cardAreaReady || !this.plotAreaReady) {
      this.dismissInspection()
      return
    }
    const plotLeft = this.plotGlobalLeft - this.cardGlobalLeft
    const plotTop = this.plotGlobalTop - this.cardGlobalTop
    const insidePlot = event.x >= plotLeft && event.x <= plotLeft + this.plotWidth &&
      event.y >= plotTop && event.y <= plotTop + this.plotHeight
    if (!insidePlot) this.dismissInspection()
  }

  private areaLength(length: Length | undefined): number {
    if (typeof length === 'number') return length
    if (typeof length === 'string') {
      const parsed = Number.parseFloat(length)
      if (Number.isFinite(parsed)) return parsed
    }
    return 0
  }

  private rangeLabel(range: MetricChartRange): string {
    switch (range) {
      case MetricChartRange.LIVE: return 'Live'
      case MetricChartRange.HOUR_1: return '1h'
      case MetricChartRange.HOUR_12: return '12h'
      case MetricChartRange.DAY_1: return '1d'
      case MetricChartRange.DAY_7: return '7d'
      case MetricChartRange.DAY_30: return '30d'
      default: return '1h'
    }
  }

  private rangeOptions(): SelectOption[] {
    return METRIC_CHART_RANGES.map((range: MetricChartRange): SelectOption => {
      return { value: this.rangeLabel(range) }
    })
  }

  private selectedRangeIndex(): number {
    const index = METRIC_CHART_RANGES.indexOf(this.chart.range)
    return index >= 0 ? index : 1
  }

  private rangeDescription(): ResourceStr {
    switch (this.chart.range) {
      case MetricChartRange.LIVE: return $r('app.string.chart_range_live_description')
      case MetricChartRange.HOUR_1: return $r('app.string.chart_range_1h_description')
      case MetricChartRange.HOUR_12: return $r('app.string.chart_range_12h_description')
      case MetricChartRange.DAY_1: return $r('app.string.chart_range_1d_description')
      case MetricChartRange.DAY_7: return $r('app.string.chart_range_7d_description')
      case MetricChartRange.DAY_30: return $r('app.string.chart_range_30d_description')
      default: return $r('app.string.chart_range_1h_description')
    }
  }
}
