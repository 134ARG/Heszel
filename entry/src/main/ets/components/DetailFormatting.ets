export function formatBytes(value: number): string {
  if (value <= 0) {
    return '0 B'
  }
  if (value >= 1024 * 1024 * 1024) {
    return `${(value / (1024 * 1024 * 1024)).toFixed(1)} GB`
  }
  if (value >= 1024 * 1024) {
    return `${(value / (1024 * 1024)).toFixed(1)} MB`
  }
  if (value >= 1024) {
    return `${(value / 1024).toFixed(1)} KB`
  }
  return `${value.toFixed(0)} B`
}

export function formatRate(value: number): string {
  return `${formatBytes(value)}/s`
}

export function formatGigabytes(value: number): string {
  return value >= 10 ? `${value.toFixed(1)} GB` : `${value.toFixed(2)} GB`
}

export function batteryStateLabel(state: number): string {
  switch (state) {
    case 1:
      return 'Charging'
    case 2:
      return 'Discharging'
    case 3:
      return 'Full'
    default:
      return 'Battery'
  }
}
