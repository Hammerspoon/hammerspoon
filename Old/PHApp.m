
- (NSArray*) visibleWindows {
    return [[self allWindows] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(PHWindow* win, NSDictionary *bindings) {
        return ![[win app] isHidden]
        && ![win isWindowMinimized]
        && [win isNormalWindow];
    }]];
}

- (NSArray*) allWindows {
    NSMutableArray* windows = [NSMutableArray array];

    CFArrayRef _windows;
    AXError result = AXUIElementCopyAttributeValues(self.app, kAXWindowsAttribute, 0, 100, &_windows);
    if (result == kAXErrorSuccess) {
        for (NSInteger i = 0; i < CFArrayGetCount(_windows); i++) {
            AXUIElementRef win = CFArrayGetValueAtIndex(_windows, i);

            PHWindow* window = [[PHWindow alloc] initWithElement:win];
            [windows addObject:window];
        }
        CFRelease(_windows);
    }

    return windows;
}
