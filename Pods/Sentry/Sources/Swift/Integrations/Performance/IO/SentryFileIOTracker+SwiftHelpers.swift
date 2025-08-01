@_implementationOnly import _SentryPrivate
import Foundation

extension SentryFileIOTracker {
    func measureReadingData(
        from url: URL,
        options: Data.ReadingOptions,
        origin: String,
        method: (_ url: URL, _ options: Data.ReadingOptions) throws -> Data
    ) rethrows -> Data {
        // We dont track reads from a url that is not a file url
        // because these reads are handled by NSURLSession and
        // SentryNetworkTracker will create spans in these cases.
        guard url.scheme == NSURLFileScheme else {
            return try method(url, options)
        }
        guard let span = self.span(forPath: url.path, origin: origin, operation: SentrySpanOperationFileRead) else {
            return try method(url, options)
        }
        do {
            let data = try method(url, options)
            span.setData(value: data.count, key: SentrySpanDataKeyFileSize)
            span.finish()
            return data
        } catch {
            span.finish(status: .internalError)
            throw error
        }
    }

    func measureWritingData(
        _ data: Data,
        to url: URL,
        options: Data.WritingOptions,
        origin: String,
        method: (_ data: Data, _ url: URL, _ options: Data.WritingOptions) throws -> Void
    ) rethrows {
        // We dont track reads from a url that is not a file url
        // because these reads are handled by NSURLSession and
        // SentryNetworkTracker will create spans in these cases.
        guard url.scheme == NSURLFileScheme else {
            return try method(data, url, options)
        }
        guard let span = self.span(forPath: url.path, origin: origin, operation: SentrySpanOperationFileWrite, size: UInt(data.count)) else {
            return try method(data, url, options)
        }
        do {
            try method(data, url, options)
            span.finish()
        } catch {
            span.finish(status: .internalError)
            throw error
        }
    }

    func measureRemovingItem(
        at url: URL,
        origin: String,
        method: (_ url: URL) throws -> Void
    ) rethrows {
        // We dont track reads from a url that is not a file url
        // because these reads are handled by NSURLSession and
        // SentryNetworkTracker will create spans in these cases.
        guard url.scheme == NSURLFileScheme else {
            return try method(url)
        }
        guard let span = self.span(forPath: url.path, origin: origin, operation: SentrySpanOperationFileDelete) else {
            return try method(url)
        }
        do {
            try method(url)
            span.finish()
        } catch {
            span.finish(status: .internalError)
            throw error
        }
    }
    
    func measureRemovingItem(
        atPath path: String,
        origin: String,
        method: (_ path: String) throws -> Void
    ) rethrows {
        guard let span = self.span(forPath: path, origin: origin, operation: SentrySpanOperationFileDelete) else {
            return try method(path)
        }
        do {
            try method(path)
            span.finish()
        } catch {
            span.finish(status: .internalError)
            throw error
        }
    }

    func measureCreatingFile(
        atPath path: String,
        contents data: Data?,
        attributes attr: [FileAttributeKey: Any]?,
        origin: String,
        method: (_ path: String, _ data: Data?, _ attributes: [FileAttributeKey: Any]?) -> Bool
    ) -> Bool {
        let size = UInt(data?.count ?? 0)
        guard let span = self.span(forPath: path, origin: origin, operation: SentrySpanOperationFileWrite, size: size) else {
            return method(path, data, attr)
        }
        if let data = data {
            span.setData(value: data.count, key: SentrySpanDataKeyFileSize)
        }
        defer {
            span.finish()
        }
        return method(path, data, attr)
}

    func measureCopyingItem(
        at srcUrl: URL,
        to dstUrl: URL,
        origin: String,
        method: (_ srcUrl: URL, _ dstUrl: URL) throws -> Void
    ) rethrows {
        // We dont track reads from a url that is not a file url
        // because these reads are handled by NSURLSession and
        // SentryNetworkTracker will create spans in these cases.
        guard srcUrl.scheme == NSURLFileScheme && dstUrl.scheme == NSURLFileScheme else {
            return try method(srcUrl, dstUrl)
        }
        guard let span = self.span(forPath: srcUrl.path, origin: origin, operation: SentrySpanOperationFileCopy) else {
            return try method(srcUrl, dstUrl)
        }
        do {
            try method(srcUrl, dstUrl)
            span.finish()
        } catch {
            span.finish(status: .internalError)
            throw error
        }
    }
    
    func measureCopyingItem(
        atPath srcPath: String,
        toPath dstPath: String,
        origin: String,
        method: (_ srcPath: String, _ dstPath: String) throws -> Void
    ) rethrows {
        guard let span = self.span(forPath: srcPath, origin: origin, operation: SentrySpanOperationFileCopy) else {
            return try method(srcPath, dstPath)
        }
        do {
            try method(srcPath, dstPath)
            span.finish()
        } catch {
            span.finish(status: .internalError)
            throw error
        }
    }

    func measureMovingItem(
        at srcUrl: URL,
        to dstUrl: URL,
        origin: String,
        method: (_ srcUrl: URL, _ dstUrl: URL) throws -> Void
    ) rethrows {
        // We dont track reads from a url that is not a file url
        // because these reads are handled by NSURLSession and
        // SentryNetworkTracker will create spans in these cases.
        guard srcUrl.scheme == NSURLFileScheme && dstUrl.scheme == NSURLFileScheme else {
            return try method(srcUrl, dstUrl)
        }
        guard let span = self.span(forPath: srcUrl.path, origin: origin, operation: SentrySpanOperationFileRename) else {
            return try method(srcUrl, dstUrl)
        }
        do {
            try method(srcUrl, dstUrl)
            span.finish()
        } catch {
            span.finish(status: .internalError)
            throw error
        }
    }

    func measureMovingItem(
        atPath srcPath: String,
        toPath dstPath: String,
        origin: String,
        method: (_ srcPath: String, _ dstPath: String) throws -> Void
    ) rethrows {
        guard let span = self.span(forPath: srcPath, origin: origin, operation: SentrySpanOperationFileRename) else {
            return try method(srcPath, dstPath)
        }
        do {
            try method(srcPath, dstPath)
            span.finish()
        } catch {
            span.finish(status: .internalError)
            throw error
        }
    }
}
