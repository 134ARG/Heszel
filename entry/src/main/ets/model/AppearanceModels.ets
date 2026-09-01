export enum AppColorMode {
  SYSTEM = 'system',
  DARK = 'dark',
  LIGHT = 'light'
}

export enum CpuChartHeight {
  COMPACT = 'compact',
  DEFAULT = 'default',
  SPACIOUS = 'spacious'
}

export function parseAppColorMode(value: string): AppColorMode {
  if (value === AppColorMode.DARK) {
    return AppColorMode.DARK
  }
  if (value === AppColorMode.LIGHT) {
    return AppColorMode.LIGHT
  }
  return AppColorMode.SYSTEM
}

export function parseCpuChartHeight(value: string): CpuChartHeight {
  if (value === CpuChartHeight.COMPACT) {
    return CpuChartHeight.COMPACT
  }
  if (value === CpuChartHeight.SPACIOUS) {
    return CpuChartHeight.SPACIOUS
  }
  return CpuChartHeight.DEFAULT
}

export function cpuChartHeightVp(value: CpuChartHeight): number {
  if (value === CpuChartHeight.COMPACT) {
    return 64
  }
  if (value === CpuChartHeight.SPACIOUS) {
    return 128
  }
  return 96
}

export enum MetricChartHeight {
  COMPACT = 'compact',
  DEFAULT = 'default',
  SPACIOUS = 'spacious'
}

export function parseMetricChartHeight(value: string): MetricChartHeight {
  if (value === MetricChartHeight.COMPACT) {
    return MetricChartHeight.COMPACT
  }
  if (value === MetricChartHeight.SPACIOUS) {
    return MetricChartHeight.SPACIOUS
  }
  return MetricChartHeight.DEFAULT
}

// Multiplies the compact/expanded base heights kept in MetricChartPanel.
export function metricChartHeightScale(value: MetricChartHeight): number {
  if (value === MetricChartHeight.COMPACT) {
    return 0.7
  }
  if (value === MetricChartHeight.SPACIOUS) {
    return 1.35
  }
  return 1
}
