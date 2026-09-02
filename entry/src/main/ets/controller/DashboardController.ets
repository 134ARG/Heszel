import { BeszelApiError, BeszelClient } from '../api/BeszelClient'
import {
  BeszelRealtimeClient,
  BeszelRealtimeMetrics,
  BeszelSystemRealtimeEvent
} from '../api/BeszelRealtimeClient'
import { common, ConfigurationConstant } from '@kit.AbilityKit'
import {
  AppColorMode,
  CpuChartHeight,
  MetricChartHeight,
  MetricInspectionSort
} from '../model/AppearanceModels'
import { BeszelSession, SystemSummary } from '../model/BeszelModels'
import { ConnectionMode, ConnectionPhase, ConnectionProfile, LoginRequest } from '../model/ConnectionModels'
import {
  chartRangeRecordType,
  MetricChartRange
} from '../model/MetricChartModels'
import { MetricChartPanelState, MetricChartsState } from '../model/MetricChartsModels'
import {
  MetricChartKind,
  MetricChartLabels,
  MetricChartPanelKind
} from '../model/MetricChartSource'
import {
  BeszelSystemStatsWire,
  SystemDetailState
} from '../model/SystemDetailModels'
import { SessionRepository, StoredSession } from '../repository/SessionRepository'
import { WidgetSnapshotRepository } from '../repository/WidgetSnapshotRepository'
import { settleWithin } from '../service/AsyncDeadline'
import { ConnectionRuntimeService } from '../service/ConnectionRuntimeService'
import { IrohPairingCodec } from '../service/IrohPairingCodec'
import { SessionRefreshService } from '../service/SessionRefreshService'
import { LoadedSystemDetail, SystemDetailLoader } from '../service/SystemDetailLoader'
import { SystemRefreshService } from '../service/SystemRefreshService'

const DETAIL_CACHE_LIMIT = 10
const SELECTION_PERSIST_DELAY_MS = 750
const METRIC_HISTORY_RANGES: MetricChartRange[] = [
  MetricChartRange.HOUR_1,
  MetricChartRange.HOUR_12,
  MetricChartRange.DAY_1,
  MetricChartRange.DAY_7,
  MetricChartRange.DAY_30
]
// Every resume step is individually bounded by request timeouts; this watchdog
// only exists to abandon a resume wedged in native or storage calls so later
// resumes are not queued behind it forever.
const RESUME_DEADLINE_MS = 120000

class MetricChartHistoryTarget {
  kind: MetricChartPanelKind
  sequence: number

  constructor(kind: MetricChartPanelKind, sequence: number) {
    this.kind = kind
    this.sequence = sequence
  }
}

@Observed
export class DashboardController {
  session: BeszelSession = new BeszelSession()
  systems: SystemSummary[] = []
  selectedId: string = ''
  signingIn: boolean = false
  refreshing: boolean = false
  loginError: string = ''
  dashboardError: string = ''
  lastRefresh: string = ''
  detailVisible: boolean = false
  detailState: SystemDetailState = new SystemDetailState()
  liveMetrics: boolean = false
  updateWhileScrolling: boolean = false
  colorMode: AppColorMode = AppColorMode.SYSTEM
  cpuChartHeight: CpuChartHeight = CpuChartHeight.DEFAULT
  metricChartHeight: MetricChartHeight = MetricChartHeight.DEFAULT
  metricInspectionSort: MetricInspectionSort = MetricInspectionSort.VALUE
  metricChartsState: MetricChartsState = new MetricChartsState()
  chartLiveActive: boolean = false
  realtimeConnected: boolean = false
  connectionPhase: ConnectionPhase = ConnectionPhase.STOPPED
  restoringSession: boolean = true
  savedServerUrl: string = ''
  savedEmail: string = ''
  savedGatewayKey: string = ''
  savedConnectionMode: ConnectionMode = ConnectionMode.HTTP
  savedIrohPairingJson: string = ''
  private context: common.Context | null = null
  private sessionRepository: SessionRepository | null = null
  private widgetRepository: WidgetSnapshotRepository | null = null
  private client: BeszelClient | null = null
  private realtimeClient: BeszelRealtimeClient | null = null
  private connectionRuntime: ConnectionRuntimeService | null = null
  private connectionProfile: ConnectionProfile = new ConnectionProfile()
  private connectionResumeTask: Promise<void> | null = null
  private connectionResetTask: Promise<void> | null = null
  private pageVisible: boolean = false
  private detailScrolling: boolean = false
  private refreshInFlight: boolean = false
  private manualRefreshPending: boolean = false
  private sessionRefreshPending: boolean = false
  private detailStates: Map<string, SystemDetailState> = new Map<string, SystemDetailState>()
  private selectionPersistTimer: number = -1
  private selectionPersistTask: Promise<void> | null = null
  private pendingSelectedId: string = ''
  private lastPersistedSelectedId: string = ''
  private sessionRefreshService: SessionRefreshService = new SessionRefreshService()
  private manualRefreshService: SystemRefreshService | null = null
  private pendingGatewayClient: BeszelClient | null = null
  private dataGeneration: number = 0
  private detailLoadSequence: number = 0
  private detailLoadTokens: Map<string, number> = new Map<string, number>()
  private detailLoader: SystemDetailLoader = new SystemDetailLoader()

  aboutToAppear(context: common.Context): void {
    this.context = context
    this.restoreSession()
  }

  onPageShow(): void {
    this.pageVisible = true
    if (this.session.token.length > 0) {
      this.resumeConnection()
    }
  }

  onPageHide(): void {
    this.pageVisible = false
    this.flushSelectedId()
    this.invalidateDataWork()
    this.stopRealtime()
    this.stopBackgroundConnection()
  }

  aboutToDisappear(): void {
    this.pageVisible = false
    this.invalidateDataWork()
    this.stopRealtime()
    this.stopBackgroundConnection()
  }

  selectSystem(id: string): void {
    if (this.selectedId === id) {
      return
    }
    this.selectedId = id
    this.onSelectedIdChanged()
  }

  setLiveMetrics(enabled: boolean): void {
    if (this.metricChartsState.active) {
      // A header toggle is a deliberate preference change, unlike the
      // temporary enable performed by selecting the Live chart range.
      this.metricChartsState.entryLiveEnabled = enabled
      if (!enabled && this.metricChartsState.hasLivePanel()) {
        this.liveMetrics = false
        this.metricChartsState.panels.forEach((panel: MetricChartPanelState) => {
          if (panel.chart.range === MetricChartRange.LIVE) {
            panel.setRange(panel.lastHistoricalRange, Date.now())
          }
        })
        this.updateMetricChartLiveState()
        this.loadMetricChartHistories()
        return
      }
    }
    this.liveMetrics = enabled
    this.onLiveMetricsChanged()
  }

