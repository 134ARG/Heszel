export const PAGE_CONTENT_BOTTOM_PADDING = 10

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

export enum MetricInspectionSort {
  VALUE = 'value',
  LABEL = 'label'
}

export enum ChartLineWidth {
  THIN = 'thin',
  DEFAULT = 'default',
  THICK = 'thick'
}

export enum ChartLineOpacity {
  SOFT = 'soft',
  DEFAULT = 'default',
  SOLID = 'solid'
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

export function parseMetricInspectionSort(value: string): MetricInspectionSort {
  return value === MetricInspectionSort.LABEL ? MetricInspectionSort.LABEL : MetricInspectionSort.VALUE
}

export function parseChartLineWidth(value: string): ChartLineWidth {
  if (value === ChartLineWidth.THIN) return ChartLineWidth.THIN
  if (value === ChartLineWidth.THICK) return ChartLineWidth.THICK
  return ChartLineWidth.DEFAULT
}

export function parseChartLineOpacity(value: string): ChartLineOpacity {
  if (value === ChartLineOpacity.SOFT) return ChartLineOpacity.SOFT
  if (value === ChartLineOpacity.SOLID) return ChartLineOpacity.SOLID
  return ChartLineOpacity.DEFAULT
}

export function chartLineWidthVp(value: ChartLineWidth): number {
  if (value === ChartLineWidth.THIN) return 1
  if (value === ChartLineWidth.THICK) return 2
  return 1.5
}

export function chartLineOpacityValue(value: ChartLineOpacity): number {
  if (value === ChartLineOpacity.SOFT) return 0.5
  if (value === ChartLineOpacity.SOLID) return 1
  return 0.7
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
