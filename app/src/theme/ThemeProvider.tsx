/**
 * Theme context. Holds the user's theme selection and resolves it to a
 * concrete Theme, exposed via useTheme().
 *
 * Selection is one of the three theme ids or 'system' (follow the OS light/
 * dark setting). The app default is 'dark' per SPECS § A.2.
 *
 * Note: automatic detection of the iOS "Increase Contrast" setting is not
 * wired here — React Native core exposes no API for it, so the high-contrast
 * theme is a manual selection for now. Detecting it needs a small native
 * addition (a candidate for the Fase 4 native module work).
 */

import {
  createContext,
  useContext,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import { useColorScheme } from 'react-native';
import { DEFAULT_THEME_ID, THEMES, type Theme, type ThemeId } from './tokens';

export type ThemeSelection = ThemeId | 'system';

interface ThemeContextValue {
  theme: Theme;
  selection: ThemeSelection;
  setSelection: (selection: ThemeSelection) => void;
}

const ThemeContext = createContext<ThemeContextValue | undefined>(undefined);

interface ThemeProviderProps {
  children: ReactNode;
  initialSelection?: ThemeSelection;
}

export function ThemeProvider({
  children,
  initialSelection = DEFAULT_THEME_ID,
}: ThemeProviderProps) {
  const [selection, setSelection] = useState<ThemeSelection>(initialSelection);
  const systemScheme = useColorScheme();

  const value = useMemo<ThemeContextValue>(() => {
    const resolvedId: ThemeId =
      selection === 'system'
        ? systemScheme === 'light'
          ? 'light'
          : 'dark'
        : selection;
    return { theme: THEMES[resolvedId], selection, setSelection };
  }, [selection, systemScheme]);

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
} {
  const { selection, setSelection } = useThemeContext();
  return { selection, setSelection };
}
