export THEOS := /Users/tune/Develop/theos-roothide
export THEOS_PACKAGE_SCHEME := roothide
TARGET := iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = WatusiZhHans
WatusiZhHans_FILES = Tweak.xm
WatusiZhHans_CFLAGS = -fobjc-arc
WatusiZhHans_FRAMEWORKS = Foundation UIKit
INSTALL_TARGET_PROCESSES = WhatsApp

before-stage::
	python3 scripts/generate_localizations.py

include $(THEOS_MAKE_PATH)/tweak.mk
