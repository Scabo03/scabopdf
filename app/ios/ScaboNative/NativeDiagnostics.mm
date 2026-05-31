#import "NativeDiagnostics.h"

#import <ScaboNative/ScaboNative.h>
#import "ScaboNative-Swift.h"

using namespace facebook::react;

@interface NativeDiagnostics () <NativeDiagnosticsSpec>
@end

@implementation NativeDiagnostics

RCT_EXPORT_MODULE()

// Pure logging; nothing here needs the main thread at setup time.
+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

// Native-resolved constants exposed to JS so the TS pipeline gates verbose
// snapshots exactly as the Swift side does.
- (NSDictionary *)getConstants
{
  return @{
    @"testMode" : @([ScaboLog isTestMode]),
    @"subsystem" : [ScaboLog subsystem],
  };
}

- (facebook::react::ModuleConstants<JS::NativeDiagnostics::Constants>)constantsToExport
{
  return [self getConstants];
}

// Content-free structured event onto the OSLog channel. Fire-and-forget.
- (void)log:(NSString *)category
      level:(NSString *)level
       name:(NSString *)name
metadataJson:(NSString *)metadataJson
{
  [ScaboLog emitWithCategoryName:category
                       levelName:level
                            name:name
                    metadataJSON:metadataJson ?: @"{}"];
}

// Test-mode-only heavy snapshot (written to a file by the Swift side; a no-op
// when test mode is off).
- (void)snapshot:(NSString *)category
            name:(NSString *)name
            json:(NSString *)json
{
  [ScaboLog snapshotWithCategoryName:category name:name json:json ?: @""];
}

- (std::shared_ptr<TurboModule>)getTurboModule:(const ObjCTurboModule::InitParams &)params
{
  return std::make_shared<NativeDiagnosticsSpecJSI>(params);
}

@end