  openMetricCharts(kind: MetricChartKind): void {
    if (this.selectedId.length === 0) return
    const system = this.systems.find((candidate: SystemSummary) => candidate.id === this.selectedId)
    this.metricChartsState.begin(kind, this.selectedId, system?.name ?? '', this.liveMetrics,
      this.detailState, this.metricChartLabels())
    const repository = this.sessionRepository
    if (repository !== null) {
      this.metricChartsState.panels.forEach((panel: MetricChartPanelState) => {
        const selectedKeys = repository.metricChartSelection(this.selectedId, panel.kind)
        if (selectedKeys !== null) panel.restoreSelection(selectedKeys)
      })
    }
    this.loadMetricChartHistories()
  }

  setMetricChartsVisible(visible: boolean): void {
    if (!this.metricChartsState.active) return
    this.metricChartsState.visible = visible
    this.updateMetricChartLiveState()
  }

  setMetricChartRange(kind: MetricChartPanelKind, range: MetricChartRange): void {
    if (!this.metricChartsState.active) return
    const sequence = this.metricChartsState.setPanelRange(kind, range)
    if (sequence < 0) return
    this.updateMetricChartLiveState()
    if (range === MetricChartRange.LIVE) {
      return
    }
    this.loadMetricChartHistory(range, [new MetricChartHistoryTarget(kind, sequence)])
  }

  async saveMetricChartSelection(kind: MetricChartPanelKind, selectedKeys: string[]): Promise<void> {
    const repository = this.sessionRepository
    const systemId = this.metricChartsState.systemId
    if (repository === null || systemId.length === 0) return
    try {
      await repository.saveMetricChartSelection(systemId, kind, selectedKeys)
    } catch (_) {
      this.dashboardError = this.localized(
        'error_save_metric_chart_selection', 'Unable to save the metric chart selection.')
    }
  }

  closeMetricCharts(): void {
    if (!this.metricChartsState.active) return
    const restoreLive = this.metricChartsState.entryLiveEnabled
    this.chartLiveActive = false
    this.liveMetrics = restoreLive
    this.metricChartsState.close()
    this.syncMetricSubscription()
  }

  liveSamplingActive(): boolean {
    return this.liveMetrics && this.realtimeConnected && (this.detailIsVisible() || this.chartLiveActive)
  }

  setDetailVisible(visible: boolean): void {
    this.detailVisible = visible
    if (!visible) {
      this.detailScrolling = false
    }
    this.onDetailContextChanged()
  }

  setDetailScrolling(scrolling: boolean): void {
    this.detailScrolling = scrolling
  }

  setChartsScrolling(scrolling: boolean): void {
    this.detailScrolling = scrolling
    this.metricChartsState.setLivePaused(scrolling)
  }

  async login(request: LoginRequest): Promise<void> {
    this.loginError = ''
    const profile = request.toConnectionProfile()
    if (!profile.canConnect() || request.email.trim().length === 0 || request.password.length === 0) {
      this.loginError = profile.mode === ConnectionMode.IROH ?
        this.localized('error_enter_iroh_credentials', 'Scan an Iroh pairing QR code and enter your email and password.') :
        this.localized('error_enter_credentials', 'Enter the hub address, email, and password.')
      return
    }

    this.signingIn = true
    this.connectionPhase = ConnectionPhase.CONNECTING
    const generation = this.dataGeneration
    let client: BeszelClient | null = null
    try {
      const activeBaseUrl = await this.openConnection(profile)
      if (!this.isDataWorkCurrent(generation)) {
        await this.closeConnection(profile.mode)
        return
      }
      const loginClient = new BeszelClient(activeBaseUrl, profile.gatewayKey)
      client = loginClient
      this.client = loginClient
      const session = await loginClient.login(request.email, request.password)
      if (!this.isDataWorkCurrent(generation)) {
        if (this.client === loginClient) {
          this.client = null
        }
        await this.closeConnection(profile.mode)
        return
      }
      this.markRestSuccess()
      this.connectionProfile = profile
      this.session = session
      this.sessionRefreshPending = false
      this.savedConnectionMode = profile.mode
      this.savedServerUrl = profile.httpBaseUrl
      this.savedEmail = session.email
      this.savedGatewayKey = profile.gatewayKey
      this.savedIrohPairingJson = IrohPairingCodec.stringify(profile.iroh)
      this.systems = []
      this.selectSystem('')
      this.clearDetailStates()
      await this.persistSession(session)
      if (!this.isDataWorkCurrent(generation)) {
        return
      }
      const refreshed = await this.refreshSystems(true)
      if (refreshed && this.pageVisible && this.session.token.length > 0) {
        this.startRealtime()
      }
    } catch (error) {
      if (!this.isDataWorkCurrent(generation)) {
        if (client !== null && this.client === client) {
          this.client = null
        }
        return
      }
      if (client !== null && this.client === client) {
        this.client = null
      }
      await this.closeConnection(profile.mode)
      this.connectionPhase = ConnectionPhase.STOPPED
      this.loginError = this.describeError(error,
        this.localized('error_connect_beszel', 'Unable to connect to Beszel.'))
    } finally {
      this.signingIn = false
    }
  }

  private async refreshSystems(showLoading: boolean, retryPendingSession: boolean = true): Promise<boolean> {
    const client = this.client
    if (client === null || this.session.token.length === 0) {
      return false
    }
    const generation = this.dataGeneration
    if (this.refreshInFlight) {
      if (showLoading) {
        this.manualRefreshPending = true
        this.refreshing = true
      }
      return false
    }

    this.refreshInFlight = true
    if (showLoading) {
      this.refreshing = true
    }
    this.dashboardError = ''
    try {
      if (retryPendingSession && this.sessionRefreshPending) {
        const sessionReady = await this.retrySessionRefresh(generation)
        if (!sessionReady) {
          return false
        }
      }

      const incomingSystems = await this.executeAuthenticated(
        (activeSession: BeszelSession) => client.listSystems(activeSession.token),
        generation
      )
      if (!this.isDataWorkCurrent(generation)) {
        return false
      }
      const systems = this.reconcileSystems(incomingSystems)
      this.systems = systems
      if (systems.length > 0 && !systems.some((system: SystemSummary) => system.id === this.selectedId)) {
        this.selectSystem(systems[0].id)
      }
      this.syncSelectedDetailSummary()
      this.lastRefresh = new Date().toLocaleTimeString()
      await this.publishWidgetSnapshot()
      if (this.realtimeClient !== null && !this.realtimeConnected) {
        this.realtimeClient.retryNow()
      }
      return true
    } catch (error) {
      if (!this.isDataWorkCurrent(generation)) {
        return false
      }
      if (this.isSessionRejected(error)) {
        await this.expireSavedSession()
        return false
      }
      this.dashboardError = this.describeError(error,
        this.localized('error_refresh_systems', 'Unable to refresh systems.'))
      return false
    } finally {
      if (this.isDataWorkCurrent(generation)) {
        this.refreshInFlight = false
        if (this.manualRefreshPending && this.client !== null && this.session.token.length > 0) {
          this.manualRefreshPending = false
          await this.performManualRefresh()
        } else {
          this.manualRefreshPending = false
          this.refreshing = false
        }
      }
    }
  }

