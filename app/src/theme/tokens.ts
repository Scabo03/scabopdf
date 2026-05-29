/**
 * Design tokens for ScaboPDF, from SPECS § A.
 *
 * Three themes are offered (SPECS § A.6): dark high-contrast (default and
 * mandatory for the reading view, § A.2), light academic, and a higher
 * contrast variant. Pure white (#FFFFFF) and yellow are categorically
 * excluded (§ A.2).
 *
 * Values marked "(derived)" are not given verbatim by SPECS § A and are
 * conservative fills to be confirmed: SPECS specifies the dark palette and
 * accents fully, but for the light theme gives only background and text
 * primaries, and for high contrast gives only the intent.
 */

import type { TextStyle } from 'react-native';

export type ThemeId = 'dark' | 'light' | 'highContrast';

export interface Palette {
  background: {
    primary: string;
    secondary: string;
    tertiary: string;
    border: string;
  };
  text: {
    primary: string;
    secondary: string;
    disabled: string;
  };
  /** Accent roles, SPECS § A.2. Saturated and deep, never pastel. */
  accent: {
    heading: string;
    link: string;
    warning: string;
    procedural: string;
    note: string;
  };
}

export interface TypographyToken {
  fontSize: number;
  fontWeight: TextStyle['fontWeight'];
}

export interface Typography {
  documentBody: TypographyToken;
  documentHeading: TypographyToken;
  articleNumber: TypographyToken;
  note: TypographyToken;
  uiLabel: TypographyToken;
  screenTitle: TypographyToken;
}

export interface Theme {
  id: ThemeId;
  isDark: boolean;
  palette: Palette;
  typography: Typography;
}

// SPECS § A.2 accent roles. Shared across themes; SPECS § A.6 says the light
// theme reuses the same accents "con contrasto verificato" — see report note,
// some pairings on the ivory background are low-contrast and may need
// darker variants once verified against real screens.
const ACCENT: Palette['accent'] = {
  heading: '#1DB87A', // emerald — article/section headings
  link: '#1A7FE8', // electric blue — links, interactive controls
  warning: '#C0392B', // ruby — critical/significant notes
  procedural: '#B8922A', // antique gold — procedural blocks, keys
  note: '#4A8FA8', // steel blue — short note text
};

const DARK_PALETTE: Palette = {
  background: {
    primary: '#0A0A0A',
    secondary: '#141414',
    tertiary: '#1E1E1E',
    border: '#2A2A2A',
  },
  text: {
    primary: '#E0E0D8',
    secondary: '#8A8A82',
    disabled: '#4A4A44',
  },
  accent: ACCENT,
};

const LIGHT_PALETTE: Palette = {
  background: {
    primary: '#F5F2EB', // ivory (SPECS § A.6)
    secondary: '#ECE8DE', // (derived)
    tertiary: '#E3DED2', // (derived)
    border: '#D8D2C4', // (derived)
  },
  text: {
    primary: '#1A1A1A', // anthracite (SPECS § A.6)
    secondary: '#5A5A52', // (derived)
    disabled: '#9A9A90', // (derived)
  },
  accent: ACCENT,
};

// (derived) Higher-contrast variant of the dark theme, within the SPECS § A.2
// constraints (no pure white, no yellow). Available for manual selection.
const HIGH_CONTRAST_PALETTE: Palette = {
  background: {
    primary: '#000000',
    secondary: '#0A0A0A',
    tertiary: '#141414',
    border: '#4A4A44',
  },
  text: {
    primary: '#F2F2EC', // near-white, deliberately not #FFFFFF
    secondary: '#C8C8C0',
    disabled: '#6A6A62',
  },
  accent: ACCENT,
};

// SPECS § A.3. The system font (San Francisco on iOS) is used everywhere, so
// fontFamily is left to the platform default; Dynamic Type scaling is on by
// default in React Native (allowFontScaling). Sizes pick a value inside each
// SPECS range.
const TYPOGRAPHY: Typography = {
  documentBody: { fontSize: 18, fontWeight: '400' },
  documentHeading: { fontSize: 24, fontWeight: '600' },
  articleNumber: { fontSize: 18, fontWeight: '700' },
  note: { fontSize: 15, fontWeight: '400' },
  uiLabel: { fontSize: 14, fontWeight: '500' },
  screenTitle: { fontSize: 22, fontWeight: '700' },
};

export const THEMES: Readonly<Record<ThemeId, Theme>> = {
  dark: {
    id: 'dark',
    isDark: true,
    palette: DARK_PALETTE,
    typography: TYPOGRAPHY,
  },
  light: {
    id: 'light',
    isDark: false,
    palette: LIGHT_PALETTE,
    typography: TYPOGRAPHY,
  },
  highContrast: {
    id: 'highContrast',
    isDark: true,
    palette: HIGH_CONTRAST_PALETTE,
    typography: TYPOGRAPHY,
  },
};

/** App default: dark, per SPECS § A.2 (mandatory for the reading view). */
export const DEFAULT_THEME_ID: ThemeId = 'dark';
