/**
 * Public wrapper around the NativeAccessibilitySettings TurboModule.
 *
 * Falls back to safe defaults when the native module is not registered
 * (Android, jest, simulator with stale pods) so callers never crash on a
 * missing native side.
 */

import { NativeEventEmitter } from 'react-native';
import NativeAccessibilitySettings, {
  type AccessibilitySettings,
} from './NativeAccessibilitySettings';

export type { AccessibilitySettings };

const DEFAULTS: AccessibilitySettings = {
  isDarkerSystemColorsEnabled: false,
  isReduceMotionEnabled: false,
  isReduceTransparencyEnabled: false,
};

/** Read the current settings; returns DEFAULTS when the native module is absent. */
export function getAccessibilitySettings(): AccessibilitySettings {
  if (NativeAccessibilitySettings === null) {
    return DEFAULTS;
  }
  try {
    return NativeAccessibilitySettings.getCurrent();
  } catch {
    return DEFAULTS;
  }
}

/**
 * Subscribe to live changes. Returns an unsubscribe function. On platforms /
 * environments where the module is absent the callback is never invoked and
 * the unsubscribe is a no-op.
 */
export function subscribeAccessibilitySettings(
  callback: (settings: AccessibilitySettings) => void,
): () => void {
  if (NativeAccessibilitySettings === null) {
    return () => {};
  }
  // NativeEventEmitter expects a NativeModule-shaped object; the TurboModule
  // exposes the addListener/removeListeners pair the emitter needs.
  const emitter = new NativeEventEmitter(
    NativeAccessibilitySettings as unknown as ConstructorParameters<
      typeof NativeEventEmitter
    >[0],
  );
  const subscription = emitter.addListener('change', callback);
  return () => subscription.remove();
}
