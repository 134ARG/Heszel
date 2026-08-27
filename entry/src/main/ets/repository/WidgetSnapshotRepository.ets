import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { formBindingData, formProvider } from '@kit.FormKit'
import { resourceManager } from '@kit.LocalizationKit'
import { SystemSummary } from '../model/BeszelModels'
import { BeszelSystemStatsWire } from '../model/SystemDetailModels'

const PREFERENCES_NAME = 'heszel_widget'
const KEY_SNAPSHOT = 'systems_snapshot'
const KEY_FORMS = 'forms'
const LEGACY_KEY_FORM_IDS = 'form_ids'

function localized(resources: resourceManager.ResourceManager, name: string, fallback: string,
  ...args: Array<string | number>): string {
  try {
    return resources.getStringByNameSync(name, ...args)
  } catch (_) {
    return fallback
  }
}

class WidgetFormInstance {
  id: string = ''
  page: number = 0
}

class WidgetSystemData {
  id: string = ''
  name: string = ''
  host: string = ''
  up: string = '0'
  cpu: string = '0'
  memory: string = '0'
  disk: string = '0'
  temperature: string = '--'
  uptime: string = 'Uptime --'
  load: string = '--  --  --'
  networkDown: string = '--'
  networkUp: string = '--'
  diskRead: string = '--'
  diskWrite: string = '--'

  static fromSystem(system: SystemSummary, resources: resourceManager.ResourceManager): WidgetSystemData {
    const data = new WidgetSystemData()
    data.id = system.id
    data.name = system.name
    data.host = system.host.length > 0 ? system.host :
      localized(resources, 'widget_no_host', 'No host address')
    data.up = system.isUp() ? '1' : '0'
    data.cpu = Math.min(Math.round(system.cpuPercent), 100).toString()
    data.memory = Math.min(Math.round(system.memoryPercent), 100).toString()
    data.disk = Math.min(Math.round(system.diskPercent), 100).toString()
    data.temperature = system.temperatureCelsius > 0 ? `${Math.round(system.temperatureCelsius)}°C` : '--'
    const uptime = WidgetSystemData.formatUptime(system.uptimeSeconds)
    data.uptime = localized(resources, 'widget_uptime', `Uptime ${uptime}`, uptime)
    const load = `${system.loadOne.toFixed(2)}  ${system.loadFive.toFixed(2)}  ${system.loadFifteen.toFixed(2)}`
    data.load = localized(resources, 'widget_load', `Load ${load}`, load)
    return data
  }

  keepTraffic(previous: WidgetSystemData): void {
    this.networkDown = previous.networkDown ?? '--'
    this.networkUp = previous.networkUp ?? '--'
    this.diskRead = previous.diskRead ?? '--'
    this.diskWrite = previous.diskWrite ?? '--'
  }

  updateTraffic(stats: BeszelSystemStatsWire): void {
    if (stats.b !== undefined && stats.b !== null) {
      this.networkUp = WidgetSystemData.formatRate(stats.b[0])
      this.networkDown = WidgetSystemData.formatRate(stats.b[1])
    } else if (stats.ns !== undefined || stats.nr !== undefined) {
      this.networkUp = WidgetSystemData.formatRate(stats.ns === undefined ? undefined : stats.ns * 1048576)
      this.networkDown = WidgetSystemData.formatRate(stats.nr === undefined ? undefined : stats.nr * 1048576)
    }
    if (stats.dio !== undefined && stats.dio !== null) {
      this.diskRead = WidgetSystemData.formatRate(stats.dio[0])
      this.diskWrite = WidgetSystemData.formatRate(stats.dio[1])
    } else if (stats.dr !== undefined || stats.dw !== undefined) {
      this.diskRead = WidgetSystemData.formatRate(stats.dr === undefined ? undefined : stats.dr * 1048576)
      this.diskWrite = WidgetSystemData.formatRate(stats.dw === undefined ? undefined : stats.dw * 1048576)
    }
  }

