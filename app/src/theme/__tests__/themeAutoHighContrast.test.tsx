/**
 * Verifies the ThemeProvider auto-promotes dark -> highContrast when the
 * system "Increase Contrast" flag is on, and never promotes the light theme.
 */

import { Text } from 'react-native';
import { render, screen } from '@testing-library/react-native';

// Mock the native bridge BEFORE importing the provider that consumes it.
jest.mock('../../native', () => ({
  getAccessibilitySettings: () => ({
    isDarkerSystemColorsEnabled: true,
    isReduceMotionEnabled: false,
    isReduceTransparencyEnabled: false,
  }),
  subscribeAccessibilitySettings: () => () => {},
}));

import { ThemeProvider, useTheme } from '../ThemeProvider';

function Probe() {
  const theme = useTheme();
  return <Text>active:{theme.id}</Text>;
}

describe('ThemeProvider auto high-contrast', () => {
  test('promotes the dark default to highContrast when Increase Contrast is on', () => {
    render(
      <ThemeProvider>
        <Probe />
      </ThemeProvider>,
    );
    expect(screen.getByText('active:highContrast')).toBeOnTheScreen();
  });

  test('honors an explicit light selection regardless of Increase Contrast', () => {
    render(
      <ThemeProvider initialSelection="light">
        <Probe />
      </ThemeProvider>,
    );
    expect(screen.getByText('active:light')).toBeOnTheScreen();
  });

  test('honors an explicit highContrast selection', () => {
    render(
      <ThemeProvider initialSelection="highContrast">
        <Probe />
      </ThemeProvider>,
    );
    expect(screen.getByText('active:highContrast')).toBeOnTheScreen();
  });
});
