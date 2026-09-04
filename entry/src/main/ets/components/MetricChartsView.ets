import {
  AppColorMode,
  ChartLineOpacity,
  ChartLineWidth,
  MetricChartHeight,
  MetricInspectionSort,
  PAGE_CONTENT_BOTTOM_PADDING
} from '../model/AppearanceModels'
import {
  AdaptiveMetricChartState,
  MAX_SELECTED_METRIC_SERIES,
  MetricChartRange
} from '../model/MetricChartModels'
import { MetricChartPanelState, MetricChartsState } from '../model/MetricChartsModels'
import {
  MetricChartKind,
  MetricChartPanelKind
} from '../model/MetricChartSource'
import { MetricChartPanel } from './MetricChartPanel'
import { PageHeader } from './PageHeader'

@Component
struct MetricChartPanelView {
  @ObjectLink panel: MetricChartPanelState
  @ObjectLink chart: AdaptiveMetricChartState
  @Prop compact: boolean = false
  @Prop colorMode: AppColorMode = AppColorMode.SYSTEM
  @Prop metricChartHeight: MetricChartHeight = MetricChartHeight.DEFAULT
  @Prop metricInspectionSort: MetricInspectionSort = MetricInspectionSort.VALUE
  @Prop chartLineWidth: ChartLineWidth = ChartLineWidth.DEFAULT
  @Prop chartLineOpacity: ChartLineOpacity = ChartLineOpacity.DEFAULT
  onRangeChange: (kind: MetricChartPanelKind, range: MetricChartRange) => void = () => {}
  onStackedChange: (kind: MetricChartPanelKind, stacked: boolean) => void =
    (_kind: MetricChartPanelKind, _stacked: boolean) => {}
  onSelectionCommit: (kind: MetricChartPanelKind, selectedKeys: string[]) => void =
    (_kind: MetricChartPanelKind, _selectedKeys: string[]) => {}

  build() {
    MetricChartPanel({
      chart: this.chart,
      title: this.panelTitle(),
      loading: this.panel.loading,
      errorMessage: this.panel.errorMessage,
      compact: this.compact,
      colorMode: this.colorMode,
      metricChartHeight: this.metricChartHeight,
      metricInspectionSort: this.metricInspectionSort,
      chartLineWidth: this.chartLineWidth,
      chartLineOpacity: this.chartLineOpacity,
      stackAvailable: this.panel.stackAvailable,
      stacked: this.panel.stacked,
      stackNormalize: this.panel.stackNormalize,
      stackOutlineKey: this.panel.stackOutlineKey,
      metricHint: this.sensorPanel() ?
        $r('app.string.chart_metric_hint', MAX_SELECTED_METRIC_SERIES) :
        $r('app.string.chart_metric_generic_hint', MAX_SELECTED_METRIC_SERIES),
      searchPlaceholder: this.sensorPanel() ?
        $r('app.string.chart_search_metrics') : $r('app.string.chart_search_metrics_generic'),
      onRangeChange: (range: MetricChartRange) => this.onRangeChange(this.panel.kind, range),
      onStackedChange: (stacked: boolean) => this.onStackedChange(this.panel.kind, stacked),
      onSelectionChange: (selectedKeys: string[]) => this.panel.rememberSelection(selectedKeys),
      onSelectionCommit: (selectedKeys: string[]) => this.onSelectionCommit(this.panel.kind, selectedKeys)
    })
  }

  private panelTitle(): ResourceStr {
    if (this.panel.kind === MetricChartPanelKind.HEALTH_TEMPERATURE) {
      return $r('app.string.temperature_history')
    }
    if (this.panel.kind === MetricChartPanelKind.HEALTH_HUMIDITY) return $r('app.string.humidity_history')
    if (this.panel.kind === MetricChartPanelKind.FAN_SPEED) return $r('app.string.fan_speed_history')
    if (this.panel.kind === MetricChartPanelKind.CPU_USAGE) return $r('app.string.chart_cpu_usage')
    if (this.panel.kind === MetricChartPanelKind.CPU_CORES) return $r('app.string.chart_cpu_cores')
    if (this.panel.kind === MetricChartPanelKind.MEMORY_USAGE) return $r('app.string.chart_memory_usage')
    if (this.panel.kind === MetricChartPanelKind.NETWORK_UPLOAD) return $r('app.string.upload')
    if (this.panel.kind === MetricChartPanelKind.NETWORK_DOWNLOAD) return $r('app.string.download')
    if (this.panel.kind === MetricChartPanelKind.STORAGE_USAGE) return $r('app.string.usage')
    if (this.panel.kind === MetricChartPanelKind.STORAGE_READ) return $r('app.string.read')
    if (this.panel.kind === MetricChartPanelKind.STORAGE_WRITE) return $r('app.string.write')
    if (this.panel.kind === MetricChartPanelKind.GPU_USAGE) return $r('app.string.chart_gpu_usage')
    if (this.panel.kind === MetricChartPanelKind.GPU_MEMORY) return $r('app.string.gpu_memory')
    return $r('app.string.power')
  }

