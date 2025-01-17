/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"

#import "UALegacyInAppMessage.h"
#import "AirshipTests-Swift.h"

@import AirshipCore;

@interface UALegacyInAppMessageTest : UAAirshipBaseTest
@property(nonatomic, copy) NSDictionary *payload;
@end

@implementation UALegacyInAppMessageTest

- (void)setUp {
    [super setUp];

    id expiry = @"2020-12-15T11:45:22";
    id extra = @{@"foo":@"bar", @"baz":@12345};

    id display = @{@"alert":@"hi!", @"type":@"banner", @"duration":@20, @"position":@"top", @"primary_color":@"#ffffffff", @"secondary_color":@"#ff00ff00"};

    id actions = @{@"on_click":@{@"^d":@"http://google.com"}, @"button_group":@"ua_yes_no_foreground", @"button_actions":@{@"yes":@{@"^+t": @"yes_tag"}, @"no":@{@"^+t": @"no_tag"}}};

    self.payload = @{@"identifier":@"some identifier", @"expiry":expiry, @"extra":extra, @"display":display, @"actions":actions};
}

/**
 * Helper method for verifying model/payload equivalence 
 */
- (void)verifyPayloadConsistency:(UALegacyInAppMessage *)message {

    NSCalendar *gregorian = [[NSCalendar alloc]
                             initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    gregorian.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];

    NSDateComponents *expiryComponents =
    [gregorian components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond) fromDate:message.expiry];

    XCTAssertEqualObjects(message.identifier, @"some identifier");

    XCTAssertEqual(expiryComponents.year, 2020);
    XCTAssertEqual(expiryComponents.month, 12);
    XCTAssertEqual(expiryComponents.day, 15);
    XCTAssertEqual(expiryComponents.hour, 11);
    XCTAssertEqual(expiryComponents.minute, 45);
    XCTAssertEqual(expiryComponents.second, 22);

    XCTAssertEqualObjects(message.extra[@"foo"], self.payload[@"extra"][@"foo"]);
    XCTAssertEqualObjects(message.extra[@"baz"], self.payload[@"extra"][@"baz"]);

    XCTAssertEqualObjects(message.alert, self.payload[@"display"][@"alert"]);
    XCTAssertEqual(message.duration, [self.payload[@"display"][@"duration"] doubleValue]);
    XCTAssertEqual(message.position, UALegacyInAppMessagePositionTop);
    XCTAssertEqual(message.displayType, UALegacyInAppMessageDisplayTypeBanner);

    XCTAssertEqualObjects(message.buttonGroup, self.payload[@"actions"][@"button_group"]);
    XCTAssertEqualObjects(message.onClick, self.payload[@"actions"][@"on_click"]);
    XCTAssertEqualObjects(message.buttonActions, self.payload[@"actions"][@"button_actions"]);

    XCTAssertEqualObjects(message.primaryColor, [UIColor colorWithRed:1 green:1 blue:1 alpha:1]);
    XCTAssertEqualObjects(message.secondaryColor, [UIColor greenColor]);

    XCTAssertEqualObjects(message.payload, self.payload);
}

- (void)testDefaults {
    UALegacyInAppMessage *message = [UALegacyInAppMessage message];
    XCTAssertEqual(message.displayType, UALegacyInAppMessageDisplayTypeBanner);
    XCTAssertEqual(message.position, UALegacyInAppMessagePositionBottom);

    NSDate *expiry = message.expiry;
    NSDate *expectedExpiry = [NSDate dateWithTimeIntervalSinceNow:60 * 60 * 24 * 30];
    XCTAssertEqualWithAccuracy(expiry.timeIntervalSince1970, expectedExpiry.timeIntervalSince1970, 1);
}

/**
 * Test that payloads get turned into model objects properly
 */
- (void)testMessageWithPayload {
    UALegacyInAppMessage *iam = [UALegacyInAppMessage messageWithPayload:self.payload];
    [self verifyPayloadConsistency:iam];
}


/**
 * Test that messages can be compared for equality by value
 */
- (void)testIsEqualToMessage {
    UALegacyInAppMessage *iam = [UALegacyInAppMessage messageWithPayload:self.payload];
    UALegacyInAppMessage *iam2 = [UALegacyInAppMessage messageWithPayload:self.payload];
    XCTAssertTrue([iam isEqualToMessage:iam2]);

    iam.alert = @"sike!";

    XCTAssertFalse([iam isEqualToMessage:iam2]);
}

- (void)testUnexpectedDisplayAndPosition {
    NSMutableDictionary *weirdPayload = [NSMutableDictionary dictionaryWithDictionary:self.payload];
    NSDictionary *weirdDisplay = @{@"alert":@"yo!", @"type":@"not a type", @"position":@"sideways, starring paul giamatti"};

    weirdPayload[@"display"] = weirdDisplay;
    UALegacyInAppMessage *iam = [UALegacyInAppMessage messageWithPayload:weirdPayload];

    // invalid payload results in nil message
    XCTAssertNil(iam);
}

/**
 * Test that the payload parser drops values that don't conform to the expected type
 */
- (void)testSoftTypeChecking {
    NSMutableDictionary *weirdPayload = [NSMutableDictionary dictionaryWithDictionary:self.payload];
    NSDictionary *weirdDisplay = @{@"alert":@{@"not_a" : @"string"}, @"type":@"banner", @"duration":@"not a number", @"position":@[@1, @2, @3]};

    weirdPayload[@"display"] = weirdDisplay;

    UALegacyInAppMessage *iam = [UALegacyInAppMessage messageWithPayload:weirdPayload];

    // alert has no default, so it should be nil in this case
    XCTAssertNil(iam.alert);

    // set to banner
    XCTAssertEqual(iam.displayType, UALegacyInAppMessageDisplayTypeBanner);

    // default to bottom
    XCTAssertEqual(iam.position, UALegacyInAppMessagePositionBottom);

    // default to 15 seconds
    XCTAssertEqual(iam.duration, 15);
}

@end
