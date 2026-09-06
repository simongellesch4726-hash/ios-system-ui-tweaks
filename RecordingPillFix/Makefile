export TARGET := iphone:clang:latest:15.0
export ARCHS := arm64
export THEOS_PACKAGE_SCHEME := roothide

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := RecordingPillFix
RecordingPillFix_FILES := Source/Tweak.xm
RecordingPillFix_CFLAGS := -fobjc-arc
RecordingPillFix_FRAMEWORKS := UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
