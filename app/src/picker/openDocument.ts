/**
 * Wraps the iOS system document picker (UIDocumentPickerViewController via
 * @react-native-documents/picker) for the "open a document" flow.
 *
 * The app accepts two kinds of file: a `.pdf` (read on device by the native
 * PDFKit extractor) and a `.scabopdf.json` (the Layer 1 pipeline output). The
 * wrapper detects which one was picked and returns enough for the caller to
 * route it: for a PDF the local URI (the native side reads the file directly);
 * for a JSON the raw text content (fed to parseDocument).
 *
 * In iOS "import" mode the picker copies the chosen file into the app's
 * temporary container; the returned URI is local. The picker is intentionally
 * left unrestricted so no existing `.scabopdf.json` can ever become unpickable
 * (backward compat is absolute); an unexpected file routes to the JSON path and
 * surfaces a readable parse error.
 *
 * The user canceling the picker is not an error: the wrapper returns null and
 * the caller renders the home screen unchanged.
 */

import { errorCodes, pick } from '@react-native-documents/picker';

/** Which reading path a picked file routes to. */
export type PickedKind = 'pdf' | 'scabopdf';

export interface PickedDocument {
  /** Original file name as it appeared in the picker, for the recents list. */
  name: string;
  /** Local URI of the imported copy in the app sandbox. */
  uri: string;
  /** Detected kind, deciding the reading path. */
  kind: PickedKind;
  /**
   * Raw text content of the file, for `kind === 'scabopdf'` (fed to
   * parseDocument). `null` for a PDF, whose bytes are read natively from `uri`.
   */
  content: string | null;
}

export async function openDocumentFromPicker(): Promise<PickedDocument | null> {
  let results;
  try {
    results = await pick({ mode: 'import' });
  } catch (error) {
    if (
      error !== null &&
      typeof error === 'object' &&
      'code' in error &&
      (error as { code: unknown }).code === errorCodes.OPERATION_CANCELED
    ) {
      return null;
    }
    throw error;
  }

  const picked = results[0];
  if (picked === undefined) {
    return null;
  }

  const name = picked.name ?? 'documento.scabopdf.json';
  const kind = detectKind(name, picked.type);

  if (kind === 'pdf') {
    // The native extractor reads the file from the URI; no text fetch here.
    return { name, uri: picked.uri, kind, content: null };
  }

  const response = await fetch(picked.uri);
  const content = await response.text();
  return { name, uri: picked.uri, kind, content };
}

/** A PDF is recognised by its `.pdf` extension, with the MIME type as backup. */
function detectKind(name: string, mimeType?: string | null): PickedKind {
  if (name.toLowerCase().endsWith('.pdf')) {
    return 'pdf';
  }
  if (mimeType != null && mimeType.toLowerCase().includes('pdf')) {
    return 'pdf';
  }
  return 'scabopdf';
}
