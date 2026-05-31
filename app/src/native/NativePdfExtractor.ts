/**
 * Codegen spec for the TurboModule that extracts text from a PDF on device
 * using Apple PDFKit. React Native core cannot read PDFs and Layer 1's Python
 * pipeline does not run on iOS, so this module is the on-device entry point
 * that turns a picked .pdf into structured text the Generic plugin maps onto
 * the ContentSegment model.
 *
 * The result is returned as a JSON string rather than a nested Codegen object.
 * The extraction is an array of pages, each an array of line records (text +
 * font size + weight); a JSON string keeps the bridge simple and sidesteps
 * Codegen's nested-collection constraints. The JS wrapper (pdfExtraction.ts)
 * parses it into typed structures.
 *
 * Spec file naming: Native*.ts (Codegen convention for TurboModules). The
 * registered module name is 'NativePdfExtractor'. Extraction runs off the main
 * thread on the native side so a large manual does not block the UI.
 */

import { TurboModule, TurboModuleRegistry } from 'react-native';

export interface Spec extends TurboModule {
  /**
   * Extracts the PDF at `uri` (a local file:// URI from the document picker)
   * and resolves a JSON string of the shape
   * `{ pageCount, pages: [{ pageIndex, lines: [{ text, fontSize, bold }] }] }`.
   * Rejects with a readable message when the PDF cannot be opened or read.
   */
  extractToJson(uri: string): Promise<string>;
}

// .get (not .getEnforcing) so importing the spec does not throw on Android or
// in the jest environment, where the native module is not registered. The TS
// wrapper raises a readable error when the module is absent.
export default TurboModuleRegistry.get<Spec>('NativePdfExtractor');
