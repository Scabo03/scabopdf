/**
 * Theme context. Holds the user's theme selection and resolves it to a
 * concrete Theme, exposed via useTheme().
 *
 * Selection is one of the three theme ids or 'system' (follow the OS light/
 * dark setting). The app default is 'dark' per SPECS § A.2.
 *
 * iOS "Increase Contrast" auto-detection is wired through the
 * NativeAccessibilitySettings TurboModule (Fase 4 native module): when the
 * system flag is on and the user has not explicitly chosen the light theme,
 * the resolved theme is automatically promoted to highContrast.
 */

import {
  createContext,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import { useColorScheme } from 'react-native';
import {
  getAccessibilitySettings,
  subscribeAccessibilitySettings,
} from '../native';
import { DEFAULT_THEME_ID, THEMES, type Theme, type ThemeId } from './tokens';

export type ThemeSelection = ThemeId | 'system';

interface ThemeContextValue {
  theme: Theme;
  selection: ThemeSelection;
  setSelection: (selection: ThemeSelection) => void;
  /** True when the iOS "Increase Contrast" setting is currently active. */
  systemHighContrast: boolean;
}

const ThemeContext = createContext<ThemeContextValue | undefined>(undefined);

interface ThemeProviderProps {
  children: ReactNode;
  initialSelection?: ThemeSelection;
}

function resolveThemeId(
  selection: ThemeSelection,
  systemScheme: ReturnType<typeof useColorScheme>,
  systemHighContrast: boolean,
): ThemeId {
  // Explicit non-dark choices are honored verbatim.
  if (selection === 'light' || selection === 'highContrast') {
    return selection;
  }
  const baseId: ThemeId =
    selection === 'system'
      ? systemScheme === 'light'
        ? 'light'
        : 'dark'
      : selection;
  // If the system "Increase Contrast" flag is on and we are about to render
  // the regular dark theme, promote it to high contrast automatically. We
  // never auto-promote the light theme (no light-HC palette exists).
  if (baseId === 'dark' && systemHighContrast) {
    return 'highContrast';
  }
  return baseId;
}

export function ThemeProvider({
  children,
  initialSelection = DEFAULT_THEME_ID,
}: ThemeProviderProps) {
  const [selection, setSelection] = useState<ThemeSelection>(initialSelection);
  const systemScheme = useColorScheme();
  const [systemHighContrast, setSystemHighContrast] = useState<boolean>(
    () => getAccessibilitySettings().isDarkerSystemColorsEnabled,
  );

  useEffect(() => {
    const unsubscribe = subscribeAccessibilitySettings(settings => {
      setSystemHighContrast(settings.isDarkerSystemColorsEnabled);
    });
    return unsubscribe;
  }, []);

  const value = useMemo<ThemeContextValue>(() => {
    const resolvedId = resolveThemeId(
      selection,
      systemScheme,
      systemHighContrast,
    );
    return {
      theme: THEMES[resolvedId],
      selection,
      setSelection,
      systemHighContrast,
    };
  }, [selection, systemScheme, systemHighContrast]);

  return (
    <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>
  );
}

function useThemeContext(): ThemeContextValue {
  const ctx = useContext(ThemeContext);
  if (ctx === undefined) {
    throw new Error('useTheme must be used within a ThemeProvider');
  }
  return ctx;
}

/** The active resolved theme. */
export function useTheme(): Theme {
  return useThemeContext().theme;
}

/** The current selection and a setter, for theme-switching UI. */
export function useThemeSelection(): {
  selection: ThemeSelection;
  setSelection: (selection: ThemeSelection) => void;
  systemHighContrast: boolean;
} {
  const { selection, setSelection, systemHighContrast } = useThemeContext();
  return { selection, setSelection, systemHighContrast };
}
