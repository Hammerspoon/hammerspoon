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
