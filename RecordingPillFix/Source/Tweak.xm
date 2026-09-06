#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

static CFTimeInterval RPFSessionStart = 0;
static __thread BOOL RPFInternalTextUpdate = NO;

static BOOL RPFParseElapsed(NSString *text, NSInteger *seconds) {
    if (!text) return NO;
    NSArray<NSString *> *parts = [text componentsSeparatedByString:@":"];
    if (parts.count != 2 || parts[0].length == 0 || parts[0].length > 3 || parts[1].length != 2) return NO;

    NSCharacterSet *digits = [NSCharacterSet decimalDigitCharacterSet];
    if ([parts[0] rangeOfCharacterFromSet:[digits invertedSet]].location != NSNotFound ||
        [parts[1] rangeOfCharacterFromSet:[digits invertedSet]].location != NSNotFound) return NO;

    NSInteger minutes = parts[0].integerValue;
    NSInteger remainingSeconds = parts[1].integerValue;
    if (remainingSeconds < 0 || remainingSeconds > 59) return NO;

    if (seconds) *seconds = minutes * 60 + remainingSeconds;
    return YES;
}

static BOOL RPFHasRecordingAppearance(UIView *view) {
    for (UIView *v = view; v; v = v.superview) {
        UIColor *color = v.backgroundColor;
        CGFloat r = 0, g = 0, b = 0, a = 0;
        if (color && [color getRed:&r green:&g blue:&b alpha:&a] &&
            a > 0.5 && r > 0.45 && r > g * 1.5 && r > b * 1.5) {
            return YES;
        }
    }
    return NO;
}

static BOOL RPFIsCandidate(UILabel *label, NSInteger *systemSeconds) {
    if (!label.window || !RPFHasRecordingAppearance(label)) return NO;
    return RPFParseElapsed(label.text, systemSeconds);
}

static void RPFUpdateLabel(UILabel *label) {
    if (RPFInternalTextUpdate) return;

    NSInteger displayed = 0;
    if (!RPFIsCandidate(label, &displayed)) return;

    CFTimeInterval now = CACurrentMediaTime();
    NSInteger expected = RPFSessionStart > 0 ? MAX(0, (NSInteger)floor(now - RPFSessionStart)) : -1;

    if (RPFSessionStart == 0 || displayed + 5 < expected) {
        RPFSessionStart = now - displayed;
        expected = displayed;
    }

    NSString *replacement = [NSString stringWithFormat:@"%ld:%02ld", (long)(expected / 60), (long)(expected % 60)];
    if ([label.text isEqualToString:replacement]) return;

    RPFInternalTextUpdate = YES;
    label.text = replacement;
    RPFInternalTextUpdate = NO;
}

%hook UILabel
- (void)didMoveToWindow {
    %orig;
    if (self.window) RPFUpdateLabel(self);
}

- (void)setText:(NSString *)text {
    %orig(text);
    if (!RPFInternalTextUpdate) RPFUpdateLabel(self);
}
%end
