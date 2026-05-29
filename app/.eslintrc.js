module.exports = {
  root: true,
  extends: ['@react-native', 'plugin:react-native-a11y/ios'],
  // Generated from shared/schema.json by npm run gen:schema; not hand-edited.
  ignorePatterns: ['src/consumption/schema.generated.ts'],
  rules: {
    // SPECS § 0.5: accessibilityHint is required only where the action is
    // not self-evident from the label, not on every labelled element. The
    // plugin's iOS preset forces it everywhere, which over-reports; we keep
    // every other accessibility rule at error (total accessibility is P0).
    'react-native-a11y/has-accessibility-hint': 'off',
  },
  overrides: [
    {
      // Node/Jest config and setup files that run outside the RN runtime.
      files: ['jest.setup.js', '*.config.js', '.eslintrc.js', '.prettierrc.js'],
      env: { node: true, jest: true },
    },
  ],
};
