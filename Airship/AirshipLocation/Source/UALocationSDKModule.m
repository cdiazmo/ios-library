/* Copyright Airship and Contributors */

#import "UALocationSDKModule.h"
#import "UALocation+Internal.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif

@interface UALocationSDKModule ()
@property (nonatomic, strong) UALocation *location;
@end

@implementation UALocationSDKModule

- (instancetype)initWithLocation:(UALocation *)location {
    self = [super init];
    if (self) {
        self.location = location;
    }
    return self;
}

- (NSArray<id<UAComponent>> *)components {
    return @[self.location];
}

+ (id<UASDKModule>)loadWithDependencies:(nonnull NSDictionary *)dependencies {
    UAPreferenceDataStore *dataStore = dependencies[UASDKDependencyKeys.dataStore];
    UAChannel *channel = dependencies[UASDKDependencyKeys.channel];
    UAAnalytics *analytics = dependencies[UASDKDependencyKeys.analytics];
    UAPrivacyManager *privacyManager = dependencies[UASDKDependencyKeys.privacyManager];
    
    UALocation *location = [UALocation locationWithDataStore:dataStore
                                                     channel:channel
                                                   analytics:analytics
                                              privacyManager:privacyManager];
    return [[self alloc] initWithLocation:location];

}

@end
