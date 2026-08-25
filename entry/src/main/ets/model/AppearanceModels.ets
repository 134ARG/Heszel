export enum AppColorMode {
  SYSTEM = 'system',
  DARK = 'dark',
  LIGHT = 'light'
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
