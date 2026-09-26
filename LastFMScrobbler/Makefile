ARCHS = arm64
TARGET = iphone:clang:16.5
FINALPACKAGE = 1
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TOOL_NAME = lastfmscrobblerd
lastfmscrobblerd_FILES = src/main.m src/LFMScrobbler.m src/MediaRemoteManager.m src/LastFMClient.m src/CredentialStore.m src/ScrobbleQueue.m src/MetadataNormalizer.m src/LFMTrack.m
lastfmscrobblerd_FRAMEWORKS = UIKit Foundation
lastfmscrobblerd_PRIVATE_FRAMEWORKS = MediaRemote
lastfmscrobblerd_LDFLAGS = -lz
lastfmscrobblerd_CFLAGS = -fobjc-arc -Wno-deprecated-declarations

include $(THEOS_MAKE_PATH)/tool.mk

SUBPROJECTS += LastFMScrobblerPrefs
include $(THEOS_MAKE_PATH)/aggregate.mk