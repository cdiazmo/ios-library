/* Copyright Airship and Contributors */

/**
 * A UAAccountEventTemplate represents a custom account event template for the
 * application.
 */
@objc
public class UAAccountEventTemplate : NSObject {

    private let eventName: String

    /**
     * The event's value. The value must be between -2^31 and
     * 2^31 - 1 or it will invalidate the event.
     */
    @objc
    public var eventValue: NSNumber?

    /**
     * The event's transaction ID. The transaction ID's length must not exceed 255
     * characters or it will invalidate the event.
     */
    @objc
    public var  transactionID : String?

    /**
     * The event's identifier.
     */
    @objc
    public var userID: String?


    /**
     * The event's category.
     */
    @objc
    public var category: String?

    /**
     * The event's type.
     */
    @objc
    public var type: String?

    private init(eventName: String, value: NSNumber? = nil) {
        self.eventName = eventName
        self.eventValue = value
        super.init()
    }

    /**
     * Factory method for creating a registered account event template.
     * @returns An Account event template instance
     */
    @objc
    public class func registeredTemplate() -> UAAccountEventTemplate {
        return registeredTemplate(value: nil)
    }

    /**
     * Factory method for creating a registered account event template with a value from a string.
     *
     * @param valueString The value of the event as a string. The value must be a valid
     * number between -2^31 and 2^31 - 1 or it will invalidate the event.
     * @returns An Account event template instance
     */
    @objc(registeredTemplateWithValueFromString:)
    public class func registeredTemplate(valueString: String?) -> UAAccountEventTemplate {
        let decimalValue = valueString != nil ? NSDecimalNumber(string: valueString) : nil
        return registeredTemplate(value: decimalValue)
    }

    /**
     * Factory method for creating a registered account event template with a value.
     *
     * @param value The value of the event. The value must be between -2^31 and
     * 2^31 - 1 or it will invalidate the event.
     * @returns An Account event template instance
     */
    @objc(registeredTemplateWithValue:)
    public class func registeredTemplate(value: NSNumber?) -> UAAccountEventTemplate {
        return UAAccountEventTemplate(eventName: "registered_account", value: value)
    }

    /**
     * Factory method for creating a logged in account event template.
     * @returns An Account event template instance
     */
    @objc
    public class func loggedInTemplate() -> UAAccountEventTemplate {
        return loggedInTemplate(value: nil)
    }

    /**
     * Factory method for creating a logged in account event template with a value from a string.
     *
     * @param valueString The value of the event as a string. The value must be a valid
     * number between -2^31 and 2^31 - 1 or it will invalidate the event.
     * @returns An Account event template instance
     */
    @objc(loggedInTemplateWithValueFromString:)
    public class func loggedInTemplate(valueString: String?) -> UAAccountEventTemplate {
        let decimalValue = valueString != nil ? NSDecimalNumber(string: valueString) : nil
        return loggedInTemplate(value: decimalValue)
    }

    /**
     * Factory method for creating a logged in account event template with a value.
     *
     * @param value The value of the event. The value must be between -2^31 and
     * 2^31 - 1 or it will invalidate the event.
     * @returns An Account event template instance
     */
    @objc(loggedInTemplateWithValue:)
    public class func loggedInTemplate(value: NSNumber?) -> UAAccountEventTemplate {
        return UAAccountEventTemplate(eventName: "logged_in", value: value)
    }


    /**
     * Factory method for creating a logged out account event template.
     * @returns An Account event template instance
     */
    @objc
    public class func loggedOutTemplate() -> UAAccountEventTemplate {
        return loggedOutTemplate(value: nil)
    }

    /**
     * Factory method for creating a logged out account event template with a value from a string.
     *
     * @param valueString The value of the event as a string. The value must be a valid
     * number between -2^31 and 2^31 - 1 or it will invalidate the event.
     * @returns An Account event template instance
     */
    @objc(loggedOutTemplateWithValueFromString:)
    public class func loggedOutTemplate(valueString: String?) -> UAAccountEventTemplate {
        let decimalValue = valueString != nil ? NSDecimalNumber(string: valueString) : nil
        return loggedOutTemplate(value: decimalValue)
    }

    /**
     * Factory method for creating a logged out account event template with a value.
     *
     * @param value The value of the event. The value must be between -2^31 and
     * 2^31 - 1 or it will invalidate the event.
     * @returns An Account event template instance
     */
    @objc(loggedOutTemplateWithValue:)
    public class func loggedOutTemplate(value: NSNumber?) -> UAAccountEventTemplate {
        return UAAccountEventTemplate(eventName: "logged_out", value: value)
    }

    /**
     * Creates the custom account event.
     */
    @objc
    public func createEvent() -> UACustomEvent? {
        var propertyDictionary: [AnyHashable : Any] = [:]
        propertyDictionary["ltv"] = self.eventValue != nil
        propertyDictionary["user_id"] = self.userID
        propertyDictionary["category"] = self.category
        propertyDictionary["type"] = self.type

        let event = UACustomEvent(name: self.eventName)
        event.templateType = "account"
        event.eventValue = self.eventValue
        event.transactionID = self.transactionID
        event.properties = propertyDictionary
        return event
    }
}
