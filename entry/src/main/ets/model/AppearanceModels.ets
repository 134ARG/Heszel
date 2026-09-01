export enum AppColorMode {
  SYSTEM = 'system',
  DARK = 'dark',
  LIGHT = 'light'
}

export enum CpuChartHeight {
  DEFAULT = 'default',
  SPACIOUS = 'spacious'
}

export enum MetricChartHeight {
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
  if (value === CpuChartHeight.SPACIOUS) {
    return CpuChartHeight.SPACIOUS
  }
  return CpuChartHeight.DEFAULT
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

export function chartHeightVp(value: CpuChartHeight | MetricChartHeight, compactLayout: boolean,
  compactBaseHeight: number = 150, expandedBaseHeight: number = 180): number {
  const baseHeight = compactLayout ? compactBaseHeight : expandedBaseHeight
  if (value === MetricChartHeight.COMPACT) {
    return baseHeight * 0.7
  }
  if (value === CpuChartHeight.SPACIOUS || value === MetricChartHeight.SPACIOUS) {
    return baseHeight * 1.35
  }
  return baseHeight
}
