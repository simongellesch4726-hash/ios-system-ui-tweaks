#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>

static const void *kRPFTrackedLabelKey = &kRPFTrackedLabelKey;
static const void *kRPFControllerKey = &kRPFControllerKey;
static const void *kRPFSessionStartKey = &kRPFSessionStartKey;
static const void *kRPFInternalUpdateKey = &kRPFInternalUpdateKey;

static void (*orig_SBRecordingIndicator_updateVisibility)(id, SEL, BOOL);
static void (*orig_SBRecordingIndicator_updateVisibilitySkip)(id, SEL, BOOL, BOOL);
static void (*orig_UILabel_setText)(UILabel *, SEL, NSString *);

static BOOL RPFParseElapsed(NSString *text, NSInteger *seconds) {
    if (![text isKindOfClass:NSString.class]) return NO;
    NSArray<NSString *> *parts = [text componentsSeparatedByString:@":"];
    if (parts.count != 2 || parts[0].length == 0 || parts[0].length > 3 || parts[1].length != 2) return NO;

    NSCharacterSet *digits = NSCharacterSet.decimalDigitCharacterSet;
    if ([parts[0] rangeOfCharacterFromSet:digits.invertedSet].location != NSNotFound ||
        [parts[1] rangeOfCharacterFromSet:digits.invertedSet].location != NSNotFound) return NO;

    NSInteger minutes = parts[0].integerValue;
    NSInteger secs = parts[1].integerValue;
    if (secs < 0 || secs > 59) return NO;
    if (seconds) *seconds = minutes * 60 + secs;
    return YES;
}

static void RPFCollectTimerLabels(UIView *view, NSMutableArray<UILabel *> *labels) {
    if ([view isKindOfClass:UILabel.class]) {
        UILabel *label = (UILabel *)view;
        NSInteger seconds = 0;
        if (RPFParseElapsed(label.text, &seconds)) [labels addObject:label];
    }
    for (UIView *subview in view.subviews) RPFCollectTimerLabels(subview, labels);
}

static NSArray<UILabel *> *RPFLabelsForController(id controller) {
    SEL indicatorSelector = NSSelectorFromString(@"indicatorView");
    if (![controller respondsToSelector:indicatorSelector]) return @[];

    UIView *indicator = ((id (*)(id, SEL))objc_msgSend)(controller, indicatorSelector);
    if (![indicator isKindOfClass:UIView.class]) return @[];

    NSMutableArray<UILabel *> *labels = [NSMutableArray array];
    RPFCollectTimerLabels(indicator, labels);
    for (UILabel *label in labels) {
        objc_setAssociatedObject(label, kRPFTrackedLabelKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(label, kRPFControllerKey, controller, OBJC_ASSOCIATION_ASSIGN);
    }
    return labels;
}

static CFTimeInterval RPFSessionStartForController(id controller) {
    NSNumber *stored = objc_getAssociatedObject(controller, kRPFSessionStartKey);
    return stored ? stored.doubleValue : 0;
}

static void RPFSetSessionStart(id controller, CFTimeInterval start) {
    objc_setAssociatedObject(controller, kRPFSessionStartKey, @(start), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void RPFRewriteLabel(UILabel *label, id controller) {
    if (!objc_getAssociatedObject(label, kRPFTrackedLabelKey) || !controller) return;
    if ([objc_getAssociatedObject(label, kRPFInternalUpdateKey) boolValue]) return;

    NSInteger displayed = 0;
    if (!RPFParseElapsed(label.text, &displayed)) return;

    CFTimeInterval now = CACurrentMediaTime();
    CFTimeInterval start = RPFSessionStartForController(controller);
    if (start <= 0) {
        start = now - displayed;
        RPFSetSessionStart(controller, start);
    }

    NSInteger expected = MAX(0, (NSInteger)floor(now - start));
    // The system may recreate the visual timer after the indicator is hidden.
    // Keep the persistent controller session as the source of truth in that case.
    if (displayed > expected + 2) {
        start = now - displayed;
        RPFSetSessionStart(controller, start);
        expected = displayed;
    }

    NSString *replacement = [NSString stringWithFormat:@"%ld:%02ld", (long)(expected / 60), (long)(expected % 60)];
    if ([label.text isEqualToString:replacement]) return;

    objc_setAssociatedObject(label, kRPFInternalUpdateKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    label.text = replacement;
    objc_setAssociatedObject(label, kRPFInternalUpdateKey, nil, OBJC_ASSOCIATION_ASSIGN);
}

static void RPFRefreshController(id controller) {
    for (UILabel *label in RPFLabelsForController(controller)) RPFRewriteLabel(label, controller);
}

static void rpf_updateVisibility(id self, SEL _cmd, BOOL visible) {
    orig_SBRecordingIndicator_updateVisibility(self, _cmd, visible);
    if (!visible) return;
    dispatch_async(dispatch_get_main_queue(), ^{ RPFRefreshController(self); });
}

static void rpf_updateVisibilitySkip(id self, SEL _cmd, BOOL visible, BOOL skip) {
    orig_SBRecordingIndicator_updateVisibilitySkip(self, _cmd, visible, skip);
    if (!visible) return;
    dispatch_async(dispatch_get_main_queue(), ^{ RPFRefreshController(self); });
}

static void rpf_setText(UILabel *self, SEL _cmd, NSString *text) {
    orig_UILabel_setText(self, _cmd, text);
    if (!objc_getAssociatedObject(self, kRPFTrackedLabelKey)) return;
    if ([objc_getAssociatedObject(self, kRPFInternalUpdateKey) boolValue]) return;
    RPFRewriteLabel(self, objc_getAssociatedObject(self, kRPFControllerKey));
}

%ctor {
    @autoreleasepool {
        Class controller = objc_getClass("SBRecordingIndicatorViewController");
        if (!controller) return;

        SEL visibility = NSSelectorFromString(@"updateIndicatorVisibility:");
        if (class_respondsToSelector(controller, visibility)) {
            MSHookMessageEx(controller, visibility, (IMP)rpf_updateVisibility, (IMP *)&orig_SBRecordingIndicator_updateVisibility);
        }

        SEL visibilitySkip = NSSelectorFromString(@"updateIndicatorVisibility:skipFadeOutAnimation:");
        if (class_respondsToSelector(controller, visibilitySkip)) {
            MSHookMessageEx(controller, visibilitySkip, (IMP)rpf_updateVisibilitySkip, (IMP *)&orig_SBRecordingIndicator_updateVisibilitySkip);
        }

        MSHookMessageEx(UILabel.class, @selector(setText:), (IMP)rpf_setText, (IMP *)&orig_UILabel_setText);
    }
}
