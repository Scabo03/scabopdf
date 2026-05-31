// TurboModule that extracts structured text from a PDF using Apple PDFKit.
//
// React Native core cannot read PDFs and the Layer 1 Python pipeline does not
// run on iOS, so this module is the on-device entry point that turns a picked
// .pdf into structured text (per page, per line, with font size + weight). The
// heavy work lives in ScaboPdfExtractor.swift; this ObjC++ shim exposes it to
// the New Architecture and runs it off the main thread.

#import <React/RCTBridgeModule.h>

NS_ASSUME_NONNULL_BEGIN

@interface NativePdfExtractor : NSObject <RCTBridgeModule>
@end

NS_ASSUME_NONNULL_END
