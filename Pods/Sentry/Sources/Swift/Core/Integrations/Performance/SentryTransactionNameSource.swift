import Foundation

@objc
public enum SentryTransactionNameSource: Int {
    @objc(kSentryTransactionNameSourceCustom)
    case custom = 0
    
    @objc(kSentryTransactionNameSourceUrl)
    case url
    
    @objc(kSentryTransactionNameSourceRoute)
    case route
    
    @objc(kSentryTransactionNameSourceView)
    case view
    
    @objc(kSentryTransactionNameSourceComponent)
    case component
    
    @objc(kSentryTransactionNameSourceTask)
    case sourceTask
}
