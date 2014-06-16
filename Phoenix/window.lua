print("window!")

-- + (NSArray*) allWindows {
--     NSMutableArray* windows = [NSMutableArray array];
--
--     for (PHApp* app in [PHApp runningApps]) {
--         [windows addObjectsFromArray:[app allWindows]];
--     }
--
--     return windows;
-- }

-- - (CGRect) frame {
--     CGRect r;
--     r.origin = [self topLeft];
--     r.size = [self size];
--     return r;
-- }
--
-- - (void) setFrame:(CGRect)frame {
--     [self setSize: frame.size];
--     [self setTopLeft: frame.origin];
--     [self setSize: frame.size];
-- }





-- + (NSArray*) visibleWindows {
--     return [[self allWindows] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(PHWindow* win, NSDictionary *bindings) {
--         return ![[win app] isHidden]
--         && ![win isWindowMinimized]
--         && [win isNormalWindow];
--     }]];
-- }
--
-- - (NSArray*) otherWindowsOnSameScreen {
--     return [[PHWindow visibleWindows] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(PHWindow* win, NSDictionary *bindings) {
--         return !CFEqual(self.window, win.window) && [[self screen] isEqual: [win screen]];
--     }]];
-- }
--
-- - (NSArray*) otherWindowsOnAllScreens {
--     return [[PHWindow visibleWindows] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(PHWindow* win, NSDictionary *bindings) {
--         return !CFEqual(self.window, win.window);
--     }]];
-- }



-- - (NSScreen*) screen {
--     CGRect windowFrame = [self frame];
--
--     CGFloat lastVolume = 0;
--     NSScreen* lastScreen = nil;
--
--     for (NSScreen* screen in [NSScreen screens]) {
--         CGRect screenFrame = [screen frameIncludingDockAndMenu];
--         CGRect intersection = CGRectIntersection(windowFrame, screenFrame);
--         CGFloat volume = intersection.size.width * intersection.size.height;
--
--         if (volume > lastVolume) {
--             lastVolume = volume;
--             lastScreen = screen;
--         }
--     }
--
--     return lastScreen;
-- }
