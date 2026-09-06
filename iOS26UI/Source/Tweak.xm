#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const void *kI26LastScrollKey = &kI26LastScrollKey;

static BOOL I26IsSpringBoardHomeScrollView(UIScrollView *view) {
    NSString *name = NSStringFromClass(view.class);
    if ([name containsString:@"Icon"] || [name containsString:@"Home"] || [name containsString:@"Page"]) return YES;
    return NO;
}

static void I26ScheduleIndicatorHide(UIScrollView *view) {
    if (!I26IsSpringBoardHomeScrollView(view)) return;
    NSNumber *generation = @(CACurrentMediaTime() * 1000.0);
    objc_setAssociatedObject(view, kI26LastScrollKey, generation, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([objc_getAssociatedObject(view, kI26LastScrollKey) isEqual:generation]) {
            [view flashScrollIndicators];
            view.showsHorizontalScrollIndicator = NO;
            view.showsVerticalScrollIndicator = NO;
        }
    });
}

%hook UIScrollView
- (void)setContentOffset:(CGPoint)offset {
    if (I26IsSpringBoardHomeScrollView(self)) {
        self.showsHorizontalScrollIndicator = YES;
        self.showsVerticalScrollIndicator = YES;
    }
    %orig(offset);
    I26ScheduleIndicatorHide(self);
}
- (void)didMoveToWindow {
    %orig;
    if (I26IsSpringBoardHomeScrollView(self) && self.window) {
        self.showsHorizontalScrollIndicator = NO;
        self.showsVerticalScrollIndicator = NO;
    }
}
%end