  private static formatUptime(seconds: number): string {
    if (seconds <= 0) {
      return '--'
    }
    if (seconds < 3600) {
      return `${Math.max(1, Math.floor(seconds / 60))}m`
    }
    if (seconds < 86400) {
      return `${Math.floor(seconds / 3600)}h`
    }
    const days = Math.floor(seconds / 86400)
    const hours = Math.floor((seconds % 86400) / 3600)
    return hours > 0 ? `${days}d ${hours}h` : `${days}d`
  }

  private static formatRate(bytes: number | undefined): string {
    if (bytes === undefined || !Number.isFinite(bytes)) return '--'
    if (bytes >= 1073741824) return `${(bytes / 1073741824).toFixed(1)} GB/s`
    if (bytes >= 1048576) return `${(bytes / 1048576).toFixed(1)} MB/s`
    if (bytes >= 1024) return `${(bytes / 1024).toFixed(1)} KB/s`
    return `${Math.max(0, bytes).toFixed(0)} B/s`
  }
}

class WidgetSnapshotData {
  summary: string = 'Open Heszel to load systems'
  updated: string = 'No cached data'
  systems: WidgetSystemData[] = []

  static empty(resources: resourceManager.ResourceManager): WidgetSnapshotData {
    const data = new WidgetSnapshotData()
    data.summary = localized(resources, 'widget_open_heszel', data.summary)
    data.updated = localized(resources, 'widget_no_cached_data', data.updated)
    return data
  }

  static fromSystems(systems: SystemSummary[], updated: string,
    resources: resourceManager.ResourceManager): WidgetSnapshotData {
    const data = WidgetSnapshotData.empty(resources)
    const online = systems.filter((system: SystemSummary) => system.isUp()).length
    data.summary = localized(resources, 'systems_online', `${online} of ${systems.length} systems online`,
      online, systems.length)
    data.updated = updated.length > 0 ?
      localized(resources, 'updated', `Updated ${updated}`, updated) :
      localized(resources, 'widget_recently_updated', 'Recently updated')
    systems.forEach((system: SystemSummary) =>
      data.systems.push(WidgetSystemData.fromSystem(system, resources)))
    return data
  }

  keepTraffic(previous: WidgetSnapshotData): void {
    this.systems.forEach((system: WidgetSystemData) => {
      const old = previous.systems.find((candidate: WidgetSystemData) => candidate.id === system.id)
      if (old !== undefined) system.keepTraffic(old)
    })
  }

  updateTraffic(systemId: string, stats: BeszelSystemStatsWire | null): void {
    if (stats === null) return
    this.systems.find((system: WidgetSystemData) => system.id === systemId)?.updateTraffic(stats)
  }
}

export class WidgetFormData {
  s: string = 'Open Heszel to load systems'
  r: string = 'No cached data'
  c: string = '0'
  p: string = '0'
  n: string = ''
  h: string = ''
  u: string = '0'
  a: string = '0'
  m: string = '0'
  d: string = '0'
  t: string = '--'
  v: string = 'Uptime --'
  l: string = '--  --  --'
  nd: string = '--'
  nu: string = '--'
  dr: string = '--'
  dw: string = '--'
  q: string = '0'

  static fromSnapshot(snapshot: WidgetSnapshotData, requestedPage: number,
    refreshing: boolean = false): WidgetFormData {
    const data = new WidgetFormData()
    data.q = refreshing ? '1' : '0'
    const count = snapshot.systems.length
    const page = count > 0 ? Math.min(Math.max(0, Math.floor(requestedPage)), count - 1) : 0
    data.s = snapshot.summary
    data.r = snapshot.updated
    data.c = count.toString()
    data.p = page.toString()
    if (count === 0) {
      return data
    }
    const system = snapshot.systems[page]
    data.n = system.name
    data.h = system.host
    data.u = system.up
    data.a = system.cpu
    data.m = system.memory
    data.d = system.disk
    data.t = system.temperature
    data.v = system.uptime
    data.l = system.load
    data.nd = system.networkDown ?? '--'
    data.nu = system.networkUp ?? '--'
    data.dr = system.diskRead ?? '--'
    data.dw = system.diskWrite ?? '--'
    return data
  }
}

