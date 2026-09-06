#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>

static void (*orig_SBDockView_layoutSubviews)(id, SEL);
static void (*orig_SBDockView_setFrame)(id, SEL, CGRect);
static void (*orig_SBHSearchBar_layoutSubviews)(id, SEL);
static void (*orig_SBIconListView_setContentOffset)(id, SEL, CGPoint);
static void (*orig_SBIconListView_didMoveToWindow)(id, SEL);

static const void *kI26GenerationKey = &kI26GenerationKey;

static CGFloat I26DockHeight(void) {
    return 92.0;
}

static UIView *I26DockForWindow(UIWindow *window) {
    Class cls = objc_getClass("SBDockView");
    if (!window || !cls) return nil;
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:window];
    while (queue.count) {
        UIView *view = queue.firstObject;
        [queue removeObjectAtIndex:0];
        if ([view isKindOfClass:cls]) return view;
        [queue addObjectsFromArray:view.subviews];
    }
    return nil;
}

static BOOL I26IsHomeIconList(UIView *view) {
    Class cls = objc_getClass("SBIconListView");
    if (!cls || ![view isKindOfClass:cls]) return NO;
    UIWindow *window = view.window;
    if (!window) return NO;

    UIView *dock = I26DockForWindow(window);
    if (!dock) return NO;

    CGRect listRect = [view convertRect:view.bounds toView:window];
    CGRect dockRect = [dock convertRect:dock.bounds toView:window];
    // Home-screen pages live above the dock. App/library tables and unrelated
    // SpringBoard lists are not touched by this tweak.
    return CGRectGetMaxY(listRect) <= CGRectGetMinY(dockRect) + 8.0;
}

static void I26ScheduleIndicatorHide(UIScrollView *scrollView) {
    NSNumber *generation = @((NSUInteger)(CACurrentMediaTime() * 1000000.0));
    objc_setAssociatedObject(scrollView, kI26GenerationKey, generation, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1500 * NSEC_PER_MSEC)),
                   dispatch_get_main_queue(), ^{
        if ([objc_getAssociatedObject(scrollView, kI26GenerationKey) isEqual:generation] &&
            I26IsHomeIconList(scrollView)) {
            scrollView.showsHorizontalScrollIndicator = NO;
            scrollView.showsVerticalScrollIndicator = NO;
        }
    });
}

static void i26_dockLayoutSubviews(id self, SEL _cmd) {
    orig_SBDockView_layoutSubviews(self, _cmd);

    SEL heightSel = NSSelectorFromString(@"dockHeight");
    SEL paddingSel = NSSelectorFromString(@"dockHeightPadding");
    if ([self respondsToSelector:heightSel] && [self respondsToSelector:paddingSel]) {
        // These are read-only layout inputs on the system class. We adjust the
        // actual dock frame after the system pass rather than swizzling getters,
        // avoiding recursion into SpringBoard's internal layout calculations.
        CGRect frame = [self frame];
        CGFloat desired = I26DockHeight() + 4.0;
        CGFloat bottom = CGRectGetMaxY(frame);
        if (frame.size.height < desired - 1.0 || frame.size.height > desired + 12.0) {
            frame.size.height = desired;
            frame.origin.y = bottom - desired;
            [self setFrame:frame];
        }
    }

    self.layer.cornerCurve = kCACornerCurveContinuous;
    self.layer.cornerRadius = MIN(28.0, CGRectGetHeight(self.bounds) * 0.42);
    self.clipsToBounds = YES;
}

static void i26_dockSetFrame(id self, SEL _cmd, CGRect frame) {
    // Permit SpringBoard to place the dock normally. The layout hook performs
    // the controlled height adjustment once the containing geometry is known.
    orig_SBDockView_setFrame(self, _cmd, frame);
}

static void i26_searchLayoutSubviews(id self, SEL _cmd) {
    orig_SBHSearchBar_layoutSubviews(self, _cmd);

    UIWindow *window = [(UIView *)self window];
    UIView *dock = I26DockForWindow(window);
    if (!window || !dock) return;

    CGRect dockRect = [dock convertRect:dock.bounds toView:window];
    CGRect current = [(UIView *)self convertRect:((UIView *)self).bounds toView:window];
    CGFloat height = CGRectGetHeight(current);
    if (height <= 0.0) return;

    // iOS 26 places its Home Screen search affordance as a distinct control
    // immediately above the dock. Keep this geometry independent from the
    // App Library's full-screen search controller.
    current.size.width = MIN(220.0, CGRectGetWidth(window.bounds) - 32.0);
    current.size.height = height;
    current.origin.x = (CGRectGetWidth(window.bounds) - current.size.width) * 0.5;
    current.origin.y = CGRectGetMinY(dockRect) - height - 10.0;

    UIView *superview = [(UIView *)self superview];
    if (superview) {
        CGRect local = [window convertRect:current toView:superview];
        [(UIView *)self setFrame:local];
    }
}

static void i26_iconListSetContentOffset(id self, SEL _cmd, CGPoint offset) {
    UIScrollView *scroll = (UIScrollView *)self;
    if (I26IsHomeIconList(scroll)) {
        scroll.showsHorizontalScrollIndicator = YES;
        scroll.showsVerticalScrollIndicator = YES;
    }
    orig_SBIconListView_setContentOffset(self, _cmd, offset);
    if (I26IsHomeIconList(scroll)) I26ScheduleIndicatorHide(scroll);
}

static void i26_iconListDidMoveToWindow(id self, SEL _cmd) {
    orig_SBIconListView_didMoveToWindow(self, _cmd);
    UIScrollView *scroll = (UIScrollView *)self;
    if (scroll.window && I26IsHomeIconList(scroll)) {
        scroll.showsHorizontalScrollIndicator = NO;
        scroll.showsVerticalScrollIndicator = NO;
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
        I26HookIfAvailable("SBDockView", @selector(layoutSubviews), (IMP)i26_dockLayoutSubviews,
                           (IMP *)&orig_SBDockView_layoutSubviews);
        I26HookIfAvailable("SBDockView", @selector(setFrame:), (IMP)i26_dockSetFrame,
                           (IMP *)&orig_SBDockView_setFrame);
        I26HookIfAvailable("SBHSearchBar", @selector(layoutSubviews), (IMP)i26_searchLayoutSubviews,
                           (IMP *)&orig_SBHSearchBar_layoutSubviews);
        I26HookIfAvailable("SBIconListView", @selector(setContentOffset:), (IMP)i26_iconListSetContentOffset,
                           (IMP *)&orig_SBIconListView_setContentOffset);
        I26HookIfAvailable("SBIconListView", @selector(didMoveToWindow), (IMP)i26_iconListDidMoveToWindow,
                           (IMP *)&orig_SBIconListView_didMoveToWindow);
    }
}
