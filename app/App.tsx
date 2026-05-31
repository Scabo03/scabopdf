/**
 * ScaboPDF — app root.
 *
 * Wires the end-to-end minimum: theme + layout preferences restored from
 * AsyncStorage, the home screen lists the documents opened this session and
 * offers "Apri documento", the iOS system document picker imports a
 * .scabopdf.json file, the consumption layer parses + validates it, the
 * rendering layer builds the segment stream for the active layout, and the
 * native ReadingView renders the current page (Fase 4 + 5 + 6 partial).
 *
 * Navigation (Q3): opening a document swaps to a reader with a top-left
 * "Chiudi" control (iOS convention); closing returns to the home list and
 * moves VoiceOver focus onto the row of the document that was just closed —
 * the one the user had open — rather than the top of the list.
 *
 * Everything VoiceOver-facing carries explicit accessibility props per
 * SPECS § 0 (total accessibility, P0).
 */

import { useEffect, useMemo, useRef, useState } from 'react';
import {
  AccessibilityInfo,
  findNodeHandle,
  Pressable,
  ScrollView,
  StatusBar,
  StyleSheet,
  Text,
  View,
} from 'react-native';
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
import { extractPdf, ReadingView, totalLines } from './src/native';
import { buildDocumentFromPdf } from './src/plugins';
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

/** A document opened this session, kept parsed in memory for instant reopen. */
interface OpenedDocument {
  id: string;
  name: string;
  doc: ScabopdfDocument;
}