  private reconcileSystems(incoming: SystemSummary[]): SystemSummary[] {
    const existingById = new Map<string, SystemSummary>()
    this.systems.forEach((system: SystemSummary) => {
      existingById.set(system.id, system)
    })

    const reconciled: SystemSummary[] = []
    incoming.forEach((fresh: SystemSummary) => {
      const existing = existingById.get(fresh.id)
      if (existing === undefined) {
        reconciled.push(fresh)
        return
      }

      existing.updateFrom(fresh)
      reconciled.push(existing)
    })
    return reconciled
  }

  private async resumeData(): Promise<void> {
    const refreshed = await this.refreshSystems(false)
    if (!refreshed) {
      return
    }
    if (this.pageVisible && this.detailIsVisible()) {
      this.loadSelectedDetail()
    }
    if (this.pageVisible && this.session.token.length > 0) {
      this.startRealtime()
    }
    if (this.pageVisible && this.metricChartsState.active && this.metricChartsState.visible) {
      this.reloadMetricChartHistories()
    }
  }

  private startRealtime(): void {
    if (!this.pageVisible || this.session.token.length === 0) {
      return
    }
    this.stopRealtime()
    let realtime: BeszelRealtimeClient | null = null
    realtime = new BeszelRealtimeClient(
      this.session.baseUrl,
      this.session.token,
      this.session.gatewayKey,
      (event: BeszelSystemRealtimeEvent) => this.handleSystemRealtimeEvent(event),
      (systemId: string, metrics: BeszelRealtimeMetrics) => this.handleRealtimeMetrics(systemId, metrics),
      (connected: boolean) => {
        if (this.realtimeClient !== realtime) {
          return
        }
        this.realtimeConnected = connected
        if (connected) {
          if (this.connectionPhase !== ConnectionPhase.OFFLINE &&
            this.connectionPhase !== ConnectionPhase.RECOVERING &&
            this.connectionPhase !== ConnectionPhase.STOPPED) {
            this.connectionPhase = ConnectionPhase.READY
            this.dashboardError = ''
          }
        } else if (this.connectionPhase !== ConnectionPhase.OFFLINE &&
          this.connectionPhase !== ConnectionPhase.RECOVERING &&
          this.connectionPhase !== ConnectionPhase.STOPPED) {
          this.connectionPhase = ConnectionPhase.DEGRADED
        }
      },
      (error: Error) => {
        if (this.realtimeClient === realtime && this.pageVisible && this.session.token.length > 0) {
          if (this.connectionPhase !== ConnectionPhase.OFFLINE &&
            this.connectionPhase !== ConnectionPhase.RECOVERING) {
            this.connectionPhase = ConnectionPhase.DEGRADED
          }
          this.dashboardError = this.localized(
            'error_refresh_available', `${error.message} Refresh remains available.`, error.message)
        }
      }
    )
    this.realtimeClient = realtime
    realtime.connect()
    this.syncMetricSubscription()
  }

  private stopRealtime(): void {
    if (this.realtimeClient !== null) {
      const realtime = this.realtimeClient
      this.realtimeClient = null
      realtime.disconnect()
    }
    this.realtimeConnected = false
  }

  private handleSystemRealtimeEvent(event: BeszelSystemRealtimeEvent): void {
    if (event.action === 'delete') {
      this.systems = this.systems.filter((system: SystemSummary) => system.id !== event.record.id)
      this.detailStates.delete(event.record.id)
    } else if (event.action === 'create' || event.action === 'update') {
      const fresh = SystemSummary.fromWire(event.record)
      const existing = this.systems.find((system: SystemSummary) => system.id === fresh.id)
      if (existing === undefined) {
        const next = this.systems.slice()
        next.push(fresh)
        this.systems = this.sortSystems(next)
      } else {
        // Cards observe field mutations directly. Status also affects array-level
        // bindings and sort order, so publish a sorted copy only when it changes.
        if (existing.updateFrom(fresh)) {
          this.systems = this.sortSystems(this.systems.slice())
        }
      }
      if (!(this.liveMetrics && this.realtimeConnected) && event.record.info?.cpu !== undefined) {
        this.detailStates.get(event.record.id)?.appendCpuSample(event.record.info.cpu)
      }
    } else {
      return
    }

    if (this.systems.length > 0 && !this.systems.some((system: SystemSummary) => system.id === this.selectedId)) {
      this.selectSystem(this.systems[0].id)
    } else if (this.systems.length === 0) {
      this.selectSystem('')
    }
    if (event.record.id === this.selectedId || this.detailState.systemId !== this.selectedId) {
      this.syncSelectedDetailSummary()
    }
    this.lastRefresh = new Date().toLocaleTimeString()
  }

  private sortSystems(systems: SystemSummary[]): SystemSummary[] {
    systems.sort((left: SystemSummary, right: SystemSummary) => {
      if (left.isUp() !== right.isUp()) {
        return left.isUp() ? 1 : -1
      }
      return left.name.localeCompare(right.name)
    })
    return systems
  }

  private handleRealtimeMetrics(systemId: string, metrics: BeszelRealtimeMetrics): void {
    // Charts buffer internally while their view scrolls, so live samples keep
    // flowing (with arrival timestamps) even when the rest of the tick is gated.
    if (this.metricChartsState.active && this.metricChartsState.systemId === systemId) {
      this.metricChartsState.appendRealtime(metrics.stats)
    }
    if (this.detailScrolling && !this.updateWhileScrolling) {
      return
    }
    const system = this.systems.find((candidate: SystemSummary) => candidate.id === systemId)
    if (system !== undefined && metrics.info !== undefined) {
      system.updateCardMetrics(metrics.info)
    }

    const detail = this.detailStates.get(systemId)
    if (detail !== undefined) {
      detail.applyRealtime(metrics.info, metrics.stats, metrics.container)
      detail.appendRealtimeCpu(metrics.info, metrics.stats)
    }
  }

  refresh(): void {
    if (this.session.token.length === 0) {
      return
    }
    if (this.connectionPhase === ConnectionPhase.RECOVERING) {
      return
    }
    if (this.connectionPhase === ConnectionPhase.OFFLINE || this.client === null) {
      this.resetOfflineConnection()
      return
    }
    if (this.refreshInFlight) {
      this.manualRefreshPending = true
      this.refreshing = true
      return
    }
    this.performManualRefresh()
  }

  private async resetOfflineConnection(): Promise<void> {
    if (this.connectionResetTask !== null) {
      await this.connectionResetTask
      return
    }
    const task = this.performConnectionReset()
    this.connectionResetTask = task
    try {
      await task
    } finally {
      if (this.connectionResetTask === task) {
        this.connectionResetTask = null
      }
    }
  }

