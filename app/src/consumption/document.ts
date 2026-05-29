/**
 * Loading and validating a ScaboPDF document (the Layer 1 -> Layer 2 JSON).
 *
 * `parseDocument` is the single entry point the app uses to turn a file's
 * contents into a validated, typed document. It never throws; every failure
 * is returned as a `DocumentLoadError` carrying an accessible, user-facing
 * Italian message (UI language is Italian in phase 1, SPECS § 0).
 */

import type { ScabopdfDocument } from './schema.generated';
import { validateAgainstSchema } from './validate';
import type { SchemaValidationError } from './validate';

/** The single contract version this build of the app understands. */
export const SUPPORTED_SCHEMA_VERSION = '0.7.0';

export type DocumentLoadError =
  | { kind: 'invalid_json'; message: string }
  | { kind: 'unsupported_version'; message: string; foundVersion: string }
  | {
      kind: 'schema_validation';
      message: string;
      errors: SchemaValidationError[];
    };

export type DocumentLoadResult =
  | { ok: true; document: ScabopdfDocument; warnings: string[] }
  | { ok: false; error: DocumentLoadError };

/**
 * Parses and validates a document.
 *
 * @param input either the raw file contents (a JSON string) or an
 * already-parsed object.
 */
export function parseDocument(input: string | unknown): DocumentLoadResult {
  let data: unknown;
  if (typeof input === 'string') {
    try {
      data = JSON.parse(input);
    } catch {
      return {
        ok: false,
        error: {
          kind: 'invalid_json',
          message:
            'Il file non è un documento ScaboPDF valido: non contiene dati JSON leggibili.',
        },
      };
    }
  } else {
    data = input;
  }

  // Peek the version before full validation so a document from another schema
  // version gets a clear message instead of a generic "const" mismatch buried
  // in the validation errors.
  const foundVersion = peekSchemaVersion(data);
  if (foundVersion !== undefined && foundVersion !== SUPPORTED_SCHEMA_VERSION) {
    return {
      ok: false,
      error: {
        kind: 'unsupported_version',
        foundVersion,
        message: `Questo documento usa la versione di formato ${foundVersion}, diversa da quella supportata dall'app (${SUPPORTED_SCHEMA_VERSION}). Aggiorna l'app oppure rigenera il documento.`,
      },
    };
  }

  const errors = validateAgainstSchema(data);
  if (errors.length > 0) {
    return {
      ok: false,
      error: {
        kind: 'schema_validation',
        message:
          'Il file non rispetta il formato previsto per un documento ScaboPDF.',
        errors,
      },
    };
  }

  const document = data as ScabopdfDocument;
  return { ok: true, document, warnings: document.warnings ?? [] };
}

function peekSchemaVersion(data: unknown): string | undefined {
  if (typeof data === 'object' && data !== null && 'schema_version' in data) {
    const value = (data as { schema_version: unknown }).schema_version;
    return typeof value === 'string' ? value : undefined;
  }
  return undefined;
}