function Home() {
  const theme = useTheme();
  const styles = useMemo(() => makeStyles(theme), [theme]);

  const [layoutId, setLayoutId] = useState<LayoutId>('continuous');
  const [documents, setDocuments] = useState<OpenedDocument[]>([]);
  const [activeId, setActiveId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pageIndex, setPageIndex] = useState<number>(0);
  const [busy, setBusy] = useState<boolean>(false);
  // The row to move VoiceOver focus to after returning to the home list.
  const [focusTargetId, setFocusTargetId] = useState<string | null>(null);

  const nextId = useRef<number>(0);
  const rowRefs = useRef<Map<string, View | null>>(new Map());

  useEffect(() => {
    getStoredLayoutId().then(setLayoutId);
  }, []);

  const activeDoc = useMemo(
    () => documents.find(d => d.id === activeId) ?? null,
    [documents, activeId],
  );

  const pages = useMemo<ContentPage[]>(() => {
    if (activeDoc === null) {
      return [];
    }
    return paginate(buildLayout(activeDoc.doc, layoutId)).pages;
  }, [activeDoc, layoutId]);

  // After closing a document, move VoiceOver focus onto its row in the list.
  useEffect(() => {
    if (activeId !== null || focusTargetId === null) {
      return;
    }
    const id = focusTargetId;
    const timer = setTimeout(() => {
      const el = rowRefs.current.get(id);
      const node = el ? findNodeHandle(el) : null;
      if (node != null) {
        AccessibilityInfo.setAccessibilityFocus(node);
      }
      setFocusTargetId(null);
    }, 250);
    return () => clearTimeout(timer);
  }, [activeId, focusTargetId]);

  // Surface a failure to VoiceOver: the live-region <Text alert> renders it,
  // and the explicit announce guarantees it is spoken even if the region update
  // is missed. Never swallow a meaningful message (SPECS § 0, P0).
  function fail(message: string): void {
    setError(message);
    AccessibilityInfo.announceForAccessibility(message);
  }

  async function handleOpenDocument(): Promise<void> {
    setError(null);
    setBusy(true);
    // The button label flips to "Apertura…" and is disabled, but a state
    // change is not spoken; announce it so the wait is not silent for a
    // VoiceOver user while the picker / parse runs (SPECS § 0, P0).
    AccessibilityInfo.announceForAccessibility(
      'Apertura del documento in corso',
    );
    try {
      const picked = await openDocumentFromPicker();
      if (picked === null) {
        return;
      }
      if (picked.kind === 'pdf') {
        await openPdf(picked.name, picked.uri);
      } else {
        openScabopdf(picked.name, picked.content ?? '');
      }
    } catch (cause) {
      // parseDocument never throws; the throwing paths are the picker, the
      // file read and the native PDF extractor — all of which carry a readable
      // Italian message we must show rather than replace with an opaque one.
      fail(
        cause instanceof Error && cause.message.length > 0
          ? cause.message
          : 'Non è stato possibile aprire il documento. Riprova o scegli un altro file.',
      );
    } finally {
      setBusy(false);
    }
  }

  function openScabopdf(name: string, content: string): void {
    const result = parseDocument(content);
    if (!result.ok) {
      // invalid_json / unsupported_version / schema_validation — each carries
      // its own user-facing message; surface it instead of swallowing it.
      fail(result.error.message);
      return;
    }
    openInReader(name, result.document);
  }

  async function openPdf(name: string, uri: string): Promise<void> {
    const extraction = await extractPdf(uri);
    if (totalLines(extraction) === 0) {
      fail(
        'Nessun testo estraibile da questo PDF. Potrebbe essere un documento scansionato, fatto di sole immagini.',
      );
      return;
    }
    openInReader(name, buildDocumentFromPdf(extraction, name));
  }

  function openInReader(name: string, doc: ScabopdfDocument): void {
    // Reuse the existing entry when the same file is reopened, so the list
    // stays clean and the focus-return target is stable.
    const existing = documents.find(d => d.name === name);
    const id = existing ? existing.id : `doc_${nextId.current++}`;
    setDocuments(prev => {
      const without = prev.filter(d => d.id !== id);
      return [{ id, name, doc }, ...without];
    });
    setActiveId(id);
    setPageIndex(0);
    AccessibilityInfo.announceForAccessibility(`Documento ${name} aperto`);
  }

  function handleReopen(item: OpenedDocument): void {
    setActiveId(item.id);
    setPageIndex(0);
    AccessibilityInfo.announceForAccessibility(`Documento ${item.name} aperto`);
  }

  function handleClose(): void {
    const closed = activeId;
    setActiveId(null);
    setFocusTargetId(closed);
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

  const page = pages[pageIndex] ?? pages[0];

  return (
    <>
      <StatusBar
        barStyle={theme.isDark ? 'light-content' : 'dark-content'}
        backgroundColor={theme.palette.background.primary}
      />
      <SafeAreaView style={styles.safeArea}>
        {activeDoc === null ? (
          <ScrollView contentContainerStyle={styles.homeContent}>
            <Text accessibilityRole="header" style={styles.title}>
              ScaboPDF
            </Text>
            <Text style={styles.subtitle}>
              Lettura accessibile di documenti strutturati.
            </Text>
            <Pressable
              accessibilityRole="button"
              accessibilityLabel="Apri documento"
              accessibilityHint="Apre il selettore file di sistema per scegliere un PDF o un documento .scabopdf.json"
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
            {documents.length > 0 ? (
              <View style={styles.list}>
                <Text accessibilityRole="header" style={styles.listHeader}>
                  Documenti aperti
                </Text>
                {documents.map(item => (
                  <Pressable
                    key={item.id}
                    ref={el => {
                      rowRefs.current.set(item.id, el);
                    }}
                    accessibilityRole="button"
                    accessibilityLabel={item.name}
                    accessibilityHint="Riapre il documento in lettura"
                    onPress={() => handleReopen(item)}
                    style={styles.row}
                  >
                    <Text style={styles.rowLabel}>{item.name}</Text>
                  </Pressable>
                ))}
              </View>
            ) : null}
          </ScrollView>
        ) : (
          <View style={styles.readerScreen}>
            <View style={styles.readerBar}>
              <Pressable
                accessibilityRole="button"
                accessibilityLabel="Chiudi documento"
                accessibilityHint="Torna all'elenco dei documenti"
                onPress={handleClose}
                style={styles.backButton}
              >
                <Text style={styles.backLabel}>‹ Chiudi</Text>
              </Pressable>
              <Text
                accessibilityRole="header"
                numberOfLines={1}
                style={styles.readerTitle}
              >
                {activeDoc.name}
              </Text>
            </View>
            <ReadingView
              style={styles.reader}
              pageContent={page?.segments ?? []}
              pageNumber={page?.pageNumber ?? 1}
              textColor={theme.palette.text.primary}
              bodyFontSize={theme.typography.documentBody.fontSize}
              onRequestPageChange={handlePageChange}
              accessibilityLabel={`Lettura del documento ${activeDoc.name}`}
            />
          </View>
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
    homeContent: {
      paddingHorizontal: 24,
      paddingTop: 32,
      paddingBottom: 24,
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
      marginBottom: 24,
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
    },
    list: {
      marginTop: 32,
    },
    listHeader: {
      color: theme.palette.accent.heading,
      fontSize: theme.typography.uiLabel.fontSize,
      fontWeight: theme.typography.uiLabel.fontWeight,
      marginBottom: 12,
    },
    row: {
      minHeight: 44,
      paddingVertical: 12,
      paddingHorizontal: 12,
      borderRadius: 8,
      backgroundColor: theme.palette.background.secondary,
      borderWidth: 1,
      borderColor: theme.palette.background.tertiary,
      marginBottom: 8,
      justifyContent: 'center',
    },
    rowLabel: {
      color: theme.palette.text.primary,
      fontSize: theme.typography.documentBody.fontSize,
    },
    readerScreen: {
      flex: 1,
    },
    readerBar: {
      flexDirection: 'row',
      alignItems: 'center',
      minHeight: 44,
      paddingHorizontal: 8,
      borderBottomWidth: 1,
      borderBottomColor: theme.palette.background.tertiary,
    },
    backButton: {
      minHeight: 44,
      minWidth: 44,
      paddingHorizontal: 8,
      justifyContent: 'center',
    },
    backLabel: {
      color: theme.palette.accent.link,
      fontSize: theme.typography.uiLabel.fontSize,
      fontWeight: theme.typography.uiLabel.fontWeight,
    },
    readerTitle: {
      flex: 1,
      color: theme.palette.text.secondary,
      fontSize: theme.typography.note.fontSize,
      marginLeft: 8,
    },
    reader: {
      flex: 1,
    },
  });
}

export default App;
