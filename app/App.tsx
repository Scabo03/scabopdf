/**
 * ScaboPDF — app root.
 *
 * Placeholder home screen. The real reading experience (native
 * UIAccessibilityReadingContent view, the three layout renderers, the theme
 * system and the JSON consumption layer) lands in later phases. This screen
 * exists so the scaffold runs and is fully VoiceOver-accessible from day one
 * (SPECS § 0: accessibility is total and non-negotiable).
 */

import { StatusBar, StyleSheet, Text, View } from 'react-native';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';

const colors = {
  background: '#0A0A0A',
  textPrimary: '#E0E0D8',
  textSecondary: '#8A8A82',
};

function App() {
  return (
    <SafeAreaProvider>
      <StatusBar barStyle="light-content" backgroundColor={colors.background} />
      <SafeAreaView style={styles.safeArea}>
        <View style={styles.container}>
          <Text accessibilityRole="header" style={styles.title}>
            ScaboPDF
          </Text>
          <Text style={styles.subtitle}>
            Lettura accessibile di documenti strutturati.
          </Text>
        </View>
      </SafeAreaView>
    </SafeAreaProvider>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: colors.background,
  },
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 24,
  },
  title: {
    color: colors.textPrimary,
    fontSize: 28,
    fontWeight: '700',
    marginBottom: 12,
  },
  subtitle: {
    color: colors.textSecondary,
    fontSize: 17,
    textAlign: 'center',
  },
});

export default App;
