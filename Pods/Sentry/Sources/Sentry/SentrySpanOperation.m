#import <Foundation/Foundation.h>

NSString *const SentrySpanOperationAppLifecycle = @"app.lifecycle";

NSString *const SentrySpanOperationCoredataFetchOperation = @"db.sql.query";
NSString *const SentrySpanOperationCoredataSaveOperation = @"db.sql.transaction";

NSString *const SentrySpanOperationFileRead = @"file.read";
NSString *const SentrySpanOperationFileWrite = @"file.write";
NSString *const SentrySpanOperationFileCopy = @"file.copy";
NSString *const SentrySpanOperationFileRename = @"file.rename";
NSString *const SentrySpanOperationFileDelete = @"file.delete";

NSString *const SentrySpanOperationNetworkRequestOperation = @"http.client";

NSString *const SentrySpanOperationUiAction = @"ui.action";
NSString *const SentrySpanOperationUiActionClick = @"ui.action.click";
NSString *const SentrySpanOperationUiLoad = @"ui.load";
NSString *const SentrySpanOperationUiLoadInitialDisplay = @"ui.load.initial_display";
NSString *const SentrySpanOperationUiLoadFullDisplay = @"ui.load.full_display";
