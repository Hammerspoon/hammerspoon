SocketRocket Objective-C WebSocket Client (beta)
================================================
A conforming WebSocket (`RFC 6455 <http://tools.ietf.org/html/rfc6455>`_)
client library.

`Test results for SocketRocket here <http://square.github.io/SocketRocket/results/>`_.
You can compare to what `modern browsers look like here
<http://tavendo.com/autobahn/testsuite/report/clients/index.html>`_.

SocketRocket currently conforms to all ~300 of `Autobahn
<http://autobahn.ws/testsuite/>`_'s fuzzing tests (aside from
two UTF-8 ones where it is merely *non-strict*. tests 6.4.2 and 6.4.4)

Features/Design
---------------
- TLS (wss) support.  It uses CFStream so we get this for *free*
- Uses NSStream/CFNetworking.  Earlier implementations used ``dispatch_io``,
  however, this proved to be make TLS nearly impossible.  Also I wanted this to
  work in iOS 4.x. (SocketRocket only supports 5.0 and above now)
- Uses ARC.  It uses the 4.0 compatible subset (no weak refs).
- Seems to perform quite well
- Parallel architecture. Most of the work is done in background worker queues.
- Delegate-based. Had older versions that could use blocks too, but I felt it
  didn't blend well with retain cycles and just objective C in general.

Changes
-------

v0.3.1-beta2 - 2013-01-12
`````````````````````````

- Stability fix for ``closeWithCode:reason:`` (Thanks @michaelpetrov!)
- Actually clean up the NSStreams and remove them from their runloops
- ``_SRRunLoopThread``'s ``main`` wasn't correctly wrapped with
  ``@autoreleasepool``

v0.3.1-beta1 - 2013-01-12
`````````````````````````

- Cleaned up GCD so OS_OBJECT_USE_OBJC_RETAIN_RELEASE is optional
- Removed deprecated ``dispatch_get_current_queue`` in favor of ``dispatch_queue_set_specific`` and ``dispatch_get_specific``
- Dropping support for iOS 4.0 (it may still work)


Installing (iOS)
----------------
There's a few options. Choose one, or just figure it out

- You can copy all the files in the SocketRocket group into your app.
- Include SocketRocket as a subproject and use libSocketRocket

  If you do this, you must add -ObjC to your "other linker flags" option

- For OS X you will have to repackage make a .framework target.  I will take
  contributions. Message me if you are interested.


Depending on how you configure your project you may need to ``#import`` either
``<SocketRocket/SRWebSocket.h>`` or ``"SRWebSocket.h"``

Framework Dependencies
``````````````````````
Your .app must be linked against the following frameworks/dylibs

- libicucore.dylib
- CFNetwork.framework
- Security.framework
- Foundation.framework

Installing (OS X)
-----------------
SocketRocket now has (64-bit only) OS X support.  ``SocketRocket.framework``
inside Xcode project is for OS X only.  It should be identical in function aside
from the unicode validation.  ICU isn't shipped with OS X which is what the
original implementation used for unicode validation.  The workaround is much
more rudimentary and less robust.

1. Add SocketRocket.xcodeproj as either a subproject of your app or in your workspace.
2. Add ``SocketRocket.framework`` to the link libraries
3. If you don't have a "copy files" step for ``Framework``, create one
4. Add ``SocketRocket.framework`` to the "copy files" step.

API
---
The classes

``SRWebSocket``
```````````````
The Web Socket.

.. note:: ``SRWebSocket`` will retain itself between ``-(void)open`` and when it
  closes, errors, or fails.  This is similar to how ``NSURLConnection`` behaves.
  (unlike ``NSURLConnection``, ``SRWebSocket`` won't retain the delegate)

What you need to know

.. code-block:: objective-c

  @interface SRWebSocket : NSObject

  // Make it with this
  - (id)initWithURLRequest:(NSURLRequest *)request;

  // Set this before opening
  @property (nonatomic, assign) id <SRWebSocketDelegate> delegate;

  - (void)open;
  
  // Close it with this
  - (void)close;

  // Send a UTF8 String or Data
  - (void)send:(id)data;

  @end

``SRWebSocketDelegate``
```````````````````````
You implement this

