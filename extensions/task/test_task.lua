hs.task = require("hs.task")

taskObject = nil
taskPID = nil
callbackCalled = false
taskExitcode = nil
taskStdout = nil
taskStderr = nil
streamingTaskStdout = ""
streamingTaskStderr = ""
streamingTaskCounter = 0

function testNewTask()
  taskObject = hs.task.new("/bin/pwd", nil)
  assertIsUserdataOfType("hs.task", taskObject)
  assertTrue(#tostring(taskObject) > 0)
  return success()
end

function simpleTaskCallback(exitCode, stdOut, stdErr)
  callbackCalled = true
  taskExitcode = exitCode
  taskStdout = stdOut
  taskStderr = stdErr
  print("simpleTaskCallback exitCode: "..tostring(exitCode))
  print("simpleTaskCallback stdOut: "..stdOut)
  print("simpleTaskCallback stdErr: "..stdErr)
end

function testSimpleTask()
  taskObject = hs.task.new("/usr/bin/true", simpleTaskCallback)
  taskObject:start()
  -- Ensure we can't start this a second time
  assertFalse(taskObject:start())
  return success()
end

function testSimpleTaskValueCheck()
  if callbackCalled then
    assertIsEqual(0, taskExitcode)
    assertIsEqual("exit", taskObject:terminationReason())
    assertTrue(#taskStdout == 0)
    assertFalse(taskObject:isRunning())
    return success()
  else
    return string.format("Waiting for success...(%s != true)", tostring(callbackCalled))
  end
end

function testSimpleTaskFail()
  taskObject = hs.task.new("/usr/bin/false", nil)
  taskObject:setCallback(simpleTaskCallback)
  taskObject:start()
  return success()
end

function testSimpleTaskFailValueCheck()
  if callbackCalled then
    assertIsEqual(1, taskExitcode)
    assertTrue(#taskStdout == 0)
    assertFalse(taskObject:isRunning())
    return success()
  else
    return string.format("Waiting for success...(%s != true)", tostring(callbackCalled))
  end
end

function testStreamingTaskCallback(exitCode, stdOut, stdErr)
  callbackCalled = true
  taskExitcode = exitCode
  taskStdout = stdOut
  taskStderr = stdErr
end

function testStreamingCallback(task, stdOut, stdErr)
  streamingTaskCounter = streamingTaskCounter + 1
  streamingTaskStdout = streamingTaskStdout..stdOut
  streamingTaskStderr = streamingTaskStderr..stdErr
  taskObject:setInput(tostring(streamingTaskCounter))
  if streamingTaskCounter > 5 then
    taskPID = task:pid()
    task:closeInput()
  end
  return true
end

function testStreamingTask()
  taskObject = hs.task.new("/bin/cat", testStreamingTaskCallback, testStreamingCallback)
  taskObject:start()
  taskObject:setInput(tostring(streamingTaskCounter))
  assertTrue(taskObject:isRunning())
  return success()
end

function testStreamingTaskValueCheck()
  if callbackCalled then
    assertIsEqual(0, taskExitcode)
    assertTrue(taskPID > 0)
    assertTrue(#taskStdout == 0)
    assertTrue(string.find(streamingTaskStdout, "12345"))
    assertFalse(taskObject:isRunning())
    return success()
  else
    return string.format("Waiting for success...(%s != true)", tostring(callbackCalled))
  end
end

function testTaskLifecycle()
  taskObject = hs.task.new("/bin/sleep", nil, {"60"})
  taskObject:start()
  assertIsUserdataOfType("hs.task", taskObject:pause())
  assertIsUserdataOfType("hs.task", taskObject:resume())
  taskObject:terminate()
  hs.timer.usleep(500000)
  assertFalse(taskObject:isRunning())
  assertIsEqual(15, taskObject:terminationStatus())
  assertIsEqual("interrupt", taskObject:terminationReason())
  return success()
end

function testTaskEnvironment()
  taskObject = hs.task.new("/bin/sleep", nil, {"60"})
  assertIsTable(taskObject:environment())
  assertIsUserdataOfType("hs.task", taskObject:setEnvironment({SOMEKEY="SOMEVALUE"}))
  taskObject:start()
  assertIsEqual("SOMEVALUE", taskObject:environment()["SOMEKEY"])
  assertFalse(taskObject:setEnvironment({}))
  taskObject:interrupt()
  hs.timer.usleep(500000)
  assertFalse(taskObject:isRunning())
  return success()
end

function testTaskBlock()
  taskObject = hs.task.new("/bin/sleep", nil, {"2"})
  taskObject:start()
  taskObject:waitUntilExit()
  assertFalse(taskObject:isRunning())
  return success()
end

function testTaskWorkingDirectory()
  taskObject = hs.task.new("/bin/sleep", nil, {"60"})
  taskObject:setWorkingDirectory("/tmp")
  assertIsEqual("/tmp", taskObject:workingDirectory())
  taskObject:setStreamingCallback(function() print("unused") end)
  taskObject:start()
  assertIsEqual("/tmp", taskObject:workingDirectory())
  taskObject:terminate()
  return success()
end
