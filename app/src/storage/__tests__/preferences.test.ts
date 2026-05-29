/**
 * Tests for the persistent preferences wrappers. Uses the AsyncStorage mock
 * provided by the library (a JS-only Map-backed implementation), so the
 * round-trips are real.
 */

import AsyncStorage from '@react-native-async-storage/async-storage';
import {
  getStoredLayoutId,
  getStoredThemeSelection,
  setStoredLayoutId,
  setStoredThemeSelection,
} from '../preferences';

beforeEach(async () => {
  await AsyncStorage.clear();
});

describe('theme selection persistence', () => {
  test('defaults to dark when nothing is stored', async () => {
    expect(await getStoredThemeSelection()).toBe('dark');
  });

  test('round-trips a valid value', async () => {
    await setStoredThemeSelection('light');
    expect(await getStoredThemeSelection()).toBe('light');
    await setStoredThemeSelection('highContrast');
    expect(await getStoredThemeSelection()).toBe('highContrast');
    await setStoredThemeSelection('system');
    expect(await getStoredThemeSelection()).toBe('system');
  });

  test('ignores a corrupted/unknown stored value and returns the default', async () => {
    await AsyncStorage.setItem('@scabopdf/theme/selection', 'midnight');
    expect(await getStoredThemeSelection()).toBe('dark');
  });
});

describe('layout id persistence', () => {
  test('defaults to continuous when nothing is stored', async () => {
    expect(await getStoredLayoutId()).toBe('continuous');
  });

  test('round-trips a valid value', async () => {
    await setStoredLayoutId('quick');
    expect(await getStoredLayoutId()).toBe('quick');
    await setStoredLayoutId('doctrine');
    expect(await getStoredLayoutId()).toBe('doctrine');
  });

  test('ignores a corrupted stored value and returns the default', async () => {
    await AsyncStorage.setItem('@scabopdf/reading/layout', 'fancy');
    expect(await getStoredLayoutId()).toBe('continuous');
  });
});
