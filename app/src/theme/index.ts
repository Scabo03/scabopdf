/** Public surface of the theme/design system. */

export {
  THEMES,
  DEFAULT_THEME_ID,
  type Theme,
  type ThemeId,
  type Palette,
  type Typography,
  type TypographyToken,
} from './tokens';

export {
  ThemeProvider,
  useTheme,
  useThemeSelection,
  type ThemeSelection,
} from './ThemeProvider';
