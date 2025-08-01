public enum SentryRedactRegionType: String, Codable {
    /// Redacts the region.
    case redact = "redact"

    /// Marks a region to not draw anything.
    /// This is used for opaque views.
    case clipOut = "clip_out"

    /// Push a clip region to the drawing context.
    /// This is used for views that clip to its bounds.
    case clipBegin = "clip_begin"

    /// Pop the last Pushed region from the drawing context.
    /// Used after prossing every child of a view that clip to its bounds.
    case clipEnd = "clip_end"

    /// These regions are redacted first, there is no way to avoid it.
    case redactSwiftUI = "redact_swiftui"
}
