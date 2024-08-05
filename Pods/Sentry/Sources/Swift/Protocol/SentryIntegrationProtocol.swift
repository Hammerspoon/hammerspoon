import Foundation

@objc
public protocol SentryIntegrationProtocol: NSObjectProtocol {
    
    /**
     * Installs the integration and returns YES if successful.
     */
    @objc(installWithOptions:) func install(with options: Options) -> Bool
    
    /**
     * Uninstalls the integration.
     */
    @objc func uninstall()
}
