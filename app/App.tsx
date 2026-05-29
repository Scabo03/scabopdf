/**
 * ScaboPDF — app root.
 *
 * Placeholder home screen. The real reading experience (native
 * UIAccessibilityReadingContent view, the three layout renderers and the JSON
 * consumption wiring) lands in later phases. This screen exists so the
 * scaffold runs, is fully VoiceOver-accessible from day one (SPECS § 0), and
 * consumes the theme system (SPECS § A).
 */

import { useMemo } from 'react';
import { StatusBar, StyleSheet, Text, View } from 'react-native';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { ThemeProvider, useTheme, type Theme } from './src/theme';

function App() {
  return (
    <SafeAreaProvider>
      <ThemeProvider>
        <Home />
      </ThemeProvider>
    </SafeAreaProvider>
  );
}

function Home() {
  const theme = useTheme();
  const styles = useMemo(() => makeStyles(theme), [theme]);

  return (
    <>
      <StatusBar
        barStyle={theme.isDark ? 'light-content' : 'dark-content'}
        backgroundColor={theme.palette.background.primary}
      />
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
    </>
  );
}

function makeStyles(theme: Theme) {
  return StyleSheet.create({
    safeArea: {
      flex: 1,
      backgroundColor: theme.palette.background.primary,
    },
    container: {
      flex: 1,
      justifyContent: 'center',
      alignItems: 'center',
      paddingHorizontal: 24,
    },
    title: {
      color: theme.palette.accent.heading,
      fontSize: theme.typography.screenTitle.fontSize,
      fontWeight: theme.typography.screenTitle.fontWeight,
      marginBottom: 12,
    },
    subtitle: {
      color: theme.palette.text.secondary,
      fontSize: theme.typography.documentBody.fontSize,
      textAlign: 'center',
    },
  });
}

export default App;
