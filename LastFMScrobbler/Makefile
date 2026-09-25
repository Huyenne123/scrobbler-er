ARCHS = arm64
TARGET = iphone:clang:16.5
FINALPACKAGE = 1
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LastFMScrobbler
LastFMScrobbler_FILES = src/main.m src/LFMScrobbler.m src/MediaRemoteManager.m src/LastFMClient.m src/CredentialStore.m src/ScrobbleQueue.m src/MetadataNormalizer.m src/LFMTrack.m
LastFMScrobbler_FRAMEWORKS = UIKit Foundation
LastFMScrobbler_PRIVATE_FRAMEWORKS = MediaRemote
LastFMScrobbler_LDFLAGS = -lz

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += LastFMScrobblerPrefs
include $(THEOS_MAKE_PATH)/aggregate.mk