  private async performConnectionReset(): Promise<void> {
    if (!this.pageVisible || this.session.token.length === 0) {
      return
    }

    const email = this.session.email
    const token = this.session.token
    this.connectionPhase = ConnectionPhase.RECOVERING
    this.invalidateDataWork()
    const generation = this.dataGeneration
    this.refreshing = true
    this.dashboardError = ''
    this.stopRealtime()
    this.client = null

    try {
      await this.closeConnection(this.connectionProfile.mode)
      if (!this.pageVisible || !this.isDataWorkCurrent(generation)) {
        return
      }
      const activeBaseUrl = await this.openConnection(this.connectionProfile)
      if (!this.pageVisible || !this.isDataWorkCurrent(generation)) {
        await this.closeConnection(this.connectionProfile.mode)
        return
      }

      const resumed = new BeszelSession()
      resumed.baseUrl = activeBaseUrl
      resumed.email = email
      resumed.token = token
      resumed.gatewayKey = this.connectionProfile.gatewayKey
      this.session = resumed
      this.client = new BeszelClient(activeBaseUrl, resumed.gatewayKey)

      const refreshed = await this.refreshSystems(true)
      if (!refreshed || !this.isDataWorkCurrent(generation) || this.client === null) {
        if (this.session.token.length > 0 && this.isDataWorkCurrent(generation)) {
          this.connectionPhase = ConnectionPhase.OFFLINE
          this.client = null
          await this.closeConnection(this.connectionProfile.mode)
        }
        return
      }

      const detail = this.detailStates.get(this.selectedId)
      if (detail !== undefined) {
        detail.loaded = false
        detail.errorMessage = ''
      }
      if (this.detailIsVisible()) {
        await this.loadSelectedDetail()
      }
      if (this.pageVisible && !this.connectionIsOffline()) {
        this.startRealtime()
      }
    } catch (error) {
      if (this.pageVisible && this.isDataWorkCurrent(generation)) {
        this.markRestFailure(error)
        this.client = null
        await this.closeConnection(this.connectionProfile.mode)
        this.dashboardError = this.describeError(error,
          this.localized('error_refresh_systems', 'Unable to reconnect to Beszel.'))
      }
    } finally {
      if (this.isDataWorkCurrent(generation)) {
        this.refreshing = false
      }
    }
  }

  private async performManualRefresh(): Promise<void> {
    const client = this.client
    if (client === null || this.session.token.length === 0) {
      return
    }
    const generation = this.dataGeneration
    const refreshService = new SystemRefreshService()
    this.manualRefreshService = refreshService
    this.refreshInFlight = true
    this.refreshing = true
    this.dashboardError = ''
    const requestedSystemId = this.selectedId
    try {
      if (this.sessionRefreshPending) {
        const sessionReady = await this.retrySessionRefresh(generation)
        if (!sessionReady || this.client === null) {
          return
        }
      }
      const alreadyReceivingMetrics = this.liveSamplingActive()
      const detailLoaded = this.detailStates.get(requestedSystemId)?.loaded === true
      const result = await this.executeAuthenticated(
        (activeSession: BeszelSession) => refreshService.refresh(
          client,
          activeSession,
          requestedSystemId,
          !alreadyReceivingMetrics,
          detailLoaded
        ),
        generation
      )
      if (!this.isDataWorkCurrent(generation)) {
        return
      }
      this.systems = this.reconcileSystems(result.systems)
      if (this.systems.length > 0 &&
        !this.systems.some((system: SystemSummary) => system.id === this.selectedId)) {
        this.selectSystem(this.systems[0].id)
      }
      if (result.metrics !== null) {
        const detail = this.detailStates.get(requestedSystemId)
        if (detail !== undefined) {
          if (result.statsHistory !== null && result.statsHistory.length > 0) {
            detail.seedCpuTrend(result.statsHistory)
          }
          detail.applyRealtime(result.metrics.info, result.metrics.stats, result.metrics.container)
        }
      } else if (result.statsHistory !== null && result.statsHistory.length > 0) {
        this.detailStates.get(requestedSystemId)?.seedCpuTrend(result.statsHistory)
      }
      if (result.smartDevices !== null) {
        const detail = this.detailStates.get(requestedSystemId)
        if (detail !== undefined) {
          detail.applySmartDevices(result.smartDevices)
        }
      }
      this.lastRefresh = result.refreshedAt
      await this.publishWidgetSnapshot(requestedSystemId, result.metrics?.stats ?? null)
      if (result.metricsError !== null) {
        this.dashboardError = this.localized(
          'error_refresh_metrics_partial',
          'Systems refreshed, but fresh realtime metrics were unavailable.'
        )
      }
      if (this.realtimeClient !== null && !this.realtimeConnected) {
        this.realtimeClient.retryNow()
      }
      this.refreshVisibleCharts(requestedSystemId, result.metrics?.stats)
    } catch (error) {
      if (!this.isDataWorkCurrent(generation)) {
        return
      }
      if (this.isSessionRejected(error)) {
        await this.expireSavedSession()
        return
      }
      this.dashboardError = this.describeError(error,
        this.localized('error_refresh_systems', 'Unable to refresh systems.'))
    } finally {
      if (this.manualRefreshService === refreshService) {
        this.manualRefreshService = null
      }
      if (this.isDataWorkCurrent(generation)) {
        this.refreshInFlight = false
        if (this.manualRefreshPending && this.client !== null && this.session.token.length > 0) {
          this.manualRefreshPending = false
          await this.performManualRefresh()
        } else {
          this.manualRefreshPending = false
          this.refreshing = false
        }
      }
    }
  }

  private detailIsVisible(): boolean {
    return this.detailVisible && this.selectedId.length > 0
  }

  private refreshVisibleCharts(systemId: string, stats?: BeszelSystemStatsWire): void {
    if (this.metricChartsState.active && this.metricChartsState.visible) {
      if (this.metricChartsState.hasLivePanel() && this.metricChartsState.systemId === systemId) {
        this.metricChartsState.appendRealtime(stats)
      }
      this.reloadMetricChartHistories()
    }
  }

  private syncMetricSubscription(): void {
    if (this.liveMetrics && this.chartLiveActive) {
      const chartSystemId = this.metricChartsState.active ? this.metricChartsState.systemId : ''
      this.realtimeClient?.setMetricsSystem(chartSystemId)
    } else if (this.liveMetrics && this.detailIsVisible()) {
      this.realtimeClient?.setMetricsSystem(this.selectedId)
    } else {
      this.realtimeClient?.setMetricsSystem('')
    }
  }

  private updateMetricChartLiveState(): void {
    const liveVisible = this.metricChartsState.active && this.metricChartsState.visible &&
      this.metricChartsState.hasLivePanel()
    this.chartLiveActive = liveVisible
    this.liveMetrics = liveVisible ? true : this.metricChartsState.entryLiveEnabled
    this.syncMetricSubscription()
  }

