export TARGET := iphone:clang:latest:16.0
export ARCHS := arm64e
export THEOS_PACKAGE_SCHEME := roothide

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := iOS26UI
iOS26UI_FILES := Source/Tweak.xm
iOS26UI_CFLAGS := -fobjc-arc
iOS26UI_FRAMEWORKS := UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
