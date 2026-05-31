#import "NativePdfExtractor.h"

#import <ScaboNative/ScaboNative.h>
#import "ScaboNative-Swift.h"

using namespace facebook::react;

@interface NativePdfExtractor () <NativePdfExtractorSpec>
@end

@implementation NativePdfExtractor

RCT_EXPORT_MODULE()

// Pure compute: nothing here touches UIKit on the main thread at setup time, so
// the module can initialise off the main queue.
+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

// Codegen NativePdfExtractorSpec entry point. Runs the PDFKit extraction on a
// background queue so a large manual does not block the UI, then resolves the
// JSON payload (or rejects with a readable, VoiceOver-friendly message).
- (void)extractToJson:(NSString *)uri
              resolve:(RCTPromiseResolveBlock)resolve
               reject:(RCTPromiseRejectBlock)reject
{
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    NSError *error = nil;
    NSString *json = [ScaboPdfExtractor extractFromUri:uri error:&error];
    if (json == nil) {
      reject(@"pdf_extraction_failed",
             error.localizedDescription ?: @"Estrazione PDF non riuscita.",
             error);
      return;
    }
    resolve(json);
  });
}

// TurboModule registration for the New Architecture.
- (std::shared_ptr<TurboModule>)getTurboModule:(const ObjCTurboModule::InitParams &)params
{
  return std::make_shared<NativePdfExtractorSpecJSI>(params);
}

@end
