export enum MetricChartRange {
  LIVE,
  HOUR_1,
  HOUR_12,
  DAY_1,
  DAY_7,
  DAY_30
}

export enum MetricChartAxisPolicy {
  AUTO,
  ZERO_BASED,
  PERCENT
}

export enum MetricChartValueFormat {
  NUMBER,
  BYTES,
  BYTES_PER_SECOND
}

export function chartRangeDurationMs(range: MetricChartRange): number {
  switch (range) {
    case MetricChartRange.LIVE:
      return 60_000
    case MetricChartRange.HOUR_1:
      return 60 * 60_000
    case MetricChartRange.HOUR_12:
      return 12 * 60 * 60_000
    case MetricChartRange.DAY_1:
      return 24 * 60 * 60_000
    case MetricChartRange.DAY_7:
      return 7 * 24 * 60 * 60_000
    case MetricChartRange.DAY_30:
      return 30 * 24 * 60 * 60_000
    default:
      return 60 * 60_000
  }
}

export function chartRangeExpectedIntervalMs(range: MetricChartRange): number {
  switch (range) {
    case MetricChartRange.LIVE:
      // Beszel emits every second; tolerate normal delivery latency before
      // treating a later sample as a visible gap.
      return 2_000
    case MetricChartRange.HOUR_1:
      return 60_000
    case MetricChartRange.HOUR_12:
      return 10 * 60_000
    case MetricChartRange.DAY_1:
      return 20 * 60_000
    case MetricChartRange.DAY_7:
      return 120 * 60_000
    case MetricChartRange.DAY_30:
      return 480 * 60_000
    default:
      return 60_000
  }
}

export function chartRangeRecordType(range: MetricChartRange): string {
  switch (range) {
    case MetricChartRange.HOUR_1:
      return '1m'
    case MetricChartRange.HOUR_12:
      return '10m'
    case MetricChartRange.DAY_1:
      return '20m'
    case MetricChartRange.DAY_7:
      return '120m'
    case MetricChartRange.DAY_30:
      return '480m'
    default:
      return '1m'
  }
}

@Observed
export class MetricChartSeries {
  key: string = ''
  label: string = ''
  selected: boolean = false

  constructor(key: string = '', label: string = '', selected: boolean = false) {
    this.key = key
    this.label = label
    this.selected = selected
  }
}

export class MetricChartPoint {
  timestampMs: number = 0
  values: number[] = []

  constructor(timestampMs: number = 0, values: number[] = []) {
    this.timestampMs = timestampMs
    this.values = values
  }
}

@Observed
export class AdaptiveMetricChartState {
  range: MetricChartRange = MetricChartRange.HOUR_1
  axisPolicy: MetricChartAxisPolicy = MetricChartAxisPolicy.AUTO
  valueFormat: MetricChartValueFormat = MetricChartValueFormat.NUMBER
  unit: string = ''
  series: MetricChartSeries[] = []
  points: MetricChartPoint[] = []
  windowStartMs: number = 0
  windowEndMs: number = 0
  expectedIntervalMs: number = 60_000
  revision: number = 0

  configure(range: MetricChartRange, axisPolicy: MetricChartAxisPolicy, unit: string, nowMs: number,
    valueFormat: MetricChartValueFormat = MetricChartValueFormat.NUMBER): void {
    this.range = range
    this.axisPolicy = axisPolicy
    this.valueFormat = valueFormat
    this.unit = unit
    this.expectedIntervalMs = chartRangeExpectedIntervalMs(range)
    this.windowEndMs = nowMs
    this.windowStartMs = nowMs - chartRangeDurationMs(range)
    this.revision += 1
  }

  setSeries(next: MetricChartSeries[]): void {
    this.series = next
    this.revision += 1
  }

  replacePoints(points: MetricChartPoint[], nowMs: number): void {
    this.windowEndMs = nowMs
    this.windowStartMs = nowMs - chartRangeDurationMs(this.range)
    this.points = points.filter((point: MetricChartPoint) =>
      point.timestampMs >= this.windowStartMs && point.timestampMs <= this.windowEndMs)
    this.revision += 1
  }

  clearPoints(nowMs: number): void {
    this.windowEndMs = nowMs
    this.windowStartMs = nowMs - chartRangeDurationMs(this.range)
    this.points = []
    this.revision += 1
  }

  append(timestampMs: number, valuesByKey: Map<string, number>): void {
    this.ensureSeries(Array.from(valuesByKey.keys()))
    const values: number[] = []
    this.series.forEach((series: MetricChartSeries) => {
      const value = valuesByKey.get(series.key)
      values.push(value !== undefined && Number.isFinite(value) ? value : Number.NaN)
    })
    // Points arrive in ascending time; drop the expired prefix in place instead
    // of rebuilding the array on every append.
    const windowStartMs = timestampMs - chartRangeDurationMs(this.range)
    let expired = 0
    while (expired < this.points.length && this.points[expired].timestampMs <= windowStartMs) {
      expired += 1
    }
    if (expired > 0) {
      this.points.splice(0, expired)
    }
    this.points.push(new MetricChartPoint(timestampMs, values))
    this.windowEndMs = timestampMs
    this.windowStartMs = windowStartMs
    this.revision += 1
  }

  selectedCount(): number {
    return this.series.filter((series: MetricChartSeries) => series.selected).length
  }

  hasSelectedData(): boolean {
    const selectedIndices: number[] = []
    this.series.forEach((series: MetricChartSeries, index: number) => {
      if (series.selected) selectedIndices.push(index)
    })
    return this.points.some((point: MetricChartPoint) =>
      selectedIndices.some((index: number) => Number.isFinite(point.values[index])))
  }

  toggleSeries(key: string, maximumSelected: number = 6): boolean {
    const index = this.series.findIndex((series: MetricChartSeries) => series.key === key)
    if (index < 0) return false
    const target = this.series[index]
    if (!target.selected && this.selectedCount() >= maximumSelected) return false
    target.selected = !target.selected
    // Reassigning the array makes selection changes visible to both the list
    // and the canvas without rebuilding the point data.
    this.series = this.series.slice()
    this.revision += 1
    return true
  }

  private ensureSeries(keys: string[]): void {
    const missing = keys.filter((key: string) =>
      !this.series.some((series: MetricChartSeries) => series.key === key))
    if (missing.length === 0) return
    const previousLength = this.series.length
    const next = this.series.slice()
    missing.sort().forEach((key: string) => next.push(new MetricChartSeries(key, key, false)))
    this.points.forEach((point: MetricChartPoint) => {
      const values = point.values.slice()
      for (let index = previousLength; index < next.length; index += 1) values.push(Number.NaN)
      point.values = values
    })
    this.series = next
  }
}
