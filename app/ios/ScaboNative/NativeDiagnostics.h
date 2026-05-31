// TurboModule that bridges the JS pipeline onto the unified OSLog diagnostic
// channel (subsystem "com.scabo.scabopdf"). The heavy lifting — os.Logger
// emission, test-mode gating, snapshot files — lives in ScaboLog.swift; this
// ObjC++ shim exposes it to the New Architecture as synchronous, fire-and-forget
// methods.

#import <React/RCTBridgeModule.h>

NS_ASSUME_NONNULL_BEGIN

@interface NativeDiagnostics : NSObject <RCTBridgeModule>
@end

NS_ASSUME_NONNULL_END
