function testStartStop()
  local listener = hs.noises.new(function(evNum)
    print("this can never run, because there's nobody saying tsss during tests, and it is only listening for an instant")
  end)

  listener:start()
  listener:stop()

  -- should be able to start and stop multiple times without crashing
  listener:start()
  listener:stop()

  -- being garbage collected while running should not crash
  -- who knows, leaving this running until GC might allow us
  -- to test recieving some audio frames
  listener:start()

  return success()
end
