#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

static const void *kI26ScrollGenerationKey = &kI26ScrollGenerationKey;

static void (*orig_SBDockView_layoutSubviews)(UIView *, SEL);
static void (*orig_SBHSearchBar_layoutSubviews)(UIView *, SEL);
static void (*orig_SBIconScrollView_setContentOffset)(UIScrollView *, SEL, CGPoint);
static void (*orig_SBIconScrollView_didMoveToWindow)(UIScrollView *, SEL);

static UIView *I26FindFirstViewOfClass(UIView *view, Class target) {
    if (!view || !target) return nil;
    if ([view isKindOfClass:target]) return view;
    for (UIView *subview in view.subviews) {
        UIView *found = I26FindFirstViewOfClass(subview, target);
        if (found) return found;
    }
    return nil;
}

static UIView *I26DockViewInWindow(UIWindow *window) {
    Class dockClass = objc_getClass("SBDockView");
    return I26FindFirstViewOfClass(window, dockClass);
}

static void I26ApplyDockAppearance(UIView *dock) {
    if (!dock.window) return;

    // iOS 15.7.3 exposes SBDockView's backgroundView and dock layout methods.
    // Use dynamic dispatch so the tweak remains load-safe when the implementation changes.
    SEL backgroundSelector = NSSelectorFromString(@"backgroundView");
    UIView *background = nil;
    if ([dock respondsToSelector:backgroundSelector]) {
        background = ((id (*)(id, SEL))objc_msgSend)(dock, backgroundSelector);
    }
    UIView *target = [background isKindOfClass:UIView.class] ? background : dock;
    target.layer.cornerCurve = kCACornerCurveContinuous;
    target.layer.cornerRadius = MIN(26.0, CGRectGetHeight(target.bounds) * 0.45);
    target.clipsToBounds = YES;
}

static void i26_dockLayoutSubviews(UIView *self, SEL _cmd) {
    orig_SBDockView_layoutSubviews(self, _cmd);
    I26ApplyDockAppearance(self);
}

static void I26PositionSearchAboveDock(UIView *search) {
    UIWindow *window = search.window;
    UIView *dock = I26DockViewInWindow(window);
    if (!dock || dock.hidden || CGRectIsEmpty(dock.bounds)) return;

    CGRect dockFrame = [dock convertRect:dock.bounds toView:window];
    CGRect searchFrame = [search convertRect:search.bounds toView:window];
    CGFloat margin = 10.0;
    searchFrame.origin.y = MAX(window.safeAreaInsets.top, CGRectGetMinY(dockFrame) - CGRectGetHeight(searchFrame) - margin);
    searchFrame.size.width = MIN(CGRectGetWidth(searchFrame), CGRectGetWidth(window.bounds) - 32.0);
    searchFrame.origin.x = (CGRectGetWidth(window.bounds) - searchFrame.size.width) * 0.5;

    CGRect localFrame = [window convertRect:searchFrame toView:search.superview];
    if (!CGRectEqualToRect(search.frame, localFrame)) search.frame = localFrame;
}

static void i26_searchLayoutSubviews(UIView *self, SEL _cmd) {
    orig_SBHSearchBar_layoutSubviews(self, _cmd);
    I26PositionSearchAboveDock(self);
}

static void I26ScheduleIndicatorHide(UIScrollView *scrollView) {
    NSNumber *generation = @(CACurrentMediaTime() * 1000000.0);
    objc_setAssociatedObject(scrollView, kI26ScrollGenerationKey, generation, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1500 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        if ([objc_getAssociatedObject(scrollView, kI26ScrollGenerationKey) isEqual:generation]) {
            scrollView.showsHorizontalScrollIndicator = NO;
            scrollView.showsVerticalScrollIndicator = NO;
        }
    });
}

static void i26_setContentOffset(UIScrollView *self, SEL _cmd, CGPoint offset) {
    self.showsHorizontalScrollIndicator = YES;
    self.showsVerticalScrollIndicator = YES;
    orig_SBIconScrollView_setContentOffset(self, _cmd, offset);
    I26ScheduleIndicatorHide(self);
}

static void i26_didMoveToWindow(UIScrollView *self, SEL _cmd) {
    orig_SBIconScrollView_didMoveToWindow(self, _cmd);
    if (self.window) {
        self.showsHorizontalScrollIndicator = NO;
        self.showsVerticalScrollIndicator = NO;
    }
}

static void I26HookIfAvailable(const char *className, SEL selector, IMP replacement, IMP *original) {
    Class cls = objc_getClass(className);
    if (cls && class_respondsToSelector(cls, selector)) {
        MSHookMessageEx(cls, selector, replacement, original);
    }
}

%ctor {
    @autoreleasepool {
        // These classes are present in the iOS 15–16 SpringBoardHome runtime.
        I26HookIfAvailable("SBDockView", @selector(layoutSubviews), (IMP)i26_dockLayoutSubviews, (IMP *)&orig_SBDockView_layoutSubviews);
        I26HookIfAvailable("SBHSearchBar", @selector(layoutSubviews), (IMP)i26_searchLayoutSubviews, (IMP *)&orig_SBHSearchBar_layoutSubviews);
        I26HookIfAvailable("SBIconScrollView", @selector(setContentOffset:), (IMP)i26_setContentOffset, (IMP *)&orig_SBIconScrollView_setContentOffset);
        I26HookIfAvailable("SBIconScrollView", @selector(didMoveToWindow), (IMP)i26_didMoveToWindow, (IMP *)&orig_SBIconScrollView_didMoveToWindow);
    }
}
