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

// AsyncStorage ships a JS-only jest mock at @react-native-async-storage/async-storage/jest.
jest.mock('@react-native-async-storage/async-storage', () =>
  require('@react-native-async-storage/async-storage/jest'),
);

// The document picker imports a TurboModule at module-load time via
// TurboModuleRegistry.getEnforcing, which throws under jest. Provide a default
// mock so the app + tests load; individual tests override via jest.doMock.
jest.mock('@react-native-documents/picker', () => ({
  pick: jest.fn().mockResolvedValue([]),
  errorCodes: { OPERATION_CANCELED: 'OPERATION_CANCELED' },
  isErrorWithCode: () => false,
  types: {},
  keepLocalCopy: jest.fn(),
}));
