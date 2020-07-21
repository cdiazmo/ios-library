/* Copyright Airship and Contributors */

#import "UAAutomationModuleLoader.h"
#import "UAActionAutomation+Internal.h"
#import "UALegacyInAppMessaging+Internal.h"
#import "UAInAppAutomation+Internal.h"

@interface UAAutomationModuleLoader()
@property (nonatomic, copy) NSArray<UAComponent *> *automationComponents;
@end

@implementation UAAutomationModuleLoader

- (instancetype)initWithComponents:(NSArray<UAComponent *> *)components {
    self = [super init];
    if (self) {
        self.automationComponents = components;
    }
    return self;
}

+ (id<UAModuleLoader>)inAppModuleLoaderWithDataStore:(UAPreferenceDataStore *)dataStore
                                              config:(UARuntimeConfig *)config
                                             channel:(UAChannel *)channel
                                           analytics:(UAAnalytics *)analytics
                                  remoteDataProvider:(id<UARemoteDataProvider>)remoteDataProvider
                                    tagGroupHistorian:(UATagGroupHistorian *)tagGroupHistorian {

    NSMutableArray *components = [NSMutableArray array];
    UAActionAutomation *automation = [UAActionAutomation automationWithConfig:config dataStore:dataStore];
    [components addObject:automation];

    UAInAppMessageManager *inAppAutomation = [UAInAppMessageManager managerWithConfig:config
                                                         tagGroupHistorian:tagGroupHistorian
                                                       remoteDataProvider:remoteDataProvider
                                                                dataStore:dataStore
                                                                  channel:channel
                                                                analytics:analytics];
    [components addObject:inAppAutomation];


    UALegacyInAppMessaging *legacyIAM = [UALegacyInAppMessaging inAppMessagingWithAnalytics:analytics
                                                                                  dataStore:dataStore
                                                                            inAppAutomation:inAppAutomation];
    [components addObject:legacyIAM];

    return [[self alloc] initWithComponents:components];
}

- (NSArray<UAComponent *> *)components {
    return self.automationComponents;
}

- (void)registerActions:(UAActionRegistry *)registry {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:@"UAAutomationActions" ofType:@"plist"];
    if (path) {
        [registry registerActionsFromFile:path];
    }
}


@end