  private reloadMetricChartHistories(): void {
    if (!this.metricChartsState.active) return
    const nowMs = Date.now()
    this.metricChartsState.panels.forEach((panel: MetricChartPanelState) => {
      if (panel.chart.range !== MetricChartRange.LIVE) {
        panel.setRange(panel.chart.range, nowMs)
      }
    })
    this.loadMetricChartHistories()
  }

  private loadMetricChartHistories(): void {
    METRIC_HISTORY_RANGES.forEach((range: MetricChartRange) => {
      const targets: MetricChartHistoryTarget[] = []
      this.metricChartsState.panels.forEach((panel: MetricChartPanelState) => {
        if (panel.chart.range === range) {
          targets.push(new MetricChartHistoryTarget(panel.kind, panel.loadSequence))
        }
      })
      if (targets.length > 0) this.loadMetricChartHistory(range, targets)
    })
  }

  private onLiveMetricsChanged(): void {
    this.syncMetricSubscription()
  }

  private onDetailContextChanged(): void {
    if (this.detailIsVisible()) {
      this.loadSelectedDetail()
    }
    this.syncMetricSubscription()
  }

  private async loadMetricChartHistory(range: MetricChartRange,
    targets: MetricChartHistoryTarget[]): Promise<void> {
    const client = this.client
    const systemId = this.metricChartsState.systemId
    if (client === null || this.session.token.length === 0 || systemId.length === 0) {
      const message = this.localized('error_load_chart_history', 'Unable to load metric history.')
      targets.forEach((target: MetricChartHistoryTarget) =>
        this.metricChartsState.failHistory(target.kind, message, range, target.sequence))
      return
    }
    const generation = this.dataGeneration
    try {
      const records = await this.executeAuthenticated(
        (activeSession: BeszelSession) => client.getSystemStatsHistoryByType(
          activeSession.token, systemId, chartRangeRecordType(range), 100),
        generation
      )
      if (!this.isDataWorkCurrent(generation)) return
      const nowMs = Date.now()
      targets.forEach((target: MetricChartHistoryTarget) =>
        this.metricChartsState.applyHistory(target.kind, records, range, target.sequence, nowMs))
    } catch (error) {
      if (!this.isDataWorkCurrent(generation)) return
      if (this.isSessionRejected(error)) {
        await this.expireSavedSession()
        return
      }
      const message = this.describeError(error,
        this.localized('error_load_chart_history', 'Unable to load metric history.'))
      targets.forEach((target: MetricChartHistoryTarget) =>
        this.metricChartsState.failHistory(target.kind, message, range, target.sequence))
    }
  }

  async signOut(): Promise<void> {
    await this.flushSelectedId()
    this.invalidateDataWork()
    this.stopRealtime()
    if (this.sessionRepository !== null) {
      try {
        await this.sessionRepository.clearToken()
      } catch (_) {
        this.dashboardError = this.localized(
          'error_remove_token', 'Unable to remove the protected session token. Please try again.')
        if (this.pageVisible && this.session.token.length > 0) {
          this.startRealtime()
        }
        return
      }
    }
    await this.closeConnection(this.connectionProfile.mode)
    this.client = null
    this.connectionPhase = ConnectionPhase.STOPPED
    this.session = new BeszelSession()
    this.sessionRefreshPending = false
    this.systems = []
    this.selectSystem('')
    this.clearDetailStates()
    this.setDetailVisible(false)
    this.setLiveMetrics(false)
    this.dashboardError = ''
    this.lastRefresh = ''
    await this.clearWidgetSnapshot()
  }

  private async restoreSession(): Promise<void> {
    const generation = this.dataGeneration
    try {
      const context = this.context
      if (context === null) {
        return
      }
      const repository = new SessionRepository(context)
      this.sessionRepository = repository
      this.connectionRuntime = new ConnectionRuntimeService(repository)
      this.widgetRepository = new WidgetSnapshotRepository(context)
      const stored = await repository.load()
      if (!this.isDataWorkCurrent(generation)) {
        return
      }
      this.savedServerUrl = stored.baseUrl
      this.savedEmail = stored.email
      this.savedGatewayKey = stored.gatewayKey
      this.savedConnectionMode = stored.connectionMode
      this.savedIrohPairingJson = IrohPairingCodec.stringify(stored.irohPairing)
      this.connectionProfile = stored.connectionProfile()
      this.updateWhileScrolling = stored.updateWhileScrolling
      this.colorMode = stored.colorMode
      this.cpuChartHeight = stored.cpuChartHeight
      this.metricChartHeight = stored.metricChartHeight
      this.metricInspectionSort = stored.metricInspectionSort
      this.applyColorMode(stored.colorMode)
      this.pendingSelectedId = stored.selectedSystemId
      this.lastPersistedSelectedId = stored.selectedSystemId
      this.selectSystem(stored.selectedSystemId)
      if (!stored.canRestore()) {
        return
      }

      this.connectionPhase = ConnectionPhase.CONNECTING
      const activeBaseUrl = await this.openConnection(this.connectionProfile)
      if (!this.isDataWorkCurrent(generation)) {
        await this.closeConnection(this.connectionProfile.mode)
        return
      }
      this.client = new BeszelClient(activeBaseUrl, this.connectionProfile.gatewayKey)
      this.session = this.toSession(stored, activeBaseUrl)
      this.sessionRefreshPending = true

      const sessionReady = await this.retrySessionRefresh(generation)
      if (sessionReady) {
        const refreshed = await this.refreshSystems(true, false)
        if (refreshed && this.pageVisible && this.session.token.length > 0) {
          this.startRealtime()
        }
      }
    } catch (error) {
      this.markRestFailure(error)
      await this.closeConnection(this.connectionProfile.mode)
      this.loginError = this.describeError(error,
        this.localized('error_restore_session', 'Unable to restore the saved session.'))
    } finally {
      this.restoringSession = false
    }
  }

  private async persistSession(session: BeszelSession): Promise<void> {
    if (this.sessionRepository === null) {
      return
    }
    try {
      await this.sessionRepository.saveSession(session, this.selectedId, this.connectionProfile)
      this.pendingSelectedId = this.selectedId
      this.lastPersistedSelectedId = this.selectedId
    } catch (_) {
      this.dashboardError = this.localized(
        'error_save_session', 'Signed in, but HarmonyOS could not save this session.')
    }
  }

  async updateScrollingPreference(enabled: boolean): Promise<void> {
    const previous = this.updateWhileScrolling
    this.updateWhileScrolling = enabled
    if (this.sessionRepository === null) {
      return
    }
    try {
      await this.sessionRepository.saveUpdateWhileScrolling(enabled)
    } catch (_) {
      if (this.updateWhileScrolling === enabled) {
        this.updateWhileScrolling = previous
      }
      this.dashboardError = this.localized(
        'error_save_settings', 'Unable to save the scrolling update preference.')
    }
  }

