// Implementation of the NativeAccessibilitySettings TurboModule.
//
// Exposes the iOS system accessibility flags React Native core does not
// surface — most importantly isDarkerSystemColorsEnabled (Settings ->
// Accessibility -> Display & Text Size -> Increase Contrast), which the
// theme system reads to auto-select the high-contrast palette.

#import <React/RCTEventEmitter.h>
#import <React/RCTBridgeModule.h>

NS_ASSUME_NONNULL_BEGIN

@interface NativeAccessibilitySettings : RCTEventEmitter <RCTBridgeModule>
@end

NS_ASSUME_NONNULL_END
