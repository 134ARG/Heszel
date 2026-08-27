/**
 * Waits for `task` to settle within `timeoutMs`.
 * Resolves true when the task settled (fulfilled or rejected), false on timeout.
 * The task itself keeps running; both of its settlement paths are handled so a
 * late rejection never surfaces as unhandled.
 */
export function settleWithin<T>(task: Promise<T>, timeoutMs: number): Promise<boolean> {
  return new Promise<boolean>((resolve: (settled: boolean) => void) => {
    let finished: boolean = false
    task.then(
      (): void => {
        if (finished) {
          return
        }
        finished = true
        resolve(true)
      },
      (): void => {
        if (finished) {
          return
        }
        finished = true
        resolve(true)
      }
    )
    setTimeout((): void => {
      if (finished) {
        return
      }
      finished = true
      resolve(false)
    }, timeoutMs)
  })
}
