/**
 * Public wrapper around the NativeDiagnostics TurboModule — the JS entry point
 * to the unified OSLog diagnostic channel (subsystem "com.scabo.scabopdf").
 *
 * Two surfaces, mirroring ScaboLog.swift:
 *   - `logEvent` / `logError`: content-free structured events (counts, sizes,
 *     ms, error kinds, filenames — NEVER document text). Emitted in production
 *     and test mode; persisted by os_log so they reach Console.app and Settings
 *     → Privacy & Security → Analytics on a real device.
 *   - `snapshot`: heavy JSON (node/role tree, layout) that may carry content;
 *     a no-op unless `isTestMode`, and even then written to a file natively.
 *
 * Null-safe: when the native module is absent (Android, jest, a simulator with
 * stale pods) it falls back to `console` in __DEV__ and is otherwise inert, so
 * no call site ever crashes on a missing native side.
 */

import NativeDiagnostics from './NativeDiagnostics';

/** Stable category vocabulary. Kept in sync with ScaboLogCategory in Swift. */
export const LogCategory = {
  pdfExtraction: 'pdf-extraction',
  plugin: 'plugin',
  rendering: 'rendering',
  navigation: 'navigation',
  error: 'error',
  lifecycle: 'lifecycle',
  test: 'test',
} as const;
export type LogCategory = (typeof LogCategory)[keyof typeof LogCategory];

export type LogLevel = 'debug' | 'info' | 'default' | 'error' | 'fault';

/** Flat, content-free metadata. Values are scalars only. */
export type LogMetadata = Readonly<
  Record<string, string | number | boolean | null>
>;

interface Constants {
  testMode: boolean;
  subsystem: string;
}

const CONSTANTS: Constants = readConstants();

/** True only under the XCUITest harness (`--scabo-test-mode`). */
export const isTestMode: boolean = CONSTANTS.testMode;
export const subsystem: string = CONSTANTS.subsystem;

function readConstants(): Constants {
  const fallback: Constants = { testMode: false, subsystem: 'com.scabo.scabopdf' };
  if (NativeDiagnostics === null) {
    return fallback;
  }
  try {
    const c = NativeDiagnostics.getConstants();
    return {
      testMode: Boolean(c.testMode),
      subsystem: c.subsystem || fallback.subsystem,
    };
  } catch {
    return fallback;
  }
}

/**
 * Emit a content-free structured event. Pass only scalars in `metadata`; never
 * document text (privacy contract: content is never logged).
 */
export function logEvent(
  category: LogCategory,
  name: string,
  metadata: LogMetadata = {},
  level: LogLevel = 'default',
): void {
  if (NativeDiagnostics === null) {
    if (__DEV__) {
      console.log(`[scabo:${category}] ${name}`, metadata);
    }
    return;
  }
  try {
    NativeDiagnostics.log(category, level, name, JSON.stringify(metadata));
  } catch {
    // Logging must never throw into the caller.
  }
}

/** Emit a content-free error event at `.error` level (persisted). */
export function logError(name: string, metadata: LogMetadata = {}): void {
  logEvent(LogCategory.error, name, metadata, 'error');
}

/**
 * Test-mode-only heavy snapshot. `payload` is JSON-serialised and handed to the
 * native side, which writes it to a file under Caches. A no-op when test mode
 * is off (so production never pays the cost and never risks logging content).
 */
export function snapshot(
  category: LogCategory,
  name: string,
  payload: unknown,
): void {
  if (!isTestMode || NativeDiagnostics === null) {
    return;
  }
  try {
    NativeDiagnostics.snapshot(category, name, JSON.stringify(payload));
  } catch {
    // Never throw into the caller.
  }
}
