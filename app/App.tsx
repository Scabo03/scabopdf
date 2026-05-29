/**
 * ScaboPDF — app root.
 *
 * Wires the end-to-end minimum: theme + layout preferences restored from
 * AsyncStorage, the home screen offers a single "Apri documento" action, the
 * iOS system document picker imports a .scabopdf.json file, the consumption
 * layer parses + validates it, the rendering layer builds the segment stream
 * for the active layout, and the native ReadingView renders the current page
 * (Fase 4 + 5 + 6 partial).
 *
 * Everything VoiceOver-facing carries explicit accessibility props per
 * SPECS § 0 (total accessibility, P0).
 */

import { useEffect, useMemo, useState } from 'react';
import { Pressable, StatusBar, StyleSheet, Text, View } from 'react-native';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import {
  ThemeProvider,
  useTheme,
  useThemeSelection,
  type Theme,
} from './src/theme';
import {
  parseDocument,
  type LayoutId,
  type ScabopdfDocument,
} from './src/consumption';
import { buildLayout, paginate, type ContentPage } from './src/rendering';
import { ReadingView } from './src/native';
import { openDocumentFromPicker } from './src/picker';
import { getStoredLayoutId, getStoredThemeSelection } from './src/storage';

function App() {
  return (
    <SafeAreaProvider>
      <ThemeProvider>
        <ThemeBootstrap>
          <Home />
        </ThemeBootstrap>
      </ThemeProvider>
    </SafeAreaProvider>
  );
}

function ThemeBootstrap({ children }: { children: React.ReactNode }) {
  const { setSelection } = useThemeSelection();
  useEffect(() => {
    let cancelled = false;
    getStoredThemeSelection().then(s => {
      if (!cancelled) {
        setSelection(s);
      }
    });
    return () => {
      cancelled = true;
    };
  }, [setSelection]);
  return <>{children}</>;
}

function Home() {
  const theme = useTheme();
  const styles = useMemo(() => makeStyles(theme), [theme]);

  const [layoutId, setLayoutId] = useState<LayoutId>('continuous');
  const [doc, setDoc] = useState<ScabopdfDocument | null>(null);
  const [documentName, setDocumentName] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pageIndex, setPageIndex] = useState<number>(0);
  const [busy, setBusy] = useState<boolean>(false);

  useEffect(() => {
    getStoredLayoutId().then(setLayoutId);
  }, []);

  const pages = useMemo<ContentPage[]>(() => {
    if (doc === null) {
      return [];
    }
    return paginate(buildLayout(doc, layoutId)).pages;
  }, [doc, layoutId]);

  async function handleOpenDocument(): Promise<void> {
    setError(null);
    setBusy(true);
    try {
      const picked = await openDocumentFromPicker();
      if (picked === null) {
        return;
      }
      const result = parseDocument(picked.content);
      if (!result.ok) {
        setError(result.error.message);
        return;
      }
      setDoc(result.document);
      setDocumentName(picked.name);
      setPageIndex(0);
    } catch {
      setError(
        'Non è stato possibile aprire il documento. Riprova o scegli un altro file.',
      );
    } finally {
      setBusy(false);
    }
  }

  function handlePageChange(
    direction: 'next' | 'previous',
    _fromPage: number,
  ): void {
    setPageIndex(prev => {
      if (direction === 'next') {
        return Math.min(prev + 1, pages.length - 1);
      }
      return Math.max(prev - 1, 0);
    });
  }

  return (
    <>
      <StatusBar
        barStyle={theme.isDark ? 'light-content' : 'dark-content'}
        backgroundColor={theme.palette.background.primary}
      />
      <SafeAreaView style={styles.safeArea}>
        {doc === null ? (
          <View style={styles.container}>
            <Text accessibilityRole="header" style={styles.title}>
              ScaboPDF
            </Text>
            <Text style={styles.subtitle}>
              Lettura accessibile di documenti strutturati.
            </Text>
            <Pressable
              accessibilityRole="button"
              accessibilityLabel="Apri documento"
              accessibilityHint="Apre il selettore file di sistema per scegliere un documento .scabopdf.json"
              accessibilityState={{ disabled: busy }}
              disabled={busy}
              onPress={handleOpenDocument}
              style={styles.button}
            >
              <Text style={styles.buttonLabel}>
                {busy ? 'Apertura…' : 'Apri documento'}
              </Text>
            </Pressable>
            {error !== null ? (
              <Text
                style={styles.error}
                accessibilityLiveRegion="polite"
                accessibilityRole="alert"
              >
                {error}
              </Text>
            ) : null}
          </View>
        ) : (
          <ReadingView
            style={styles.reader}
            pageContent={(pages[pageIndex] ?? pages[0])?.segments ?? []}
            pageNumber={(pages[pageIndex] ?? pages[0])?.pageNumber ?? 1}
            textColor={theme.palette.text.primary}
            bodyFontSize={theme.typography.documentBody.fontSize}
            onRequestPageChange={handlePageChange}
            accessibilityLabel={
              documentName !== null
                ? `Lettura del documento ${documentName}`
                : 'Lettura del documento'
            }
          />
        )}
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
      marginBottom: 32,
    },
    button: {
      minWidth: 200,
      minHeight: 44,
      paddingHorizontal: 24,
      paddingVertical: 12,
      borderRadius: 8,
      backgroundColor: theme.palette.background.tertiary,
      borderWidth: 1,
      borderColor: theme.palette.accent.link,
      alignItems: 'center',
      justifyContent: 'center',
    },
    buttonLabel: {
      color: theme.palette.accent.link,
      fontSize: theme.typography.uiLabel.fontSize,
      fontWeight: theme.typography.uiLabel.fontWeight,
    },
    error: {
      marginTop: 16,
      color: theme.palette.accent.warning,
      fontSize: theme.typography.note.fontSize,
      textAlign: 'center',
    },
    reader: {
      flex: 1,
    },
  });
}

export default App;