  async updateColorMode(mode: AppColorMode): Promise<void> {
    if (mode === this.colorMode || this.sessionRepository === null) {
      return
    }
    const previous = this.colorMode
    this.colorMode = mode
    if (!this.applyColorMode(mode)) {
      this.colorMode = previous
      this.dashboardError = this.localized('error_save_color_mode', 'Unable to save the color mode.')
      return
    }
    try {
      await this.sessionRepository.saveColorMode(mode)
    } catch (_) {
      this.colorMode = previous
      this.applyColorMode(previous)
      this.dashboardError = this.localized('error_save_color_mode', 'Unable to save the color mode.')
    }
  }

  async updateCpuChartHeight(height: CpuChartHeight): Promise<void> {
    if (height === this.cpuChartHeight || this.sessionRepository === null) {
      return
    }
    const previous = this.cpuChartHeight
    this.cpuChartHeight = height
    try {
      await this.sessionRepository.saveCpuChartHeight(height)
    } catch (_) {
      if (this.cpuChartHeight === height) {
        this.cpuChartHeight = previous
      }
      this.dashboardError = this.localized(
        'error_save_cpu_chart_height', 'Unable to save the CPU chart height preference.')
    }
  }

  async updateMetricChartHeight(height: MetricChartHeight): Promise<void> {
    if (height === this.metricChartHeight || this.sessionRepository === null) {
      return
    }
    const previous = this.metricChartHeight
    this.metricChartHeight = height
    try {
      await this.sessionRepository.saveMetricChartHeight(height)
    } catch (_) {
      if (this.metricChartHeight === height) {
        this.metricChartHeight = previous
      }
      this.dashboardError = this.localized(
        'error_save_metric_chart_height', 'Unable to save the history chart height preference.')
    }
  }

  async updateMetricInspectionSort(sort: MetricInspectionSort): Promise<void> {
    if (sort === this.metricInspectionSort || this.sessionRepository === null) {
      return
    }
    const previous = this.metricInspectionSort
    this.metricInspectionSort = sort
    try {
      await this.sessionRepository.saveMetricInspectionSort(sort)
    } catch (_) {
      if (this.metricInspectionSort === sort) {
        this.metricInspectionSort = previous
      }
      this.dashboardError = this.localized(
        'error_save_metric_inspection_sort', 'Unable to save the sample popup sorting preference.')
    }
  }

  async updateGatewayKey(value: string): Promise<void> {
    const gatewayKey = value.trim()
    if (this.connectionProfile.mode !== ConnectionMode.HTTP || gatewayKey === this.session.gatewayKey ||
      this.sessionRepository === null || this.session.token.length === 0) {
      return
    }

    const generation = this.dataGeneration
    this.refreshing = true
    this.dashboardError = ''
    const client = new BeszelClient(this.session.baseUrl, gatewayKey)
    this.pendingGatewayClient = client
    try {
      const incomingSystems = await client.listSystems(this.session.token)
      if (!this.isDataWorkCurrent(generation)) {
        return
      }
      await this.sessionRepository.saveGatewayKey(gatewayKey)
      if (!this.isDataWorkCurrent(generation)) {
        return
      }

      this.stopRealtime()
      const session = new BeszelSession()
      session.baseUrl = this.session.baseUrl
      session.email = this.session.email
      session.token = this.session.token
      session.gatewayKey = gatewayKey
      this.session = session
      this.client = client
      this.connectionProfile.gatewayKey = gatewayKey
      this.savedGatewayKey = gatewayKey
      this.systems = this.reconcileSystems(incomingSystems)
      this.lastRefresh = new Date().toLocaleTimeString()
      this.markRestSuccess()
      await this.publishWidgetSnapshot()
      if (this.pageVisible) {
        this.startRealtime()
      }
    } catch (error) {
      if (!this.isDataWorkCurrent(generation)) {
        return
      }
      this.markRestFailure(error)
      this.dashboardError = this.describeError(error,
        this.localized('error_gateway_rejected', 'The nginx gateway rejected this key.'))
    } finally {
      if (this.pendingGatewayClient === client) {
        this.pendingGatewayClient = null
      }
      if (this.isDataWorkCurrent(generation)) {
        this.refreshing = false
      }
    }
  }

  private onSelectedIdChanged(): void {
    this.selectDetailState()
    this.scheduleSelectedIdPersistence()
    this.syncMetricSubscription()
  }

  private scheduleSelectedIdPersistence(): void {
    this.pendingSelectedId = this.selectedId
    if (this.selectionPersistTimer >= 0) {
      clearTimeout(this.selectionPersistTimer)
      this.selectionPersistTimer = -1
    }
    if (this.pendingSelectedId === this.lastPersistedSelectedId) {
      return
    }
    this.selectionPersistTimer = setTimeout(() => {
      this.selectionPersistTimer = -1
      this.flushSelectedId()
    }, SELECTION_PERSIST_DELAY_MS)
  }

  private async flushSelectedId(): Promise<void> {
    if (this.selectionPersistTimer >= 0) {
      clearTimeout(this.selectionPersistTimer)
      this.selectionPersistTimer = -1
    }
    if (this.selectionPersistTask !== null) {
      await this.selectionPersistTask
      if (this.pendingSelectedId !== this.lastPersistedSelectedId) {
        await this.flushSelectedId()
      }
      return
    }
    if (this.sessionRepository === null || this.pendingSelectedId === this.lastPersistedSelectedId) {
      return
    }
    const repository = this.sessionRepository
    const task = this.persistPendingSelectedIds(repository)
    this.selectionPersistTask = task
    await task
    if (this.selectionPersistTask === task) {
      this.selectionPersistTask = null
    }
  }

  private async persistPendingSelectedIds(repository: SessionRepository): Promise<void> {
    try {
      while (this.pendingSelectedId !== this.lastPersistedSelectedId) {
        const id = this.pendingSelectedId
        await repository.saveSelectedSystem(id)
        this.lastPersistedSelectedId = id
      }
    } catch (_) {
      // Selection persistence is convenient but should never interrupt telemetry.
    }
  }

  private selectDetailState(): void {
    if (this.selectedId.length === 0) {
      this.detailState = new SystemDetailState()
      return
    }
    let state = this.detailStates.get(this.selectedId)
    if (state === undefined) {
      state = new SystemDetailState(this.selectedId)
    } else {
      this.detailStates.delete(this.selectedId)
    }
    this.detailStates.set(this.selectedId, state)
    this.trimDetailCache()
    const system = this.systems.find((candidate: SystemSummary) => candidate.id === this.selectedId)
    if (system !== undefined) {
      state.applySummary(system)
    }
    this.detailState = state
    if (this.detailVisible) {
      this.loadSelectedDetail()
    }
  }

  private syncSelectedDetailSummary(): void {
    if (this.detailState.systemId !== this.selectedId) {
      this.selectDetailState()
      return
    }
    const system = this.systems.find((candidate: SystemSummary) => candidate.id === this.selectedId)
    if (system !== undefined) {
      this.detailState.applySummary(system)
    }
  }

