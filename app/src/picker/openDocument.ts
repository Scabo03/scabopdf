/**
 * Wraps the iOS system document picker (UIDocumentPickerViewController via
 * @react-native-documents/picker) for the "open a .scabopdf.json file" flow.
 *
 * In iOS "import" mode the picker copies the chosen file into the app's
 * temporary container; the returned URI is local and can be read directly
 * with fetch. The wrapper returns the file's raw text plus a name for the UI.
 *
 * The user canceling the picker is not an error: the wrapper returns null
 * and the caller renders the home screen unchanged.
 */

import { errorCodes, pick } from '@react-native-documents/picker';

export interface PickedDocument {
  /** Original file name as it appeared in the picker, for the recents list. */
  name: string;
  /** Local URI of the imported copy in the app sandbox. */
  uri: string;
  /** Raw text content of the file (will be fed to parseDocument). */
  content: string;
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

  const response = await fetch(picked.uri);
  const content = await response.text();

  return {
    name: picked.name ?? 'documento.scabopdf.json',
    uri: picked.uri,
    content,
  };
}
