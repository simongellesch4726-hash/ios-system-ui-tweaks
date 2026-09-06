#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static CFTimeInterval sessionStart = 0;
static CFTimeInterval lastSeen = 0;

static BOOL RPFIsElapsedTime(NSString *text) {
    if (!text) return NO;
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"^\\d{1,2}:\\d{2}$" options:0 error:nil];
    return [re firstMatchInString:text options:0 range:NSMakeRange(0, text.length)] != nil;
}

static BOOL RPFHasRecordingAppearance(UIView *view) {
    for (UIView *v = view; v; v = v.superview) {
        UIColor *color = v.backgroundColor;
        CGFloat r = 0, g = 0, b = 0, a = 0;
        if (color && [color getRed:&r green:&g blue:&b alpha:&a] && a > 0.5 && r > 0.45 && r > g * 1.5 && r > b * 1.5)
            return YES;
    }
    return NO;
}

static void RPFUpdateLabel(UILabel *label) {
    if (!RPFIsElapsedTime(label.text) || !RPFHasRecordingAppearance(label)) return;

    CFTimeInterval now = CACurrentMediaTime();
    if (sessionStart == 0 || (lastSeen > 0 && now - lastSeen > 15.0)) {
        // The first observed system value seeds the monotonic session clock.
        NSArray<NSString *> *parts = [label.text componentsSeparatedByString:@":"];
        NSInteger seed = parts.count == 2 ? parts[0].integerValue * 60 + parts[1].integerValue : 0;
        sessionStart = now - seed;
    }
    lastSeen = now;

    NSInteger elapsed = MAX(0, (NSInteger)floor(now - sessionStart));
    NSString *expected = [NSString stringWithFormat:@"%ld:%02ld", (long)(elapsed / 60), (long)(elapsed % 60)];
    if (![label.text isEqualToString:expected]) label.text = expected;
}

%hook UILabel
- (void)didMoveToWindow {
    %orig;
    if (self.window) RPFUpdateLabel(self);
}
- (void)setText:(NSString *)text {
    %orig(text);
    RPFUpdateLabel(self);
}
%end

%ctor {
    if (@available(iOS 15.0, *)) {
        // Runtime-scoped to SpringBoard by the filter plist.
    }
}