  private clearDetailStates(): void {
    this.detailLoadTokens.clear()
    this.detailStates.clear()
    this.detailState = new SystemDetailState()
    this.chartLiveActive = false
    this.metricChartsState.close()
  }

  private trimDetailCache(): void {
    while (this.detailStates.size > DETAIL_CACHE_LIMIT) {
      const oldestId = this.detailStates.keys().next().value as string
      this.detailStates.delete(oldestId)
    }
  }

  private async loadSelectedDetail(): Promise<void> {
    const client = this.client
    const state = this.detailState
    if (!this.pageVisible || !this.detailVisible || client === null || this.session.token.length === 0 ||
      state.systemId.length === 0 || state.loading || state.loaded) {
      return
    }

    const generation = this.dataGeneration
    const loadToken = ++this.detailLoadSequence
    this.detailLoadTokens.set(state.systemId, loadToken)
    state.loading = true
    state.errorMessage = ''
    try {
      const loaded = await this.executeAuthenticated(
        (activeSession: BeszelSession): Promise<LoadedSystemDetail> =>
          this.detailLoader.load(client, activeSession.token, state.systemId),
        generation
      )
      if (!this.isDataWorkCurrent(generation) || this.detailLoadTokens.get(state.systemId) !== loadToken) {
        return
      }
      state.applyHardware(loaded.details)
      state.seedCpuTrend(loaded.statsHistory)
      const latestStats = loaded.statsHistory.length > 0 ?
        loaded.statsHistory[loaded.statsHistory.length - 1] : null
      state.initializeCapabilities(latestStats?.stats, loaded.containers?.stats, loaded.smartDevices)
      if (latestStats !== null && latestStats.stats !== undefined && latestStats.stats !== null) {
        state.applyMetrics(latestStats.stats, loaded.containers?.stats)
      } else if (loaded.containers?.stats !== undefined && loaded.containers.stats !== null) {
        state.applyContainers(loaded.containers.stats)
      }
      state.loaded = true
    } catch (error) {
      if (!this.isDataWorkCurrent(generation) || this.detailLoadTokens.get(state.systemId) !== loadToken) {
        return
      }
      if (this.isSessionRejected(error)) {
        await this.expireSavedSession()
        return
      }
      state.errorMessage = this.describeError(error,
        this.localized('error_load_detail', 'Unable to load detailed system data.'))
    } finally {
      if (this.detailLoadTokens.get(state.systemId) === loadToken) {
        this.detailLoadTokens.delete(state.systemId)
        state.loading = false
      }
    }
  }

  private isSessionRejected(error: Object): boolean {
    return SessionRefreshService.isSessionRejected(error)
  }

  private async retrySessionRefresh(generation: number = this.dataGeneration): Promise<boolean> {
    const client = this.client
    if (client === null || !this.sessionRefreshPending) {
      return true
    }

    try {
      const refreshed = await this.sessionRefreshService.refresh(client, this.session)
      if (!this.isDataWorkCurrent(generation)) {
        return false
      }
      this.markRestSuccess()
      this.session = refreshed
      this.sessionRefreshPending = false
      await this.persistSession(refreshed)
      if (!this.isDataWorkCurrent(generation)) {
        return false
      }
      return true
    } catch (error) {
      if (!this.isDataWorkCurrent(generation)) {
        return false
      }
      if (this.isSessionRejected(error)) {
        await this.expireSavedSession()
        return false
      }

      this.markRestFailure(error)
      this.dashboardError = this.localized(
        'error_network_saved_session',
        'Beszel is unreachable. Your saved session is safe; restore the network or gateway, then retry.')
      return false
    }
  }

  private async executeAuthenticated<T>(operation: (activeSession: BeszelSession) => Promise<T>,
    generation: number = this.dataGeneration): Promise<T> {
    const client = this.client
    if (client === null || this.session.token.length === 0 || !this.isDataWorkCurrent(generation)) {
      throw new Error('No active Beszel session.')
    }
    try {
      const result = await this.sessionRefreshService.execute(
        client,
        this.session,
        operation,
        async (refreshed: BeszelSession) => {
          if (this.client !== client || this.session.token.length === 0 ||
            !this.isDataWorkCurrent(generation)) {
            throw new Error('The active Beszel session changed during refresh.')
          }
          const restartRealtime = this.pageVisible && this.realtimeClient !== null
          if (restartRealtime) {
            this.stopRealtime()
          }
          this.session = refreshed
          this.sessionRefreshPending = false
          await this.persistSession(refreshed)
          if (!this.isDataWorkCurrent(generation)) {
            throw new Error('The active Beszel session changed while it was being saved.')
          }
          if (restartRealtime) {
            this.startRealtime()
          }
        }
      )
      if (!this.isDataWorkCurrent(generation)) {
        throw new Error('The Beszel request completed after its lifecycle ended.')
      }
      this.markRestSuccess()
      return result
    } catch (error) {
      if (this.isDataWorkCurrent(generation)) {
        this.markRestFailure(error)
      }
      throw error instanceof Error ? error : new Error('The authenticated Beszel request failed.')
    }
  }

  private markRestSuccess(): void {
    if (this.connectionPhase !== ConnectionPhase.STOPPED &&
      !(this.connectionPhase === ConnectionPhase.DEGRADED && !this.realtimeConnected)) {
      this.connectionPhase = ConnectionPhase.READY
    }
  }

  private connectionIsOffline(): boolean {
    return this.connectionPhase === ConnectionPhase.OFFLINE
  }

  private markRestFailure(error: Object): void {
    if (error instanceof BeszelApiError || this.isSessionRejected(error)) {
      if (this.connectionPhase === ConnectionPhase.CONNECTING ||
        this.connectionPhase === ConnectionPhase.RECOVERING ||
        this.connectionPhase === ConnectionPhase.OFFLINE) {
        this.connectionPhase = ConnectionPhase.READY
      }
      return
    }
    if (this.connectionPhase !== ConnectionPhase.STOPPED) {
      this.connectionPhase = ConnectionPhase.OFFLINE
    }
  }

  private isDataWorkCurrent(generation: number): boolean {
    return generation === this.dataGeneration
  }

  private invalidateDataWork(): void {
    this.dataGeneration += 1
    this.client?.cancelPendingRequests()
    this.pendingGatewayClient?.cancelPendingRequests()
    this.pendingGatewayClient = null
    this.manualRefreshService?.cancel()
    this.manualRefreshService = null
    this.refreshInFlight = false
    this.manualRefreshPending = false
    this.refreshing = false
    this.detailScrolling = false
    this.detailLoadTokens.clear()
    this.detailStates.forEach((state: SystemDetailState) => {
      state.loading = false
    })
  }

