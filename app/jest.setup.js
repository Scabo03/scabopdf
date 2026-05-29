/**
 * Jest setup, run after the test framework is installed.
 *
 * Mocks react-native-safe-area-context so SafeAreaProvider renders its
 * children synchronously under the test renderer. The real provider defers
 * rendering until an onLayout measurement that never fires in tests, which
 * would otherwise hide the whole tree from queries.
 */

jest.mock(
  'react-native-safe-area-context',
  () => require('react-native-safe-area-context/jest/mock').default,
);
