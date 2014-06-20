function hydra.window.allwindows()
  return hydra.fn.mapcat(hydra.app.runningapps(), hydra.app.windows)
end

function hydra.window:isvisible()
  return not self:app():ishidden() and
    not self:isminimized() and
    self:isstandard()
end

function hydra.window:frame()
  local s = self:size()
  local tl = self:topleft()
  return {x = tl.x, y = tl.y, w = s.w, h = s.h}
end

function hydra.window:setframe(f)
  self:setsize(f)
  self:settopleft(f)
  self:setsize(f)
end

function hydra.window:otherwindows_samescreen()
  return hydra.fn.filter(hydra.window.visiblewindows, function(win) return self ~= win and self:screen() == win:screen() end)
end

function hydra.window:otherwindows_allscreens()
  return hydra.fn.filter(hydra.window.visiblewindows, function(win) return self ~= win end)
end

function hydra.window:focus()
  return self:becomemain() and self:app():activate()
end

function hydra.window.visiblewindows()
  return hydra.fn.filter(window:allwindows(), hydra.window.isvisible)
end

function hydra.window:maximize()
  local screenrect = self:screen():frame_without_dock_or_menu()
  self:setframe(screenrect)
end

function hydra.window:screen()
  local windowframe = self:frame()
  local lastvolume = 0
  local lastscreen = nil

  for _, screen in pairs(hydra.screen.all()) do
    local screenframe = screen:frame_including_dock_and_menu()
    local intersection = hydra.geometry.rectintersection(windowframe, screenframe)
    local volume = intersection.w * intersection.h

    if volume > lastvolume then
      lastvolume = volume
      lastscreen = screen
    end
  end

  return lastscreen
end













-- assumes looking to east
local function windows_in_direction(win, numrotations)
  -- TODO
end

-- - (NSArray*) windowsInDirectionFn:(double(^)(double angle))whichDirectionFn
--                 shouldDisregardFn:(BOOL(^)(double deltaX, double deltaY))shouldDisregardFn
-- {
--     PHWindow* thisWindow = [PHWindow focusedWindow];
--     NSPoint startingPoint = SDMidpoint([thisWindow frame]);
--
--     NSArray* otherWindows = [thisWindow otherWindowsOnAllScreens];
--     NSMutableArray* closestOtherWindows = [NSMutableArray arrayWithCapacity:[otherWindows count]];
--
--     for (PHWindow* win in otherWindows) {
--         NSPoint otherPoint = SDMidpoint([win frame]);
--
--         double deltaX = otherPoint.x - startingPoint.x;
--         double deltaY = otherPoint.y - startingPoint.y;
--
--         if (shouldDisregardFn(deltaX, deltaY))
--             continue;
--
--         double angle = atan2(deltaY, deltaX);
--         double distance = hypot(deltaX, deltaY);
--
--         double angleDifference = whichDirectionFn(angle);
--
--         double score = distance / cos(angleDifference / 2.0);
--
--         [closestOtherWindows addObject:@{
--                                          @"score": @(score),
--                                          @"win": win,
--                                          }];
--     }
--
--     NSArray* sortedOtherWindows = [closestOtherWindows sortedArrayUsingComparator:^NSComparisonResult(NSDictionary* pair1, NSDictionary* pair2) {
--         return [[pair1 objectForKey:@"score"] compare: [pair2 objectForKey:@"score"]];
--     }];
--
--     return sortedOtherWindows;
-- }


local function focus_first_valid_window(ordered_wins)
  for _, win in pairs(ordered_wins) do
    if win:focus() then break end
  end
end

function hydra.window:windows_to_east()
  return windows_in_direction(self, 0)
end

function hydra.window:windows_to_west()
  return windows_in_direction(self, 2)
end

function hydra.window:windows_to_north()
  return windows_in_direction(self, 3)
end

function hydra.window:windows_to_south()
  return windows_in_direction(self, 1)
end

function hydra.window:focus_window_to_east()
  return self:focus_first_valid_window(self:windows_to_east())
end

function hydra.window:focus_window_to_west()
  return self:focus_first_valid_window(self:windows_to_west())
end

function hydra.window:focus_window_to_north()
  return self:focus_first_valid_window(self:windows_to_north())
end

function hydra.window:focus_window_to_south()
  return self:focus_first_valid_window(self:windows_to_south())
end
