enum SentryInfoPlistKey: String {
    /// Key used to set the Xcode version used to build app
    case xcodeVersion = "DTXcode"

    /// A Boolean value that indicates whether the system runs the app using a compatibility mode for UI.
    ///
    /// If `YES`, the system runs the app using a compatibility mode for UI elements. The compatibility mode displays the app as it looks when built against previous versions of the SDKs.
    ///
    /// If `NO`, the system uses the UI design of the running OS, with no compatibility mode. Absence of the key, or NO, is the default value for apps linking against the latest SDKs.
    ///
    /// - Warning: This key is used temporarily while reviewing and refining an app’s UI for the design in the latest SDKs (i.e. Liquid Glass).
    ///
    /// - SeeAlso: [Apple Documentation](https://developer.apple.com/documentation/BundleResources/Information-Property-List/UIDesignRequiresCompatibility)
    case designRequiresCompatibility = "UIDesignRequiresCompatibility"
}
