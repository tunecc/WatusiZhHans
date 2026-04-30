export THEOS := /Users/tune/Develop/theos-roothide
export THEOS_PACKAGE_SCHEME := roothide
TARGET := iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

NULL_NAME = WatusiZhHans

before-stage::
	python3 scripts/generate_localizations.py

include $(THEOS_MAKE_PATH)/null.mk

all::

stage::
