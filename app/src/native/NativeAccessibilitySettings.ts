/**
 * Codegen spec for the TurboModule that exposes the iOS system accessibility
 * settings React Native core does not surface — most importantly
 * isDarkerSystemColorsEnabled, which the iOS Settings panel labels "Increase
 * Contrast". The theme system uses it to auto-select the high-contrast
 * palette (closes the gap left at the end of Fase 3).
 *
 * Spec file naming: Native*.ts (Codegen convention for TurboModules). The
 * registered module name is 'NativeAccessibilitySettings'.
 */

import { TurboModule, TurboModuleRegistry } from 'react-native';
import type { Int32 } from 'react-native/Libraries/Types/CodegenTypes';

export type AccessibilitySettings = Readonly<{
  /**
   * iOS "Increase Contrast" (Settings -> Accessibility -> Display & Text
   * Size). RN core does not expose this; reading it requires native.
   */
  isDarkerSystemColorsEnabled: boolean;
  isReduceMotionEnabled: boolean;
  isReduceTransparencyEnabled: boolean;
}>;

export interface Spec extends TurboModule {
  /** Snapshot the current settings. */
  getCurrent(): AccessibilitySettings;
  // The two methods below are required by the NativeEventEmitter contract
  // (the TS wrapper subscribes to 'change' events through it).
  addListener(eventName: string): void;
  removeListeners(count: Int32): void;
}

// .get (not .getEnforcing) so the import does not throw on Android or in
// the jest environment, where the native module is not registered. The TS
// wrapper falls back to defaults when the module is absent.
export default TurboModuleRegistry.get<Spec>('NativeAccessibilitySettings');
