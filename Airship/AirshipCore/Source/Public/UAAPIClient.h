/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UARuntimeConfig.h"
#import "UARequest.h"
#import "UARequestSession.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents possible API client errors.
 */
typedef NS_ENUM(NSInteger, UAAPIClientError) {
   /**
    * Indicates an invalid URL response
    */
   UAAPIClientErrorInvalidURLResponse
};

/**
* The domain for NSErrors generated by UAAPIClient.
*/
extern NSString * const UAAPIClientErrorDomain;

/**
 * @note For internal use only. :nodoc:
 */
@interface UAAPIClient : NSObject

/**
 * Status code to indicate the API client is disabled or otherwise unavailable
 * @note For internal use only. :nodoc:
 */
extern NSUInteger const UAAPIClientStatusUnavailable;

/**
 * The UARuntimeConfig instance.
 */
@property (nonatomic, readonly) UARuntimeConfig *config;

/**
 * The UARequestSession instance. Should be used to perform requests.
 */
@property (nonatomic, readonly) UARequestSession *session;

/**
 * Flag indicating whether the client is enabled. Clear to disable. Set to enable.
 */
@property (nonatomic, assign) BOOL enabled;

/**
 * Init method.
 * @param config The UARuntimeConfig instance.
 * @param session The UARequestSession instance.
 */
- (instancetype)initWithConfig:(UARuntimeConfig *)config session:(UARequestSession *)session;

/**
 * Cancels all in-flight API requests.
 */
- (void)cancelAllRequests;

/**
 * Utility method to cast an NSURLResponse to an NSHTTPURLResponse.
 *
 * @param response The NSURLResponse.
 * @param error A pointer to an error instance. If non-nil, the original error will be unmodified, otherwise it will be populated if the cast fails.
 * @return The response cast as an NSHTTPURLResponse, or nil if the cast fails.
 */
- (nullable NSHTTPURLResponse *)castResponse:(NSURLResponse *)response error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END