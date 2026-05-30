// Fabric Native Component view for ScaboReadingView.
//
// Owns the Swift ScaboReadingContentView (the UIView that adopts
// UIAccessibilityReadingContent + causesPageTurn) and is responsible for
// translating C++ Codegen props to ObjC/Swift and for emitting the
// page-change event back to JS through the Codegen EventEmitter.

#import "ScaboReadingViewComponentView.h"
#import "ScaboNative-Swift.h"

#import <react/renderer/components/ScaboNative/ComponentDescriptors.h>
#import <react/renderer/components/ScaboNative/EventEmitters.h>
#import <react/renderer/components/ScaboNative/Props.h>
#import <react/renderer/components/ScaboNative/RCTComponentViewHelpers.h>

#import <React/RCTFabricComponentsPlugins.h>

using namespace facebook::react;

@interface ScaboReadingViewComponentView () <RCTScaboReadingViewViewProtocol>
@end

@implementation ScaboReadingViewComponentView {
  ScaboReadingContentView *_contentView;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<ScaboReadingViewComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const ScaboReadingViewProps>();
    _props = defaultProps;

    _contentView = [[ScaboReadingContentView alloc] initWithFrame:self.bounds];
    _contentView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    __weak __typeof(self) weakSelf = self;
    _contentView.onPageChangeRequest = ^(NSString *direction, NSInteger fromPage) {
      [weakSelf emitPageChange:direction fromPage:fromPage];
    };

    self.contentView = _contentView;
  }
  return self;
}

- (NSObject *)accessibilityElement
{
  // The reading experience lives entirely on the inner Swift view: it adopts
  // UIAccessibilityReadingContent, carries the .causesPageTurn trait and
  // overrides accessibilityScroll. RCTViewComponentView applies every RN
  // accessibility prop to -accessibilityElement and, when that is the host
  // `self` (the default), promotes the host to a VoiceOver element — which
  // shadows the inner view and leaves the reading-content protocol dormant.
  // Returning _contentView makes the host accessibilitywise transparent
  // "in favour of some subview" exactly as the base-class contract documents,
  // so VoiceOver focuses the reading view and the JS accessibilityLabel (the
  // document name) lands on it rather than on the host.
  return _contentView;
}

- (void)prepareForRecycle
{
  // Fabric recycles component views across shadow nodes; without a reset the
  // inner view would briefly expose the previous document's page (and its
  // accessibilityLabel) to VoiceOver on the next mount.
  [_contentView reset];
  [super prepareForRecycle];
}

- (void)updateProps:(const Props::Shared &)props oldProps:(const Props::Shared &)oldProps
{
  const auto &newProps = static_cast<const ScaboReadingViewProps &>(*props);

  NSMutableArray<NSDictionary *> *segments =
      [NSMutableArray arrayWithCapacity:newProps.pageContent.size()];
  for (const auto &segment : newProps.pageContent) {
    [segments addObject:@{
      @"role" : [NSString stringWithUTF8String:segment.role.c_str()],
      @"text" : [NSString stringWithUTF8String:segment.text.c_str()],
      @"lengthCategory" : [NSString stringWithUTF8String:segment.lengthCategory.c_str()],
    }];
  }

  NSString *textColor = [NSString stringWithUTF8String:newProps.textColor.c_str()];
  CGFloat fontSize = (CGFloat)newProps.bodyFontSize;

  [_contentView updatePageContent:segments
                       pageNumber:newProps.pageNumber
                        textColor:textColor.length > 0 ? textColor : nil
                     bodyFontSize:fontSize > 0 ? fontSize : 18.0];

  [super updateProps:props oldProps:oldProps];
}

- (void)emitPageChange:(NSString *)direction fromPage:(NSInteger)fromPage
{
  if (!_eventEmitter) {
    return;
  }
  auto emitter = std::static_pointer_cast<const ScaboReadingViewEventEmitter>(_eventEmitter);
  emitter->onRequestPageChange({
    .direction = std::string([direction UTF8String]),
    .fromPage = (int32_t)fromPage,
  });
}

@end

Class<RCTComponentViewProtocol> ScaboReadingViewCls(void)
{
  return ScaboReadingViewComponentView.class;
}
