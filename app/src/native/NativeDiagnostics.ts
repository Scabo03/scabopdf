/**
 * Codegen spec for the TurboModule that bridges the TypeScript pipeline onto the
 * unified OSLog diagnostic channel (subsystem "com.scabo.scabopdf", implemented
 * in ScaboLog.swift). It is the JS half of objective 5: parseDocument /
 * buildLayout / paginate / the plugins emit their events and (test-mode)
 * snapshots through the very same Apple `os.Logger` the Swift extractor uses, so
 * one stream covers the whole chain.
 *
 * The methods are synchronous and return void: logging is fire-and-forget and a
 * Promise round-trip per event would be wasteful. `getConstants` exposes the
 * native-resolved test-mode flag so the TS side gates verbose snapshots exactly
 * as the Swift side does.
 *
 * Privacy contract (docs/ARCHITECTURE.md): `log` payloads are content-free
 * (counts, sizes, ms, error kinds, filenames); `snapshot` may carry document
 * content and is a no-op outside test mode.
 *
 * Spec file naming: Native*.ts (Codegen convention). Registered module name is
 * 'NativeDiagnostics'.
 */

import { TurboModule, TurboModuleRegistry } from 'react-native';

export interface Spec extends TurboModule {
  /**
   * Native-resolved constants. `testMode` is true only when the app was
   * launched with the `--scabo-test-mode` argument (the XCUITest harness);
   * `subsystem` is the OSLog subsystem string.
   */
  getConstants(): { testMode: boolean; subsystem: string };

  /**
   * Emit a content-free structured event onto the OSLog channel.
   * @param category one of the stable category strings (see diag.ts).
   * @param level 'debug' | 'info' | 'default' | 'error' | 'fault'.
   * @param name short, stable event identifier.
   * @param metadataJson already-serialised, content-free JSON object string.
   */
  log(category: string, level: string, name: string, metadataJson: string): void;

  /**
   * Test-mode-only heavy snapshot (node/role tree, layout, …). The native side
   * writes `json` to a file under Caches and emits only a content-free
   * `snapshot_written` event to the stream. A no-op when test mode is off.
   */
  snapshot(category: string, name: string, json: string): void;
}

// .get (not .getEnforcing) so importing the spec never throws on Android or in
// the jest environment where the native module is not registered; the wrapper
// (diag.ts) falls back to console.
export default TurboModuleRegistry.get<Spec>('NativeDiagnostics');
