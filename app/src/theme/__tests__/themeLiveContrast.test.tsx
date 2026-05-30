/**
 * Verifies the ThemeProvider live-updates the resolved theme when the iOS
 * "Increase Contrast" flag toggles at runtime (not just at first read). The
 * sibling themeAutoHighContrast test covers the initial read with a static
 * mock; this one drives the subscription callback.
 */

import { Text } from 'react-native';
import { render, screen, act } from '@testing-library/react-native';

interface FakeSettings {
  isDarkerSystemColorsEnabled: boolean;
  isReduceMotionEnabled: boolean;
  isReduceTransparencyEnabled: boolean;
}

// Module-scoped holder (mock-prefixed so jest's hoist allows the reference).
const mockSub: { cb: ((s: FakeSettings) => void) | null } = { cb: null };

jest.mock('../../native', () => ({
  getAccessibilitySettings: (): FakeSettings => ({
    isDarkerSystemColorsEnabled: false,
    isReduceMotionEnabled: false,
    isReduceTransparencyEnabled: false,
  }),
  subscribeAccessibilitySettings: (cb: (s: FakeSettings) => void) => {
    mockSub.cb = cb;
    return () => {
      mockSub.cb = null;
    };
  },
}));

import { ThemeProvider, useTheme } from '../ThemeProvider';

function Probe() {
  const theme = useTheme();
  return <Text>active:{theme.id}</Text>;
}

describe('ThemeProvider live Increase Contrast', () => {
  test('flips dark -> highContrast when the system flag toggles on at runtime', () => {
    render(
      <ThemeProvider>
        <Probe />
      </ThemeProvider>,
    );
    // Default selection is dark and the initial read is contrast-off.
    expect(screen.getByText('active:dark')).toBeOnTheScreen();

    act(() => {
      mockSub.cb?.({
        isDarkerSystemColorsEnabled: true,
        isReduceMotionEnabled: false,
        isReduceTransparencyEnabled: false,
      });
    });

    expect(screen.getByText('active:highContrast')).toBeOnTheScreen();
  });
});