  private sensorPanel(): boolean {
    return this.panel.kind === MetricChartPanelKind.HEALTH_TEMPERATURE ||
      this.panel.kind === MetricChartPanelKind.HEALTH_HUMIDITY ||
      this.panel.kind === MetricChartPanelKind.FAN_SPEED
  }
}

@Component
export struct MetricChartsView {
  @ObjectLink state: MetricChartsState
  @Prop compact: boolean = false
  @Prop colorMode: AppColorMode = AppColorMode.SYSTEM
  @Prop metricChartHeight: MetricChartHeight = MetricChartHeight.DEFAULT
  @Prop metricInspectionSort: MetricInspectionSort = MetricInspectionSort.VALUE
  @Prop chartLineWidth: ChartLineWidth = ChartLineWidth.DEFAULT
  @Prop chartLineOpacity: ChartLineOpacity = ChartLineOpacity.DEFAULT
  onBack: () => void = () => {}
  onRangeChange: (kind: MetricChartPanelKind, range: MetricChartRange) => void = () => {}
  onStackedChange: (kind: MetricChartPanelKind, stacked: boolean) => void =
    (_kind: MetricChartPanelKind, _stacked: boolean) => {}
  onSelectionCommit: (kind: MetricChartPanelKind, selectedKeys: string[]) => void =
    (_kind: MetricChartPanelKind, _selectedKeys: string[]) => {}
  onScrollingChange: (scrolling: boolean) => void = () => {}

  build() {
    Column() {
      PageHeader({
        title: this.pageTitle(),
        subtitle: this.state.systemName,
        showSubtitle: true,
        showBack: true,
        backLabel: $r('app.string.back_system_detail'),
        onBack: () => this.onBack()
      })

      // List virtualization keeps off-screen panels unmounted, so the per-second
      // live redraws only cover visible charts.
      List({ space: 14 }) {
        ForEach(this.state.panels, (panel: MetricChartPanelState) => {
          ListItem() {
            MetricChartPanelView({
              panel: panel,
              chart: panel.chart,
              compact: this.compact,
              colorMode: this.colorMode,
              metricChartHeight: this.metricChartHeight,
              metricInspectionSort: this.metricInspectionSort,
              chartLineWidth: this.chartLineWidth,
              chartLineOpacity: this.chartLineOpacity,
              onRangeChange: (kind: MetricChartPanelKind, range: MetricChartRange) =>
                this.onRangeChange(kind, range),
              onStackedChange: (kind: MetricChartPanelKind, stacked: boolean) =>
                this.onStackedChange(kind, stacked),
              onSelectionCommit: (kind: MetricChartPanelKind, selectedKeys: string[]) =>
                this.onSelectionCommit(kind, selectedKeys)
            })
          }
        }, (panel: MetricChartPanelState) => panel.kind.toString())
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .onScrollStart(() => this.onScrollingChange(true))
      .onScrollStop(() => this.onScrollingChange(false))
      .padding({
        left: this.compact ? 16 : 22,
        right: this.compact ? 16 : 22,
        top: 14,
        bottom: PAGE_CONTENT_BOTTOM_PADDING
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }

  private pageTitle(): ResourceStr {
    if (this.state.kind === MetricChartKind.HEALTH) return $r('app.string.health')
    if (this.state.kind === MetricChartKind.CPU) return $r('app.string.cpu_detail')
    if (this.state.kind === MetricChartKind.MEMORY) return $r('app.string.memory')
    if (this.state.kind === MetricChartKind.NETWORK) return $r('app.string.network')
    if (this.state.kind === MetricChartKind.STORAGE) return $r('app.string.storage')
    if (this.state.kind === MetricChartKind.FANS) return $r('app.string.fans')
    return $r('app.string.metric_gpu')
  }
}
