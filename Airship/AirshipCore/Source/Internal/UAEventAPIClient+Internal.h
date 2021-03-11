/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAAnalytics+Internal.h"
#import "UARequestSession.h"

@class UARuntimeConfig;

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents possible event API client errors.
 */
typedef NS_ENUM(NSInteger, UAEventAPIClientError) {
    /**
     * Indicates an unsuccessful client status.
     */
    UAEventAPIClientErrorUnsuccessfulStatus
};

/**
 * The domain for NSErrors generated by the event API client.
 */
extern NSString * const UAEventAPIClientErrorDomain;

/**
 * API client to upload events to Airship.
 */
@interface UAEventAPIClient : NSObject

///---------------------------------------------------------------------------------------
/// @name Event API Client Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Default factory method.
 *
 * @param config The Airship config.
 * @return A UAEventAPIClient instance.
 */
+ (instancetype)clientWithConfig:(UARuntimeConfig *)config;

/**
 * Factory method to create a UAEventAPIClient.
 *
 * @param config The Airship config.
 * @param session The UARequestSession instance.
 * @return UAEventAPIClient instance.
 */
+ (instancetype)clientWithConfig:(UARuntimeConfig *)config session:(UARequestSession *)session;

/**
 * Uploads analytic events.
 * @param events The events to upload.
 * @param headers The event headers.
 * @param completionHandler A completion handler.
 */
- (UADisposable *)uploadEvents:(NSArray *)events headers:(NSDictionary<NSString *, NSString *> *)headers completionHandler:(void (^)(NSDictionary * _Nullable, NSError * _Nullable))completionHandler;

@end

NS_ASSUME_NONNULL_END
