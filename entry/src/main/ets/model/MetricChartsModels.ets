import { CpuMetricChartSource } from './CpuMetricChartSource'
import { GpuMetricChartSource } from './GpuMetricChartSource'
import { HealthMetricChartSource } from './HealthMetricChartSource'
import { MemoryMetricChartSource } from './MemoryMetricChartSource'
import {
  AdaptiveMetricChartState,
  MetricChartAxisPolicy,
  MetricChartPoint,
  MetricChartRange,
  MetricChartSeries,
  MetricChartValueFormat
} from './MetricChartModels'
import { NetworkMetricChartSource } from './NetworkMetricChartSource'
import { StorageMetricChartSource } from './StorageMetricChartSource'
import {
  MetricChartDefinition,
  MetricChartPanelDefinition,
  MetricChartKind,
  MetricChartLabels,
  MetricChartPanelKind,
  MetricChartSource
} from './MetricChartSource'
import { BeszelSystemStatsRecordWire, BeszelSystemStatsWire, SystemDetailState } from './SystemDetailModels'

@Observed
export class MetricChartPanelState {
  kind: MetricChartPanelKind = MetricChartPanelKind.CPU_USAGE
  axisPolicy: MetricChartAxisPolicy = MetricChartAxisPolicy.AUTO
  valueFormat: MetricChartValueFormat = MetricChartValueFormat.NUMBER
  unit: string = ''
  chart: AdaptiveMetricChartState = new AdaptiveMetricChartState()
  lastHistoricalRange: MetricChartRange = MetricChartRange.HOUR_1
  loading: boolean = false
  errorMessage: string = ''
  loadSequence: number = 0

  constructor(definition: MetricChartPanelDefinition) {
    this.kind = definition.kind
    this.axisPolicy = definition.axisPolicy
    this.valueFormat = definition.valueFormat
    this.unit = definition.unit
  }

  setRange(range: MetricChartRange, nowMs: number): number {
    if (range !== MetricChartRange.LIVE) this.lastHistoricalRange = range
    this.loading = range !== MetricChartRange.LIVE
    this.errorMessage = ''
    this.loadSequence += 1
    this.chart.configure(range, this.axisPolicy, this.unit, nowMs, this.valueFormat)
    this.chart.clearPoints(nowMs)
    return this.loadSequence
  }

  setInitialSeries(series: MetricChartSeries[]): void {
    this.chart.setSeries(series.map((item: MetricChartSeries) =>
      new MetricChartSeries(item.key, item.label, item.selected)))
  }
}

@Observed
class BufferedLiveSample {
  timestampMs: number = 0
  stats: BeszelSystemStatsWire

  constructor(timestampMs: number, stats: BeszelSystemStatsWire) {
    this.timestampMs = timestampMs
    this.stats = stats
  }
}

export class MetricChartsState {
  active: boolean = false
  visible: boolean = false
  kind: MetricChartKind = MetricChartKind.CPU
  systemId: string = ''
  systemName: string = ''
  entryLiveEnabled: boolean = false
  panels: MetricChartPanelState[] = []
  private labels: MetricChartLabels = new MetricChartLabels()
  private source: MetricChartSource | null = null
  private latestValues: Map<MetricChartPanelKind, Map<string, number>> =
    new Map<MetricChartPanelKind, Map<string, number>>()
  private livePaused: boolean = false
  private liveBuffer: BufferedLiveSample[] = []

  begin(kind: MetricChartKind, systemId: string, systemName: string, entryLiveEnabled: boolean,
    detail: SystemDetailState, labels: MetricChartLabels): void {
    this.active = true
    this.visible = false
    this.kind = kind
    this.systemId = systemId
    this.systemName = systemName
    this.entryLiveEnabled = entryLiveEnabled
    this.labels = labels
    this.source = this.sourceFor(kind)
    const initialSeries = this.source.initialSeries(detail, labels)
    this.panels = this.source.panelDefinitions().map((definition: MetricChartPanelDefinition) =>
      new MetricChartPanelState(definition))
    this.panels.forEach((panel: MetricChartPanelState) => panel.setInitialSeries(initialSeries))
    this.latestValues.clear()
    this.panels.forEach((panel: MetricChartPanelState) => {
      const latest = new Map<string, number>()
      panel.chart.series.forEach((item: MetricChartSeries) => {
        const value = this.source?.initialValue(panel.kind, detail, item.key) ?? Number.NaN
        if (Number.isFinite(value)) latest.set(item.key, value)
      })
      this.latestValues.set(panel.kind, latest)
    })
    const nowMs = Date.now()
    this.panels.forEach((panel: MetricChartPanelState) =>
      panel.setRange(MetricChartRange.HOUR_1, nowMs))
  }

  panel(kind: MetricChartPanelKind): MetricChartPanelState | null {
    return this.panels.find((panel: MetricChartPanelState) => panel.kind === kind) ?? null
  }

  hasLivePanel(): boolean {
    return this.panels.some((panel: MetricChartPanelState) =>
      panel.chart.range === MetricChartRange.LIVE)
  }

  setPanelRange(kind: MetricChartPanelKind, range: MetricChartRange): number {
    const panel = this.panel(kind)
    return panel !== null ? panel.setRange(range, Date.now()) : -1
  }

