// YMOverlayHelpers — OverlayButtons.x helpers: speed/quality labels, transcript,
// gear-frame locating, button creation/icons, frosted glass, share pill.

@class YTFormat3CaptionViewController, YTInlinePlayerBarContainerView, YTMainAppControlsOverlayView, YTPlayerViewController, YTQTMButton, YTFrostedGlassView, YMOverlayButtonSpec, MLFormat;

@interface YMOverlayHelpers : NSObject
// "1.25x" label for a playback rate.
+ (NSString *)speedLabel:(float)rate;
// Applies a rate to the shared speed state and posts the speed-label notification.
+ (void)didSelectRate:(float)rate;
// Shows the caption transcript in an alert with a copy action (YouGetCaption).
+ (void)showTranscript:(YTFormat3CaptionViewController *)cvc;
// Player view controller hosting the given controls overlay.
+ (YTPlayerViewController *)playerVCFromOverlay:(YTMainAppControlsOverlayView *)overlay;
// Recursively records the rightmost top-row YTQTMButton frame into bestFrame (gear fallback).
+ (void)scanForGearFrame:(UIView *)view overlay:(YTMainAppControlsOverlayView *)overlay topRegionMaxY:(CGFloat)topRegionMaxY bestFrame:(CGRect *)bestFrame;
// Overflow (gear) button frame in the overlay; CGRectNull when not found.
+ (CGRect)gearFrameInOverlay:(YTMainAppControlsOverlayView *)overlay;
// Largest size (up to maxSize) at which text fits; YT sans font when available.
+ (UIFont *)overlayTextButtonFont:(NSString *)text maxSize:(CGSize)maxSize;
// Sets an SF Symbol icon; "moon" turns red while the sleep timer is active.
+ (void)setOverlayButtonIcon:(YTQTMButton *)button symbolName:(NSString *)symbolName;
// Creates the spec's button (text or icon), wires ymOverlayButtonTapped: and installs it in parent.
+ (YTQTMButton *)createOverlayButton:(UIView *)parent spec:(YMOverlayButtonSpec *)spec;
// Creates/attaches a frosted-glass effect to view when the class is available.
+ (void)maybeApplyFrostedGlass:(YTFrostedGlassView *)frostedGlassView toView:(UIView *)view;
// Sizes the frosted pill to the union of the bottom-row buttons; removes it when empty.
+ (void)frostedBackgroundUpdate:(YTInlinePlayerBarContainerView *)view buttons:(NSArray<UIView *> *)buttons;
// Unhides and re-icons bottom-row buttons after YouTube hides the bar's icons.
+ (void)revealBottomOverlayButtons:(YTInlinePlayerBarContainerView *)view;
// Fades the bottom-row buttons and frosted pill to alpha.
+ (void)setBottomOverlayButtonsAlpha:(YTInlinePlayerBarContainerView *)view alpha:(CGFloat)alpha;
// Registers the bottom bar's speed/quality/sleep (+ sponsor timer) notification observers.
+ (void)setBottomNotifications:(YTInlinePlayerBarContainerView *)view;
// Shows a success/error YouMod pill for the share flow.
+ (void)showShareNotification:(NSString *)message success:(BOOL)success;
// Compact quality label for a format ("4K", "FHD", "HD", FPS/HDR handling).
+ (NSString *)compactQualityLabel:(MLFormat *)format;
@end
