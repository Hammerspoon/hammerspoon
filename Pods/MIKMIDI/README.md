This README file is meant to give a broad overview of MIKMIDI. More complete documentation for MIKMIDI can be found [here](http://cocoadocs.org/docsets/MIKMIDI). Questions should be directed to [Andrew Madsen](mailto:andrew@openreelsoftware.com).

MIKMIDI
-------

MIKMIDI is an easy-to-use Objective-C MIDI library created by Andrew Madsen and developed by him and Chris Flesner of [Mixed In Key](http://www.mixedinkey.com/). It's useful for programmers writing Objective-C or Swift OS X or iOS apps that use MIDI. It includes the ability to communicate with external MIDI devices, to read and write MIDI files, to record and play back MIDI, etc. MIKMIDI is used to provide MIDI functionality in the OS X versions of our DJ app, [Flow](http://flowdjsoftware.com), our flagship app [Mixed In Key](http://www.mixedinkey.com/), and our composition software, [Odesi](http://odesi.mixedinkey.com).

MIKMIDI can be used in projects targeting Mac OS X 10.7 and later, and iOS 6 and later. The example code in this readme is in Objective-C. However, MIKMIDI can also easily be used from Swift code.

MIKMIDI is released under an MIT license, meaning you're free to use it in both closed and open source projects. However, even in a closed source project, you must include a publicly-accessible copy of MIKMIDI's copyright notice, which you can find in the LICENSE file.

If you have any questions about, or suggestions for MIKMIDI, please [contact the maintainer](mailto:andrew@openreelsoftware.com). Contributions are always welcome. Please see our [contribution guidelines](CONTRIBUTING.md) for more information. We'd also always love to hear about any cool projects you're using it in.

How To Use MIKMIDI
------------------

MIKMIDI ships with a project to build frameworks for iOS and macOS. You can also install it using CocoaPods or Carthage. See [this page](https://github.com/mixedinkey-opensource/MIKMIDI/wiki/Installing-MIKMIDI) on the MIKMIDI wiki for detailed instructions for adding MIKMIDI to your project.

MIKMIDI Overview
----------------

MIKMIDI has an Objective-C interface -- as opposed to CoreMIDI's pure C API -- in order to make adding MIDI support to a Cocoa/Cocoa Touch app easier. At its core, MIKMIDI consists of relatively thin Objective-C wrappers around underlying CoreMIDI APIs. Much of MIKMIDI's design is informed and driven by CoreMIDI's design. For this reason, familiarity with the high level pieces of [CoreMIDI](https://developer.apple.com/library/iOS/documentation/CoreMidi/Reference/MIDIServices_Reference/Reference/reference.html) can be helpful in understanding and using MIKMIDI.

MIKMIDI is not limited to Objective-C interfaces for existing CoreMIDI functionality. MIKMIDI provides a number of higher level features. These include: message routing, sequencing, recording, etc.. Also included is functionality intended to facilitate implementing a MIDI learning UI so that users may create custom MIDI mapping files. These MIDI mapping files associate physical controls on a particular piece of MIDI hardware with corresponding receivers (e.g. on-screen buttons, knobs, musical instruments, etc.) in your application.

To understand MIKMIDI, it's helpful to break it down into its major subsystems:

- Device support -- includes support for device discovery, connection/disconnection, and sending/receiving MIDI messages.
- Commands -- includes a number of Objective-C classes that various represent MIDI message types as received from and sent to MIDI devices and endpoints.
- Mapping -- support for generating, saving, loading, and using files that associate physical MIDI controls with corresponding application features.
- Files -- support for reading and writing MIDI files.
- Synthesis -- support for turning MIDI into audio, e.g. playback of MIDI files and incoming MIDI keyboard input.
- Sequencing -- Recording and playback of MIDI.

Of course, these subsystems are used together to enable sophisticated features.

Device Support
--------------

MIKMIDI's device support architecture is based on the underlying CoreMIDI architecture. There are several major classes used to represent portions of a device. All of these classes are subclasses of `MIKMIDIObject`. These classes are listed below. In parentheses is the corresponding CoreMIDI class.

- MIKMIDIObject (MIDIObjectRef) -- Abstract base class for all the classes listed below. Includes properties common to all MIDI objects.
- MIKMIDIDevice (MIDIDeviceRef) -- Represents a single physical device, e.g. a DJ controller, MIDI keyboard, MIDI drum set, etc.
- MIKMIDIEntity (MIDIEntityRef) -- Groups related endpoints. Owned by MIKMIDIDevice, contains MIKMIDIEndpoints.
- MIKMIDIEndpoint (MIDIEndpointRef) -- Abstract base class representing a MIDI endpoint. Not used directly, only via its subclasses MIKMIDISourceEndpoint and MIKMIDIDestinationEndpoint.
- MIKMIDISourceEndpoint -- Represents a MIDI source. MIDI sources receive messages that your application can hear and process.
- MIKMIDIDestinationEndpoint -- Represents a MIDI destination. Your application passes MIDI messages to a destination endpoint in order to send them to a device.

`MIKMIDIDeviceManager` is a singleton class used for device discovery, and to send and receive MIDI messages to and from endpoints. To get a list of MIDI devices available on the system, call `-availableDevices` on the shared device manager:

    NSArray *availableMIDIDevices = [[MIKMIDIDeviceManager sharedDeviceManager] availableDevices];

`MIKMIDIDeviceManager` also includes the ability to retrieve 'virtual' endpoints, to enable communicating with other MIDI apps, or with devices (e.g. Native Instruments controllers) which present as virtual endpoints rather than physical devices.

`MIKMIDIDeviceManager`'s `availableDevices`, and `virtualSources` and `virtualDestinations` properties are Key Value Observing (KVO) compliant. This means that for example, `availableDevices` can be bound to an `NSPopupMenu` in an OS X app to provide an automatically updated list of connected MIDI devices. They can also be directly observed using key value observing to be notified when devices are connected or disconnected, etc. Additionally, `MIKMIDIDeviceManager` posts these notifications: `MIKMIDIDeviceWasAddedNotification`, `MIKMIDIDeviceWasRemovedNotification`, `MIKMIDIVirtualEndpointWasAddedNotification`, `MIKMIDIVirtualEndpointWasRemovedNotification`.

`MIKMIDIDeviceManager` is used to sign up to receive messages from MIDI endpoints as well as to send them. To receive messages from a `MIKMIDISourceEndpoint`, you must connect the endpoint and supply an event handler block to be called anytime messages are received. This is done using the `-connectInput:error:eventHandler:` method. When you no longer want to receive messages, you must call the `-disconnectInput:` method. To send MIDI messages to an `MIKMIDIDestinationEndpoint`, call `-[MIKMIDIDeviceManager sendCommands:toEndpoint:error:]` passing an `NSArray` of `MIKMIDICommand` instances. For example:

```objective-c
NSDate *date = [NSDate date];
MIKMIDINoteOnCommand *noteOn = [MIKMIDINoteOnCommand noteOnCommandWithNote:60 velocity:127 channel:0 timestamp:date];
MIKMIDINoteOffCommand *noteOff = [MIKMIDINoteOffCommand noteOffCommandWithNote:60 velocity:0 channel:0 timestamp:[date dateByAddingTimeInterval:0.5]];

MIKMIDIDeviceManager *dm = [MIKMIDIDeviceManager sharedDeviceManager];
[dm sendCommands:@[noteOn, noteOff] toEndpoint:destinationEndpoint error:&error];
```

If you've used CoreMIDI before, you may be familiar with `MIDIClientRef` and `MIDIPortRef`. These are used internally by MIKMIDI, but the "public" API for MIKMIDI does not expose them -- or their Objective-C counterparts -- directly. Rather, `MIKMIDIDeviceManager` itself allows sending and receiving messages to/from `MIKMIDIEndpoint`s.

MIDI Messages
-------------

In MIKMIDI, MIDI messages are Objective-C objects. These objects are instances of concrete subclasses of `MIKMIDICommand`. Each MIDI message type (e.g. Control Change, Note On, System Exclusive, etc.) has a corresponding class (e.g. MIKMIDIControlChangeCommand). Each command class has properties specific to that message type. By default, MIKMIDICommands are immutable. Mutable variants of each command type are also available.

MIDI Mapping
------------

MIKMIDI includes features to help with adding MIDI mapping support to an application. MIDI mapping refers to the ability to map physical controls on a particular hardware controller to specific functions in the application. MIKMIDI's mapping support includes the ability to generate, save, load, and use mapping files that associate physical controls with an application's specific functionality. It also includes help with implementing a system that allows end users to easily generate their own mappings using a "MIDI learn" style interface.

The major components of MIKMIDI's MIDI mapping functionality are:

- MIKMIDIMapping - Model class containing information to map incoming messages to to the appropriate application functionality.
- MIKMIDIMappingManager - Singleton manager used to load, save, and retrieve both application-bundled, and user customized mapping files.
- MIKMIDIMappingGenerator - Class that can listen to incoming MIDI messages, and associate them with application functionality, creating a custom MIDI mapping file.

MIDI Files
----------

MIKMIDI includes features to make it easy to read and write MIDI files. This support is primarily provided by:

- MIKMIDISequence - This class is used to represent a MIDI sequence, and can be read from or written to a MIDI file.
- MIKMIDITrack - An MIKMIDISequence contains one or more MIKMIDITracks.
- MIKMIDIEvent - MIKMIDIEvent and its specific subclasses are used to represent MIDI events contained by MIKMIDITracks.

MIDI Synthesis
--------------

MIDI synthesis is the process by which MIDI events/messages are turned into audio that you can hear. This is accomplished using `MIKMIDISynthesizer`. Also included is a subclass of `MIKMIDISynthesizer`, `MIKMIDIEndpointSynthesizer` which can very easily be hooked up to a MIDI endpoint to synthesize incoming MIDI messages:

```objective-c
MIKMIDISourceEndpoint *endpoint = midiDevice.entities.firstObject.sources.firstObject;
MIKMIDISynthesizer *synth = [[MIKMIDIEndpointSynthesizer alloc] initWithMIDISource:endpoint];
```

MIDI Sequencing
---------------

`MIKMIDISequencer` can be used to play and record to an `MIKMIDISequence`. It includes a number of high level features useful when implementing MIDI recording and playback. However, at the very simplest, MIKMIDISequencer can be used to load a MIDI file and play it like so:

```objective-c
MIKMIDISequence *sequence = [MIKMIDISequence sequenceWithFileAtURL:midiFileURL error:&error];
MIKMIDISequencer *sequencer = [MIKMIDISequencer sequencerWithSequence:sequence];
[sequencer startPlayback];
```
