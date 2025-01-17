/* Copyright Airship and Contributors */

#import "UAAccengageSDKModule.h"
#import "UAAccengage+Internal.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif
@interface UAAccengageSDKModule()
@property (nonatomic, strong) UAAccengage *accengage;
@end

@implementation UAAccengageSDKModule

- (instancetype)initWithAccengage:(UAAccengage *)accengage{
    self = [super init];
    if (self) {
        self.accengage = accengage;
    }
    return self;
}

- (NSArray<id<UAComponent>> *)components {
    return @[self.accengage];
}

+ (id<UASDKModule>)loadWithDependencies:(nonnull NSDictionary *)dependencies {
    UAPreferenceDataStore *dataStore = dependencies[UASDKDependencyKeys.dataStore];
    UAChannel *channel = dependencies[UASDKDependencyKeys.channel];
    UAPush *push = dependencies[UASDKDependencyKeys.push];
    UAPrivacyManager *privacyManager = dependencies[UASDKDependencyKeys.privacyManager];
    UAAccengage *accengage = [UAAccengage accengageWithDataStore:dataStore
                                                         channel:channel
                                                            push:push
                                                  privacyManager:privacyManager];

    return [[self alloc] initWithAccengage:accengage];
}


@end
