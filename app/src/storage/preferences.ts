/**
 * Persistent app preferences (theme selection and reading layout) backed by
 * AsyncStorage. The getters never throw: a missing or corrupt value yields
 * the documented default. The setters return a Promise that the caller can
 * await, but the UI does not need to.
 */

import AsyncStorage from '@react-native-async-storage/async-storage';
import { DEFAULT_THEME_ID, type ThemeSelection } from '../theme';
import type { LayoutId } from '../consumption';

const KEY_THEME_SELECTION = '@scabopdf/theme/selection';
const KEY_LAYOUT_ID = '@scabopdf/reading/layout';

const VALID_THEME_SELECTIONS: ReadonlySet<ThemeSelection> =
  new Set<ThemeSelection>(['dark', 'light', 'highContrast', 'system']);

const VALID_LAYOUTS: ReadonlySet<LayoutId> = new Set<LayoutId>([
  'continuous',
  'quick',
  'doctrine',
]);

export async function getStoredThemeSelection(): Promise<ThemeSelection> {
  try {
    const stored = await AsyncStorage.getItem(KEY_THEME_SELECTION);
    if (
      stored !== null &&
      (VALID_THEME_SELECTIONS as Set<string>).has(stored)
    ) {
      return stored as ThemeSelection;
    }
  } catch {
    // Fall through to default.
  }
  return DEFAULT_THEME_ID;
}

export async function setStoredThemeSelection(
  selection: ThemeSelection,
): Promise<void> {
  await AsyncStorage.setItem(KEY_THEME_SELECTION, selection);
}

export async function getStoredLayoutId(): Promise<LayoutId> {
  try {
    const stored = await AsyncStorage.getItem(KEY_LAYOUT_ID);
    if (stored !== null && (VALID_LAYOUTS as Set<string>).has(stored)) {
      return stored as LayoutId;
    }
  } catch {
    // Fall through to default.
  }
  return 'continuous';
}

export async function setStoredLayoutId(layout: LayoutId): Promise<void> {
  await AsyncStorage.setItem(KEY_LAYOUT_ID, layout);
}
