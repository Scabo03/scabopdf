import { Pressable, Text } from 'react-native';
import { fireEvent, render, screen } from '@testing-library/react-native';
import {
  THEMES,
  ThemeProvider,
  useTheme,
  useThemeSelection,
  type Palette,
} from '../index';

// Relative luminance + WCAG contrast ratio for #RRGGBB colors.
function luminance(hex: string): number {
  const c = hex.replace('#', '');
  const channel = (i: number): number => {
    const v = parseInt(c.slice(i, i + 2), 16) / 255;
    return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
  };
  return 0.2126 * channel(0) + 0.7152 * channel(2) + 0.0722 * channel(4);
}

function contrastRatio(a: string, b: string): number {
  const la = luminance(a);
  const lb = luminance(b);
  const hi = Math.max(la, lb);
  const lo = Math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

function Probe() {
  const theme = useTheme();
  const { setSelection } = useThemeSelection();
  return (
    <>
      <Text>active:{theme.id}</Text>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel="switch to light"
        onPress={() => setSelection('light')}
      >
        <Text>switch to light</Text>
      </Pressable>
    </>
  );
}

describe('THEMES tokens', () => {
  const requiredAccents: Array<keyof Palette['accent']> = [
    'heading',
    'link',
    'warning',
    'procedural',
    'note',
  ];

  test.each(['dark', 'light', 'highContrast'] as const)(
    '%s theme exposes the full token shape',
    id => {
      const theme = THEMES[id];
      expect(theme.id).toBe(id);
      expect(theme.palette.background.primary).toMatch(/^#[0-9A-Fa-f]{6}$/);
      expect(theme.palette.text.primary).toMatch(/^#[0-9A-Fa-f]{6}$/);
      for (const accent of requiredAccents) {
        expect(theme.palette.accent[accent]).toMatch(/^#[0-9A-Fa-f]{6}$/);
      }
      expect(theme.typography.documentBody.fontSize).toBeGreaterThan(0);
    },
  );

  test('never uses pure white (SPECS § A.2)', () => {
    for (const id of ['dark', 'light', 'highContrast'] as const) {
      const p = THEMES[id].palette;
      expect(p.text.primary.toUpperCase()).not.toBe('#FFFFFF');
      expect(p.background.primary.toUpperCase()).not.toBe('#FFFFFF');
    }
  });

  test('body text on primary background meets WCAG AA (4.5:1)', () => {
    for (const id of ['dark', 'light', 'highContrast'] as const) {
      const p = THEMES[id].palette;
      expect(
        contrastRatio(p.text.primary, p.background.primary),
      ).toBeGreaterThanOrEqual(4.5);
    }
  });
});

describe('ThemeProvider', () => {
  test('defaults to the dark theme (SPECS § A.2)', () => {
    render(
      <ThemeProvider>
        <Probe />
      </ThemeProvider>,
    );
    expect(screen.getByText('active:dark')).toBeOnTheScreen();
  });

  test('honors an explicit initial selection', () => {
    render(
      <ThemeProvider initialSelection="highContrast">
        <Probe />
      </ThemeProvider>,
    );
    expect(screen.getByText('active:highContrast')).toBeOnTheScreen();
  });

  test('switches theme when the selection changes', () => {
    render(
      <ThemeProvider>
        <Probe />
      </ThemeProvider>,
    );
    expect(screen.getByText('active:dark')).toBeOnTheScreen();
    fireEvent.press(screen.getByText('switch to light'));
    expect(screen.getByText('active:light')).toBeOnTheScreen();
  });

  test('useTheme throws outside a provider', () => {
    const Orphan = () => {
      useTheme();
      return null;
    };
    // Silence the expected React error log for this render.
    const spy = jest.spyOn(console, 'error').mockImplementation(() => {});
    expect(() => render(<Orphan />)).toThrow(/ThemeProvider/);
    spy.mockRestore();
  });
});
