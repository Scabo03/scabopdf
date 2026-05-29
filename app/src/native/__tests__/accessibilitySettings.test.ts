/**
 * Tests for the accessibility-settings wrapper. The native module is not
 * registered in jest, so the wrapper must fall back to safe defaults rather
 * than throw.
 */

import {
  getAccessibilitySettings,
  subscribeAccessibilitySettings,
} from '../accessibilitySettings';

describe('accessibilitySettings wrapper without native module', () => {
  test('getAccessibilitySettings returns all-false defaults', () => {
    const s = getAccessibilitySettings();
    expect(s).toEqual({
      isDarkerSystemColorsEnabled: false,
      isReduceMotionEnabled: false,
      isReduceTransparencyEnabled: false,
    });
  });

  test('subscribeAccessibilitySettings returns a no-op unsubscribe', () => {
    const callback = jest.fn();
    const unsubscribe = subscribeAccessibilitySettings(callback);
    expect(typeof unsubscribe).toBe('function');
    unsubscribe(); // does not throw
    expect(callback).not.toHaveBeenCalled();
  });
});

describe('accessibilitySettings wrapper with a mocked native module', () => {
  // The wrapper imports NativeAccessibilitySettings as default; mock that
  // import to simulate a registered TurboModule.
  beforeEach(() => {
    jest.resetModules();
  });

  test('getAccessibilitySettings returns the native snapshot', () => {
    jest.doMock('../NativeAccessibilitySettings', () => ({
      __esModule: true,
      default: {
        getCurrent: () => ({
          isDarkerSystemColorsEnabled: true,
          isReduceMotionEnabled: false,
          isReduceTransparencyEnabled: true,
        }),
        addListener: jest.fn(),
        removeListeners: jest.fn(),
      },
    }));
    // Re-require the wrapper so the mock takes effect.
    const { getAccessibilitySettings: getter } = jest.requireActual<
      typeof import('../accessibilitySettings')
    >('../accessibilitySettings');
    const s = getter();
    expect(s.isDarkerSystemColorsEnabled).toBe(true);
    expect(s.isReduceTransparencyEnabled).toBe(true);
    expect(s.isReduceMotionEnabled).toBe(false);
  });

  test('getAccessibilitySettings falls back on native throw', () => {
    jest.doMock('../NativeAccessibilitySettings', () => ({
      __esModule: true,
      default: {
        getCurrent: () => {
          throw new Error('native bridge unavailable');
        },
        addListener: jest.fn(),
        removeListeners: jest.fn(),
      },
    }));
    const { getAccessibilitySettings: getter } = jest.requireActual<
      typeof import('../accessibilitySettings')
    >('../accessibilitySettings');
    expect(getter().isDarkerSystemColorsEnabled).toBe(false);
  });
});
