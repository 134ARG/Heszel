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
