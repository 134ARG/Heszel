import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { display, window } from '@kit.ArkUI';

const DOMAIN = 0x0000;
const SCREEN_SIZE_KEY = 'curScreenSizeString';
const SCREEN_SIZE_SM = 'sm';
const SCREEN_SIZE_LG = 'lg';
const SCREEN_SIZE_BREAKPOINT = 600;
const WINDOW_WIDTH_KEY = 'curWindowWidthVp';

export default class EntryAbility extends UIAbility {
  private mainWindow: window.Window | null = null;
  private currentScreenSize: string = '';
  private currentWindowWidthVp: number = 0;
  private readonly windowSizeChangeCallback = (windowSize: window.Size): void => {
    this.updateWindowWidth(windowSize.width);
  };

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });

    windowStage.getMainWindow().then((mainWindow: window.Window) => {
      this.mainWindow = mainWindow;
      const windowRect = mainWindow.getWindowProperties().windowRect;
      this.updateWindowWidth(windowRect.width);
      mainWindow.on('windowSizeChange', this.windowSizeChangeCallback);
    }).catch((err: Object) => {
      hilog.error(DOMAIN, 'testTag', 'Failed to observe window size. Cause: %{public}s', JSON.stringify(err));
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    if (this.mainWindow !== null) {
      this.mainWindow.off('windowSizeChange', this.windowSizeChangeCallback);
      this.mainWindow = null;
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  private updateWindowWidth(windowWidth: number): void {
    try {
      const densityPixels = display.getDefaultDisplaySync().densityPixels;
      const widthVp = densityPixels > 0 ? windowWidth / densityPixels : windowWidth;
      if (Math.abs(widthVp - this.currentWindowWidthVp) > 0.5) {
        this.currentWindowWidthVp = widthVp;
        AppStorage.setOrCreate(WINDOW_WIDTH_KEY, widthVp);
      }
      const screenSize = widthVp < SCREEN_SIZE_BREAKPOINT ? SCREEN_SIZE_SM : SCREEN_SIZE_LG;
      if (screenSize !== this.currentScreenSize) {
        this.currentScreenSize = screenSize;
        AppStorage.setOrCreate(SCREEN_SIZE_KEY, screenSize);
      }
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to read window width. Cause: %{public}s', JSON.stringify(err));
    }
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
