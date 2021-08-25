/* Copyright Airship and Contributors */

/**
 * Opens a URL, either in safari or using custom URL schemes. This action is
 * registered under the names ^u and open_external_url_action.
 *
 * Expected argument values: NSString
 *
 * Valid situations: UASituationForegroundPush, UASituationLaunchedFromPush
 * UASituationWebViewInvocation, UASituationForegroundInteractiveButton,
 * UASituationManualInvocation, and UASituationAutomation
 *
 * Result value: An NSString representation of the input
 *
 * Fetch result: UAActionFetchResultNoData
 */
@objc(UAOpenExternalURLAction)
public class OpenExternalURLAction : NSObject, UAAction {
    
    @objc
    public static let name = "open_external_url_action"
    
    @objc
    public static let shortName = "^u"

    public func acceptsArguments(_ arguments: UAActionArguments) -> Bool {
        switch (arguments.situation) {
        case .backgroundPush:
            return false
        case .backgroundInteractiveButton:
            return false
        default:
            guard let url = parseURL(arguments) else {
                return false
            }
            
            guard UAirship.shared().urlAllowList.isAllowed(url, scope: .openURL) else {
                AirshipLogger.error("URL \(url) not allowed. Unable to open URL.")
                return false
            }
            
            return true
        }
    }
    
    public func perform(with arguments: UAActionArguments, completionHandler: @escaping UAActionCompletionHandler) {
        guard let url = parseURL(arguments) else {
            completionHandler(UAActionResult.empty())
            return
        }
        
        UIApplication.shared.open(url, options: [:]) { success in
            if success {
                completionHandler(UAActionResult(value: url.absoluteString))
            } else {
                let error = AirshipErrors.error("Unable to open url \(url).")
                completionHandler(UAActionResult(error: error))
            }
        }
    }

    func parseURL(_ arguments: UAActionArguments) -> URL? {
        if let string = arguments.value as? String {
            return URL(string: string)
        }
        
        return arguments.value as? URL
    }
}