export class WidgetSnapshotRepository {
  private readonly context: common.Context
  private store: preferences.Preferences | null = null

  constructor(context: common.Context) {
    this.context = context
  }

  loadSync(): WidgetFormData {
    try {
      const store = preferences.getPreferencesSync(this.context, { name: PREFERENCES_NAME })
      this.store = store
      const raw = store.getSync(KEY_SNAPSHOT, '') as string
      return WidgetFormData.fromSnapshot(this.decodeSnapshot(raw), 0)
    } catch (_) {
      return new WidgetFormData()
    }
  }

  async saveSnapshot(systems: SystemSummary[], updated: string, systemId: string = '',
    stats: BeszelSystemStatsWire | null = null,
    statsBySystem: Map<string, BeszelSystemStatsWire> | null = null,
    publish: boolean = true): Promise<void> {
    try {
      const store = await this.getStore()
      const snapshot = WidgetSnapshotData.fromSystems(systems, updated, this.context.resourceManager)
      snapshot.keepTraffic(await this.readSnapshot(store))
      snapshot.updateTraffic(systemId, stats)
      if (statsBySystem !== null) {
        statsBySystem.forEach((systemStats: BeszelSystemStatsWire, id: string) => {
          snapshot.updateTraffic(id, systemStats)
        })
      }
      await store.put(KEY_SNAPSHOT, JSON.stringify(snapshot))
      await store.flush()
      if (publish) {
        await this.updateForms(store, snapshot)
      }
    } catch (error) {
      throw this.storageError(error, 'Unable to save the widget snapshot.')
    }
  }

  async clearSnapshot(): Promise<void> {
    try {
      const store = await this.getStore()
      await store.delete(KEY_SNAPSHOT)
      await store.flush()
      await this.updateForms(store, WidgetSnapshotData.empty(this.context.resourceManager))
    } catch (error) {
      throw this.storageError(error, 'Unable to clear the widget snapshot.')
    }
  }

  async setRefreshing(refreshing: boolean): Promise<void> {
    try {
      const store = await this.getStore()
      await this.updateForms(store, await this.readSnapshot(store), refreshing, false)
    } catch (error) {
      throw this.storageError(error, 'Unable to update the widget refresh state.')
    }
  }

  async addForm(formId: string): Promise<void> {
    if (formId.length === 0) {
      return
    }
    const store = await this.getStore()
    const forms = await this.readForms(store)
    if (!forms.some((form: WidgetFormInstance) => form.id === formId)) {
      const form = new WidgetFormInstance()
      form.id = formId
      forms.push(form)
      await this.writeForms(store, forms)
    }
  }

  async removeForm(formId: string): Promise<void> {
    const store = await this.getStore()
    const forms = await this.readForms(store)
    const remaining = forms.filter((form: WidgetFormInstance) => form.id !== formId)
    if (remaining.length !== forms.length) {
      await this.writeForms(store, remaining)
    }
  }

  async updateForm(formId: string): Promise<void> {
    if (formId.length === 0) {
      return
    }
    try {
      const store = await this.getStore()
      const snapshot = await this.readSnapshot(store)
      const page = await this.pageForForm(store, formId)
      await this.publish(formId, WidgetFormData.fromSnapshot(snapshot, page))
    } catch (error) {
      throw this.storageError(error, 'Unable to update the systems widget.')
    }
  }

