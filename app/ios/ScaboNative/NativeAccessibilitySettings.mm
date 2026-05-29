#import "NativeAccessibilitySettings.h"

#import <UIKit/UIKit.h>
#import <ScaboNative/ScaboNative.h>

using namespace facebook::react;

@interface NativeAccessibilitySettings () <NativeAccessibilitySettingsSpec>
@end

@implementation NativeAccessibilitySettings {
  BOOL _hasListeners;
}

RCT_EXPORT_MODULE()

+ (BOOL)requiresMainQueueSetup
{
  return YES;
}

- (NSArray<NSString *> *)supportedEvents
{
  return @[ @"change" ];
}

- (void)startObserving
{
  _hasListeners = YES;
  NSNotificationCenter *centre = NSNotificationCenter.defaultCenter;
  [centre addObserver:self
             selector:@selector(emitChange)
                 name:UIAccessibilityDarkerSystemColorsStatusDidChangeNotification
               object:nil];
  [centre addObserver:self
             selector:@selector(emitChange)
                 name:UIAccessibilityReduceMotionStatusDidChangeNotification
               object:nil];
  [centre addObserver:self
             selector:@selector(emitChange)
                 name:UIAccessibilityReduceTransparencyStatusDidChangeNotification
               object:nil];
}

- (void)stopObserving
{
  _hasListeners = NO;
  [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (NSDictionary *)currentSettings
{
  return @{
    @"isDarkerSystemColorsEnabled" : @(UIAccessibilityDarkerSystemColorsEnabled()),
    @"isReduceMotionEnabled" : @(UIAccessibilityIsReduceMotionEnabled()),
    @"isReduceTransparencyEnabled" : @(UIAccessibilityIsReduceTransparencyEnabled()),
  };
}

// Codegen NativeAccessibilitySettingsSpec entry point.
- (NSDictionary *)getCurrent
{
  return [self currentSettings];
}

- (void)emitChange
{
  if (_hasListeners) {
    [self sendEventWithName:@"change" body:[self currentSettings]];
  }
}

// TurboModule registration for New Architecture.
- (std::shared_ptr<TurboModule>)getTurboModule:(const ObjCTurboModule::InitParams &)params
{
  return std::make_shared<NativeAccessibilitySettingsSpecJSI>(params);
}

@end
