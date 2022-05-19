/* Copyright Airship and Contributors */

#import "UAAPNSRegistration+Internal.h"
#import "UANotificationCategory.h"

@implementation UAAPNSRegistration

-(void)getAuthorizedSettingsWithCompletionHandler:(void (^)(UAAuthorizedNotificationSettings, UAAuthorizationStatus))completionHandler {
    [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull notificationSettings) {

        UAAuthorizationStatus authorizationStatus = [self uaStatus:notificationSettings.authorizationStatus];
        UAAuthorizedNotificationSettings authorizedSettings = UAAuthorizedNotificationSettingsNone;

        if (notificationSettings.badgeSetting == UNNotificationSettingEnabled) {
            authorizedSettings |= UAAuthorizedNotificationSettingsBadge;
        }

#if !TARGET_OS_TV // Only badge settings are available on tvOS
        if (notificationSettings.soundSetting == UNNotificationSettingEnabled) {
            authorizedSettings |= UAAuthorizedNotificationSettingsSound;
        }

        if (notificationSettings.alertSetting == UNNotificationSettingEnabled) {
            authorizedSettings |= UAAuthorizedNotificationSettingsAlert;
        }

        if (notificationSettings.carPlaySetting == UNNotificationSettingEnabled) {
            authorizedSettings |= UAAuthorizedNotificationSettingsCarPlay;
        }

        if (notificationSettings.lockScreenSetting == UNNotificationSettingEnabled) {
            authorizedSettings |= UAAuthorizedNotificationSettingsLockScreen;
        }

        if (notificationSettings.notificationCenterSetting == UNNotificationSettingEnabled) {
            authorizedSettings |= UAAuthorizedNotificationSettingsNotificationCenter;
        }

        if (@available(iOS 12.0, *)) {
            if (notificationSettings.criticalAlertSetting == UNNotificationSettingEnabled) {
                authorizedSettings |= UAAuthorizedNotificationSettingsCriticalAlert;
            }
        }

        if (@available(iOS 13.0, *)) {
            if (notificationSettings.announcementSetting == UNNotificationSettingEnabled) {
                authorizedSettings |= UAAuthorizedNotificationSettingsAnnouncement;
            }
        }
#if !TARGET_OS_MACCATALYST
        if (@available(iOS 15.0, *)) {
            if (notificationSettings.scheduledDeliverySetting == UNNotificationSettingEnabled) {
                authorizedSettings |= UAAuthorizedNotificationSettingsScheduledDelivery;
            }
        }

        if (@available(iOS 15.0, *)) {
            if (notificationSettings.timeSensitiveSetting == UNNotificationSettingEnabled) {
                authorizedSettings |= UAAuthorizedNotificationSettingsTimeSensitive;
            }
        }
#endif
#endif

        completionHandler(authorizedSettings, authorizationStatus);
    }];
}

- (UAAuthorizationStatus)uaStatus:(UNAuthorizationStatus)status {
    if (@available(iOS 12.0, tvOS 12.0, *)) {
        if (status == UNAuthorizationStatusProvisional) {
            return UAAuthorizationStatusProvisional;
        }
    }

    if (status == UNAuthorizationStatusNotDetermined) {
        return UAAuthorizationStatusNotDetermined;
    } else if (status == UNAuthorizationStatusDenied) {
        return UAAuthorizationStatusDenied;
    } else if (status == UNAuthorizationStatusAuthorized) {
        return UAAuthorizationStatusAuthorized;
    }
    #if !TARGET_OS_TV && !TARGET_OS_MACCATALYST
    else if (@available(iOS 14.0, *)) {
        if (status == UNAuthorizationStatusEphemeral) {
            return UAAuthorizationStatusEphemeral;
        }
    }
    #endif
    UA_LWARN(@"Unable to handle UNAuthorizationStatus: %ld", (long)status);
    return UAAuthorizationStatusNotDetermined;
}

- (UNAuthorizationOptions)normalizedOptions:(UANotificationOptions)uaOptions {
    UNAuthorizationOptions unOptions = UNAuthorizationOptionNone;

    if ((uaOptions & UANotificationOptionBadge) == UANotificationOptionBadge) {
        unOptions |= UNAuthorizationOptionBadge;
    }

    if ((uaOptions & UANotificationOptionSound) == UANotificationOptionSound) {
        unOptions |= UNAuthorizationOptionSound;
    }

    if ((uaOptions & UANotificationOptionAlert) == UANotificationOptionAlert) {
        unOptions |= UNAuthorizationOptionAlert;
    }

    if ((uaOptions & UANotificationOptionCarPlay) == UANotificationOptionCarPlay) {
        unOptions |= UNAuthorizationOptionCarPlay;
    }

    // These authorization options and settings are iOS 12+
    if (@available(iOS 12.0, tvOS 12.0, *)) {
        if ((uaOptions & UANotificationOptionCriticalAlert) == UANotificationOptionCriticalAlert) {
            unOptions |= UNAuthorizationOptionCriticalAlert;
        }

        if ((uaOptions & UANotificationOptionProvidesAppNotificationSettings) == UANotificationOptionProvidesAppNotificationSettings) {
            unOptions |= UNAuthorizationOptionProvidesAppNotificationSettings;
        }

        if ((uaOptions & UANotificationOptionProvisional) == UANotificationOptionProvisional) {
            unOptions |= UNAuthorizationOptionProvisional;
        }
    }

    // These authorization options and settings are iOS 13+
#if !TARGET_OS_TV   // UNAuthorizationOptionAnnouncement not supported on tvOS
    if (@available(iOS 13.0, *)) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        if ((uaOptions & UANotificationOptionAnnouncement) == UANotificationOptionAnnouncement) {
            unOptions |= UNAuthorizationOptionAnnouncement;
        }
    }
#pragma clang diagnostic pop
#endif

    return unOptions;
}

-(void)updateRegistrationWithOptions:(UANotificationOptions)options
                          categories:(NSSet<UANotificationCategory *> *)categories
                   completionHandler:(nullable void(^)(BOOL success,
                                                       UAAuthorizedNotificationSettings authorizedSettings,
                                                       UAAuthorizationStatus status))completionHandler {

#if !TARGET_OS_TV   // UNNotificationCategory not supported on tvOS
    NSMutableSet *normalizedCategories;

    if (categories) {
        normalizedCategories = [NSMutableSet set];

        // Normalize our abstract categories to iOS-appropriate type
        for (UANotificationCategory *category in categories) {
            [normalizedCategories addObject:[category asUNNotificationCategory]];
        }
    }

    [[UNUserNotificationCenter currentNotificationCenter] setNotificationCategories:[NSSet setWithSet:normalizedCategories]];
#endif

    UNAuthorizationOptions normalizedOptions = [self normalizedOptions:options];

    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];

    [center requestAuthorizationWithOptions:normalizedOptions
                          completionHandler:^(BOOL granted, NSError * _Nullable error) {
        if (error) {
            UA_LERR(@"requestAuthorizationWithOptions failed with error: %@", error);
        }

        [self getAuthorizedSettingsWithCompletionHandler:^(UAAuthorizedNotificationSettings authorizedSettings, UAAuthorizationStatus status) {
            if (completionHandler) {
                completionHandler(granted, authorizedSettings, status);
            }
        }];
    }];
}

@end