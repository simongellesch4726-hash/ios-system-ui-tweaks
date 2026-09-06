#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>

static void (*orig_SBRecordingIndicatorManager_setIndicatorVisible)(id, SEL, BOOL);
static void (*orig_SBRecordingIndicatorManager_setIndicatorVisibleCamera)(id, SEL, BOOL, BOOL);
static void (*orig_SBRecordingIndicatorManager_updateStatusBar)(id, SEL);
static void (*orig_SBRecordingIndicatorManager_activityDidChange)(id, SEL, id);

static const void *kRPFIndicatorHiddenKey = &kRPFIndicatorHiddenKey;

static BOOL RPFIsRecordingManager(id self) {
    return self && [self isKindOfClass:NSClassFromString(@"SBRecordingIndicatorManager")];
}

static void RPFCallVisibilityUpdate(id self) {
    if (!self) return;
    SEL update = NSSelectorFromString(@"updateRecordingIndicatorForStatusBarChanges");
    if ([self respondsToSelector:update]) {
        ((void (*)(id, SEL))objc_msgSend)(self, update);
    }
}

static void rpf_setIndicatorVisible(id self, SEL _cmd, BOOL visible) {
    if (!RPFIsRecordingManager(self)) {
        orig_SBRecordingIndicatorManager_setIndicatorVisible(self, _cmd, visible);
        return;
    }

    // Preserve SpringBoard's authoritative recording lifecycle. This hook only
    // remembers that a presentation change hid the indicator; it never creates
    // or advances a replacement timer.
    objc_setAssociatedObject(self, kRPFIndicatorHiddenKey, @(!visible), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    orig_SBRecordingIndicatorManager_setIndicatorVisible(self, _cmd, visible);
}

static void rpf_setIndicatorVisibleCamera(id self, SEL _cmd, BOOL visible, BOOL cameraDelay) {
    if (!RPFIsRecordingManager(self)) {
        orig_SBRecordingIndicatorManager_setIndicatorVisibleCamera(self, _cmd, visible, cameraDelay);
        return;
    }

    objc_setAssociatedObject(self, kRPFIndicatorHiddenKey, @(!visible), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    orig_SBRecordingIndicatorManager_setIndicatorVisibleCamera(self, _cmd, visible, cameraDelay);
}

static void rpf_updateStatusBar(id self, SEL _cmd) {
    if (!RPFIsRecordingManager(self)) {
        orig_SBRecordingIndicatorManager_updateStatusBar(self, _cmd);
        return;
    }

    orig_SBRecordingIndicatorManager_updateStatusBar(self, _cmd);

    // If the same recording session is being shown again after a status-bar
    // presentation change, ask the manager to perform its normal location /
    // visibility synchronization. We deliberately do not touch the timer text.
    if ([objc_getAssociatedObject(self, kRPFIndicatorHiddenKey) boolValue]) {
        objc_setAssociatedObject(self, kRPFIndicatorHiddenKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        RPFCallVisibilityUpdate(self);
    }
}

static void rpf_activityDidChange(id self, SEL _cmd, id provider) {
    if (!RPFIsRecordingManager(self)) {
        orig_SBRecordingIndicatorManager_activityDidChange(self, _cmd, provider);
        return;
    }

    orig_SBRecordingIndicatorManager_activityDidChange(self, _cmd, provider);

    // The manager owns the recording state. Re-run only its normal placement
    // path after a sensor/activity transition; no synthetic elapsed clock is used.
    RPFCallVisibilityUpdate(self);
}

%ctor {
    @autoreleasepool {
        Class manager = objc_getClass("SBRecordingIndicatorManager");
        if (!manager) return;

        SEL setVisible = @selector(setIndicatorVisible:);
        if (class_respondsToSelector(manager, setVisible)) {
            MSHookMessageEx(manager, setVisible, (IMP)rpf_setIndicatorVisible,
                            (IMP *)&orig_SBRecordingIndicatorManager_setIndicatorVisible);
        }

        SEL setVisibleCamera = NSSelectorFromString(@"setIndicatorVisible:allowStatusBarDelayForCameraApp:");
        if (class_respondsToSelector(manager, setVisibleCamera)) {
            MSHookMessageEx(manager, setVisibleCamera, (IMP)rpf_setIndicatorVisibleCamera,
                            (IMP *)&orig_SBRecordingIndicatorManager_setIndicatorVisibleCamera);
        }

        SEL updateStatusBar = NSSelectorFromString(@"updateRecordingIndicatorForStatusBarChanges");
        if (class_respondsToSelector(manager, updateStatusBar)) {
            MSHookMessageEx(manager, updateStatusBar, (IMP)rpf_updateStatusBar,
                            (IMP *)&orig_SBRecordingIndicatorManager_updateStatusBar);
        }

        SEL activityChanged = @selector(activityDidChangeForSensorActivityDataProvider:);
        if (class_respondsToSelector(manager, activityChanged)) {
            MSHookMessageEx(manager, activityChanged, (IMP)rpf_activityDidChange,
                            (IMP *)&orig_SBRecordingIndicatorManager_activityDidChange);
        }
    }
}