  private async expireSavedSession(): Promise<void> {
    this.invalidateDataWork()
    this.stopRealtime()
    if (this.sessionRepository !== null) {
      try {
        await this.sessionRepository.clearToken()
      } catch (_) {
        // The rejected in-memory token is still discarded for this process.
      }
    }
    await this.closeConnection(this.connectionProfile.mode)
    this.client = null
    this.connectionPhase = ConnectionPhase.STOPPED
    this.session = new BeszelSession()
    this.sessionRefreshPending = false
    this.systems = []
    this.clearDetailStates()
    this.setDetailVisible(false)
    this.setLiveMetrics(false)
    this.dashboardError = ''
    this.lastRefresh = ''
    this.loginError = this.localized(
      'error_session_rejected', 'Your saved session was rejected by Beszel. Sign in again.')
    await this.clearWidgetSnapshot()
  }

  private async publishWidgetSnapshot(systemId: string = '', stats: BeszelSystemStatsWire | null = null): Promise<void> {
    if (this.widgetRepository === null) {
      return
    }
    try {
      await this.widgetRepository.saveSnapshot(this.systems, this.lastRefresh, systemId, stats)
    } catch (_) {
      // A launcher card is supplementary and must never interrupt dashboard telemetry.
    }
  }

  private async clearWidgetSnapshot(): Promise<void> {
    if (this.widgetRepository === null) {
      return
    }
    try {
      await this.widgetRepository.clearSnapshot()
    } catch (_) {
      // Sign-out and session rejection must continue even when no card host is available.
    }
  }

  private toSession(stored: StoredSession, activeBaseUrl: string): BeszelSession {
    const session = new BeszelSession()
    session.baseUrl = activeBaseUrl
    session.email = stored.email
    session.token = stored.token
    session.gatewayKey = this.connectionProfile.gatewayKey
    return session
  }

  private async openConnection(profile: ConnectionProfile): Promise<string> {
    if (this.connectionRuntime === null) {
      if (this.sessionRepository === null) {
        throw new Error('Heszel storage is not ready.')
      }
      this.connectionRuntime = new ConnectionRuntimeService(this.sessionRepository)
    }
    return this.connectionRuntime.open(profile)
  }

  private async closeConnection(mode: ConnectionMode): Promise<void> {
    if (mode !== ConnectionMode.IROH || this.connectionRuntime === null) {
      return
    }
    try {
      await this.connectionRuntime.close()
    } catch (_) {
      // Lifecycle cleanup is best effort; a later open starts from native state.
    }
  }

  private stopBackgroundConnection(): void {
    this.connectionPhase = ConnectionPhase.STOPPED
    if (this.connectionProfile.mode !== ConnectionMode.IROH) {
      return
    }
    this.client = null
    this.closeConnection(ConnectionMode.IROH)
  }

  private async resumeConnection(): Promise<void> {
    if (this.connectionResumeTask !== null) {
      const settled = await settleWithin(this.connectionResumeTask, RESUME_DEADLINE_MS)
      if (!settled) {
        this.abandonStuckResume()
      } else if (!this.pageVisible || this.session.token.length === 0 ||
        this.connectionProfile.mode === ConnectionMode.HTTP || this.client !== null) {
        return
      }
    }
    const task = this.performResumeConnection()
    this.connectionResumeTask = task
    try {
      await task
    } finally {
      if (this.connectionResumeTask === task) {
        this.connectionResumeTask = null
      }
    }
  }

  // Neutralizes a resume that never settled: its generation checks fail from
  // here on, so the zombie only ever closes the tunnel it may have opened.
  private abandonStuckResume(): void {
    this.invalidateDataWork()
    this.stopRealtime()
    this.client = null
    this.connectionResumeTask = null
    this.closeConnection(this.connectionProfile.mode)
  }

  private async performResumeConnection(): Promise<void> {
    if (!this.pageVisible || this.session.token.length === 0) {
      return
    }
    this.connectionPhase = ConnectionPhase.CONNECTING
    if (this.connectionProfile.mode === ConnectionMode.HTTP) {
      if (this.client === null) {
        this.client = new BeszelClient(this.session.baseUrl, this.session.gatewayKey)
      }
      await this.resumeData()
      return
    }

    const generation = this.dataGeneration
    try {
      const activeBaseUrl = await this.openConnection(this.connectionProfile)
      if (!this.pageVisible || !this.isDataWorkCurrent(generation)) {
        await this.closeConnection(ConnectionMode.IROH)
        return
      }
      const resumed = new BeszelSession()
      resumed.baseUrl = activeBaseUrl
      resumed.email = this.session.email
      resumed.token = this.session.token
      resumed.gatewayKey = ''
      this.session = resumed
      this.client = new BeszelClient(activeBaseUrl)
      await this.resumeData()
    } catch (error) {
      if (this.pageVisible && this.isDataWorkCurrent(generation)) {
        this.markRestFailure(error)
        this.dashboardError = this.describeError(error,
          this.localized('error_resume_iroh', 'Unable to reconnect the Iroh tunnel.'))
      }
    }
  }

  connectionLabel(): string {
    if (this.connectionProfile.mode === ConnectionMode.HTTP) {
      return this.connectionProfile.httpBaseUrl
    }
    return this.connectionProfile.iroh.displayName.length > 0 ?
      this.connectionProfile.iroh.displayName : this.localized('iroh_gateway', 'Iroh gateway')
  }

  connectionDetail(): string {
    return this.connectionProfile.mode === ConnectionMode.IROH ?
      this.connectionProfile.iroh.serverEndpointId : ''
  }

  private applyColorMode(mode: AppColorMode): boolean {
    const application = this.context?.getApplicationContext()
    if (application === undefined) {
      return false
    }
    let target = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
    if (mode === AppColorMode.DARK) {
      target = ConfigurationConstant.ColorMode.COLOR_MODE_DARK
    } else if (mode === AppColorMode.LIGHT) {
      target = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
    }
    try {
      application.setColorMode(target)
      return true
    } catch (_) {
      return false
    }
  }

  private describeError(error: Object, fallback: string): string {
    if (error instanceof Error && error.message.length > 0) {
      return error.message
    }
    return fallback
  }

  private metricChartLabels(): MetricChartLabels {
    const labels = new MetricChartLabels()
    labels.total = this.localized('chart_total', 'Total')
    labels.cpuUser = this.localized('cpu_user', 'User')
    labels.cpuSystem = this.localized('cpu_system', 'System')
    labels.cpuIoWait = this.localized('io_wait', 'I/O wait')
    labels.cpuSteal = this.localized('cpu_steal', 'Steal')
    labels.cpuCore = this.localized('chart_cpu_core', 'Core')
    labels.memoryUsed = this.localized('used', 'Used')
    labels.memoryCache = this.localized('buffer_cache', 'Buffer + cache')
    labels.memoryZfs = this.localized('metric_zfs_arc', 'ZFS ARC')
    labels.memorySwap = this.localized('swap', 'Swap')
    labels.rootFilesystem = this.localized('root_filesystem', 'Root filesystem')
    return labels
  }

  private localized(name: string, fallback: string, ...args: Array<string | number>): string {
    try {
      return this.context?.resourceManager.getStringByNameSync(name, ...args) ?? fallback
    } catch (_) {
      return fallback
    }
  }
}
