ARCHS = armv7
TARGET = iphone:clang:9.3:8.0
INSTALL_TARGET_PROCESSES = SpringBoard
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = NowPlayingStats
NowPlayingStats_FILES = Tweak.m
NowPlayingStats_CFLAGS = -fobjc-arc
NowPlayingStats_FRAMEWORKS = UIKit CoreGraphics
include $(THEOS_MAKE_PATH)/tweak.mk
