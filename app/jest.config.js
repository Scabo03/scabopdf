module.exports = {
  preset: '@react-native/jest-preset',
  setupFilesAfterEnv: ['<rootDir>/jest.setup.js'],
  // Watchman is unreliable on the mounted /Volumes path this repo lives on
  // and falls back to the node crawler with a noisy 60s timeout. Disable it
  // for deterministic test runs in pre-commit/CI.
  watchman: false,
  // The preset's transformIgnorePatterns does not include
  // react-native-safe-area-context, whose Jest mock ships as untransformed
  // TSX. Re-state the preset pattern and add the library so Babel transforms
  // it.
  transformIgnorePatterns: [
    'node_modules/(?!((jest-)?react-native|@react-native(-community)?|react-native-safe-area-context)/)',
  ],
};