  async updatePage(formId: string, page: number): Promise<void> {
    if (formId.length === 0) {
      return
    }
    try {
      const store = await this.getStore()
      const snapshot = await this.readSnapshot(store)
      const data = WidgetFormData.fromSnapshot(snapshot, page)
      await this.savePage(store, formId, Number(data.p))
      await this.publish(formId, data)
    } catch (error) {
      throw this.storageError(error, 'Unable to change the systems widget page.')
    }
  }

  private async updateForms(store: preferences.Preferences, snapshot: WidgetSnapshotData,
    refreshing: boolean = false, persistPages: boolean = true): Promise<void> {
    const forms = await this.readForms(store)
    for (const form of forms) {
      try {
        const data = WidgetFormData.fromSnapshot(snapshot, form.page, refreshing)
        form.page = Number(data.p)
        await this.publish(form.id, data)
      } catch (_) {
        // One stale launcher form must not block updates to the remaining instances.
      }
    }
    if (persistPages) {
      await this.writeForms(store, forms)
    }
  }

  private async publish(formId: string, data: WidgetFormData): Promise<void> {
    try {
      await formProvider.updateForm(formId, formBindingData.createFormBindingData(data))
    } catch (error) {
      throw this.storageError(error, 'Unable to publish widget data.')
    }
  }

  private async readSnapshot(store: preferences.Preferences): Promise<WidgetSnapshotData> {
    try {
      const raw = await store.get(KEY_SNAPSHOT, '') as string
      return this.decodeSnapshot(raw)
    } catch (_) {
      return new WidgetSnapshotData()
    }
  }

  private decodeSnapshot(raw: string): WidgetSnapshotData {
    if (raw.length === 0) {
      return new WidgetSnapshotData()
    }
    try {
      const wire = JSON.parse(raw) as WidgetSnapshotData
      const data = new WidgetSnapshotData()
      data.summary = wire.summary ?? data.summary
      data.updated = wire.updated ?? data.updated
      data.systems = wire.systems ?? []
      return data
    } catch (_) {
      return new WidgetSnapshotData()
    }
  }

  private async readForms(store: preferences.Preferences): Promise<WidgetFormInstance[]> {
    try {
      const raw = await store.get(KEY_FORMS, '') as string
      if (raw.length > 0) {
        return JSON.parse(raw) as WidgetFormInstance[]
      }
      const legacy = await store.get(LEGACY_KEY_FORM_IDS, '[]') as string
      const legacyIds = JSON.parse(legacy) as string[]
      const forms: WidgetFormInstance[] = []
      legacyIds.forEach((id: string) => {
        const form = new WidgetFormInstance()
        form.id = id
        forms.push(form)
      })
      return forms
    } catch (_) {
      return []
    }
  }

  private async writeForms(store: preferences.Preferences, forms: WidgetFormInstance[]): Promise<void> {
    try {
      await store.put(KEY_FORMS, JSON.stringify(forms))
      await store.flush()
    } catch (error) {
      throw this.storageError(error, 'Unable to save widget instances.')
    }
  }

  private async pageForForm(store: preferences.Preferences, formId: string): Promise<number> {
    const forms = await this.readForms(store)
    return forms.find((form: WidgetFormInstance) => form.id === formId)?.page ?? 0
  }

  private async savePage(store: preferences.Preferences, formId: string, page: number): Promise<void> {
    const forms = await this.readForms(store)
    let form = forms.find((candidate: WidgetFormInstance) => candidate.id === formId)
    if (form === undefined) {
      form = new WidgetFormInstance()
      form.id = formId
      forms.push(form)
    }
    form.page = page
    await this.writeForms(store, forms)
  }

  private async getStore(): Promise<preferences.Preferences> {
    if (this.store === null) {
      try {
        this.store = await preferences.getPreferences(this.context, PREFERENCES_NAME)
      } catch (error) {
        throw this.storageError(error, 'Unable to open widget preferences.')
      }
    }
    return this.store
  }

  private storageError(error: Object, fallback: string): Error {
    return error instanceof Error && error.message.length > 0 ? error : new Error(fallback)
  }
}