  applyHistory(kind: MetricChartPanelKind, records: BeszelSystemStatsRecordWire[],
    range: MetricChartRange, sequence: number, nowMs: number): void {
    const panel = this.panel(kind)
    if (!this.active || panel === null || panel.chart.range !== range ||
      panel.loadSequence !== sequence || this.source === null) return
    const definitions = this.definitionsFromRecords(records)
    const source = this.source
    this.mergeDefinitions(panel, definitions)
    const points: MetricChartPoint[] = []
    records.forEach((record: BeszelSystemStatsRecordWire) => {
      const timestamp = Date.parse(record.created ?? '')
      if (!Number.isFinite(timestamp)) return
      const values: number[] = []
      panel.chart.series.forEach((item: MetricChartSeries) => {
        const value = record.stats !== undefined && record.stats !== null ?
          source.valueFor(panel.kind, record.stats, item.key) : Number.NaN
        values.push(value)
      })
      points.push(new MetricChartPoint(timestamp, values))
    })
    points.sort((left: MetricChartPoint, right: MetricChartPoint) => left.timestampMs - right.timestampMs)
    panel.chart.replacePoints(points, nowMs)
    panel.loading = false
  }

  failHistory(kind: MetricChartPanelKind, message: string,
    range: MetricChartRange, sequence: number): void {
    const panel = this.panel(kind)
    if (!this.active || panel === null || panel.chart.range !== range || panel.loadSequence !== sequence) return
    panel.loading = false
    panel.errorMessage = message
  }

  appendRealtime(stats: BeszelSystemStatsWire | undefined): void {
    if (!this.active || !this.visible || !this.hasLivePanel()) return
    const nowMs = Date.now()
    if (this.livePaused) {
      if (stats !== undefined) {
        this.liveBuffer.push(new BufferedLiveSample(nowMs, stats))
      }
      return
    }
    this.applyRealtime(nowMs, stats)
  }

  // Pausing only parks the render path: samples keep buffering with their
  // arrival timestamps so the live window stays continuous after the flush.
  setLivePaused(paused: boolean): void {
    if (this.livePaused === paused) {
      return
    }
    this.livePaused = paused
    if (paused) {
      return
    }
    const buffered = this.liveBuffer
    this.liveBuffer = []
    buffered.forEach((entry: BufferedLiveSample) => this.applyRealtime(entry.timestampMs, entry.stats))
  }

  private applyRealtime(nowMs: number, stats: BeszelSystemStatsWire | undefined): void {
    if (!this.active || !this.visible || !this.hasLivePanel()) return
    const source = this.source
    if (stats !== undefined && source !== null) {
      const definitions: MetricChartDefinition[] = []
      source.appendDefinitions(definitions, stats, this.labels)
      this.panels.forEach((panel: MetricChartPanelState) => {
        if (panel.chart.range !== MetricChartRange.LIVE) return
        this.mergeDefinitions(panel, definitions)
        const latest = this.latestFor(panel.kind)
        panel.chart.series.forEach((item: MetricChartSeries) => {
          const value = source.valueFor(panel.kind, stats, item.key)
          if (Number.isFinite(value)) latest.set(item.key, value)
        })
      })
    }
    this.panels.forEach((panel: MetricChartPanelState) => {
      if (panel.chart.range !== MetricChartRange.LIVE) return
      const latest = this.latestFor(panel.kind)
      if (latest.size > 0) panel.chart.appendLive(nowMs, latest)
    })
  }

  close(): void {
    this.active = false
    this.visible = false
    this.livePaused = false
    this.liveBuffer = []
    this.latestValues.clear()
    this.panels.forEach((panel: MetricChartPanelState) => {
      panel.loading = false
      panel.errorMessage = ''
      panel.loadSequence += 1
      panel.chart.points = []
      panel.chart.revision += 1
    })
    this.panels = []
    this.source = null
  }

  private sourceFor(kind: MetricChartKind): MetricChartSource {
    if (kind === MetricChartKind.HEALTH) return new HealthMetricChartSource()
    if (kind === MetricChartKind.CPU) return new CpuMetricChartSource()
    if (kind === MetricChartKind.MEMORY) return new MemoryMetricChartSource()
    if (kind === MetricChartKind.NETWORK) return new NetworkMetricChartSource()
    if (kind === MetricChartKind.STORAGE) return new StorageMetricChartSource()
    return new GpuMetricChartSource()
  }

  private latestFor(kind: MetricChartPanelKind): Map<string, number> {
    let latest = this.latestValues.get(kind)
    if (latest === undefined) {
      latest = new Map<string, number>()
      this.latestValues.set(kind, latest)
    }
    return latest
  }

  private definitionsFromRecords(records: BeszelSystemStatsRecordWire[]): MetricChartDefinition[] {
    const definitions: MetricChartDefinition[] = []
    const source = this.source
    if (source === null) return definitions
    records.forEach((record: BeszelSystemStatsRecordWire) => {
      if (record.stats !== undefined && record.stats !== null) {
        source.appendDefinitions(definitions, record.stats, this.labels)
      }
    })
    return definitions
  }

  private mergeDefinitions(panel: MetricChartPanelState, definitions: MetricChartDefinition[]): void {
    let changed = false
    const next = panel.chart.series.slice()
    definitions.forEach((definition: MetricChartDefinition) => {
      const existing = next.find((item: MetricChartSeries) => item.key === definition.key)
      if (existing === undefined) {
        next.push(new MetricChartSeries(definition.key, definition.label, false))
        changed = true
      } else if (existing.label !== definition.label) {
        existing.label = definition.label
        changed = true
      }
    })
    if (!changed) return
    const addedCount = next.length - panel.chart.series.length
    if (addedCount > 0) {
      panel.chart.points.forEach((point: MetricChartPoint) => {
        const values = point.values.slice()
        for (let index = 0; index < addedCount; index += 1) values.push(Number.NaN)
        point.values = values
      })
    }
    if (!next.some((item: MetricChartSeries) => item.selected)) {
      for (let index = 0; index < Math.min(4, next.length); index += 1) next[index].selected = true
    }
    panel.chart.setSeries(next)
  }
}