.. code-block:: objective-c

  @protocol SRWebSocketDelegate <NSObject>

  - (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message;

  @optional

  - (void)webSocketDidOpen:(SRWebSocket *)webSocket;
  - (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error;
  - (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean;

  @end

Known Issues/Server Todo's
--------------------------
- Needs auth delegates (like in NSURLConnection)
- Move the streams off the main runloop (most of the work is backgrounded uses
  GCD, but I just haven't gotten around to moving it off the main loop since I
  converted it from dispatch_io)
- Re-implement server. I removed an existing implementation as well because it
  wasn't being used and I wasn't super happy with the interface.  Will revisit
  this.
- Separate framer and client logic. This will make it nicer when having a
  server.

Testing
-------
Included are setup scripts for the python testing environment.  It comes
packaged with vitualenv so all the dependencies are installed in userland.

To run the short test from the command line, run::

  make test

To run all the tests, run::

  make test_all

The short tests don't include the performance tests.  (the test harness is
actually the bottleneck, not SocketRocket).

The first time this is run, it may take a while to install the dependencies.  It
will be smooth sailing after that.  After the test runs the makefile will open
the results page in your browser.  If nothing comes up, you failed.  Working on
making this interface a bit nicer.

To run from the app, choose the ``SocketRocket`` target and run the test action
(``cmd+u``). It runs the same thing, but makes it easier to debug.  There is
some serious pre/post hooks in the Test action.  You can edit it to customize
behavior.

.. note:: Xcode only up to version 4.4 is currently supported for the test
  harness

TestChat Demo Application
-------------------------
SocketRocket includes a demo app, TestChat.  It will "chat" with a listening
websocket on port 9900.

It's a simple project.  Uses storyboard.  Storyboard is sweet.


TestChat Server
```````````````
We've included a small server for the chat app.  It has a simple function.
It will take a message and broadcast it to all other connected clients.

We have to get some dependencies.  We also want to reuse the virtualenv we made
when we ran the tests. If you haven't run the tests yet, go into the
SocketRocket root directory and type::

  make test

This will set up your `virtualenv <https://pypi.python.org/pypi/virtualenv>`_.
Now, in your terminal::

  source .env/bin/activate
  pip install git+https://github.com/tornadoweb/tornado.git

In the same terminal session, start the chatroom server::

  python TestChatServer/py/chatroom.py

There's also a Go implementation (with the latest weekly) where you can::

  cd TestChatServer/go
  go run chatroom.go

Chatting
````````
Now, start TestChat.app (just run the target in the Xcode project).  If you had
it started already you can hit the refresh button to reconnect.  It should say
"Connected!" on top.

To talk with the app, open up your browser to `http://localhost:9000 <http://localhost:9000>`_ and
start chatting.


WebSocket Server Implementation Recommendations
-----------------------------------------------
SocketRocket has been used with the following libraries:

- `Tornado <https://github.com/facebook/tornado>`_
- Go's `WebSocket package <https://godoc.org/golang.org/x/net/websocket>`_ or Gorilla's `version <http://www.gorillatoolkit.org/pkg/websocket>`_
- `Autobahn <http://tavendo.com/autobahn/testsuite.html>`_ (using its fuzzing
  client)

The Tornado one is dirt simple and works like a charm.  (`IPython notebook
<http://ipython.org/ipython-doc/dev/interactive/htmlnotebook.html>`_ uses it
too).  It's much easier to configure handlers and routes than in
Autobahn/twisted.

As far as Go's goes, it works in my limited testing. I much prefer go's
concurrency model as well. Try it! You may like it.
It could use some more control over things such as pings, etc., but I
am sure it will come in time.

Autobahn is a great test suite.  The Python server code is good, and conforms
well (obviously).  However for me, twisted would be a deal-breaker for writing
something new.  I find it a bit too complex and heavy for a simple service. If
you are already using twisted though, Autobahn is probably for you.

Contributing
------------
We’re glad you’re interested in SocketRocket, and we’d love to see where you take it. Please read our `contributing guidelines <https://github.com/square/SocketRocket/blob/master/Contributing.md>`_ prior to submitting a Pull Request.