//
//  Camera.swift
//  Hammertime
//
//  Created by Chris Jones on 20/12/2023.
//  Copyright © 2023 Hammerspoon. All rights reserved.
//

import Foundation
import AVFoundation
import CoreMediaIO
import IOKit.audio

let allCameraTypes:[AVCaptureDevice.DeviceType] = [
    .external,
    .builtInWideAngleCamera,
    .continuityCamera,
    .deskViewCamera
]

public typealias CameraManagerDiscoveryCallback = @convention(block) (Camera?, String) -> Void

@objc public class CameraManager : NSObject {
    @objc var discoverySession: AVCaptureDevice.DiscoverySession

    // We cache the cameras because we're storing extra information in their class and would lose that if we just used DiscoverySession.devices
    var cache:[String: Camera] = [:]

    var cameraObserver: NSKeyValueObservation? = nil
    @objc public var observerCallback: CameraManagerDiscoveryCallback?

    @objc public override init() {
        discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: allCameraTypes, mediaType: .video, position: .unspecified)
    }

    /// Get all cameras known to the OS
    /// - Returns: array of AVCaptureDevice
    @objc public func getCameras() -> [String:Camera] {
        updateCache()
        return cache
    }

    /// Get a specific camera by its Unique ID
    /// - Parameter forID: String containing the camera's ID
    /// - Returns: AVCaptureDevice or nil if the ID wasn't found
    @objc public func getCamera(forID: String) -> Camera? {
        for pair in cache {
            if pair.key == forID {
                return pair.value
            }
        }
        return nil
    }
    
    /// Update our camera cache
    func updateCache() {
        for camera in discoverySession.devices {
            if (!cache.keys.contains(camera.uniqueID)) {
                cache[camera.uniqueID] = Camera(uniqueID: camera.uniqueID)
            }
        }
    }

    /// Empty the camera cache, typically because the host program is restarting and wants a clean slate
    @objc public func drainCache() {
        cache = [:]
    }
    
    /// True if the camera device watcher is running, otherwise False
    @objc public var isWatcherRunning: Bool {
        cameraObserver != nil
    }

    /// Start watching for camera addition/removal events
    @objc public func startWatcher() {
        guard let observerCallback = self.observerCallback else { return }
        if (cameraObserver != nil) {
            return
        }

        cameraObserver = observe(\.discoverySession.devices, options: [.new, .old], changeHandler: { object, change in
            for change in change.newValue!.difference(from: change.oldValue!) {
                switch change {
                case let .remove(offset: _, element: device, associatedWith: _):
                    if let camera = self.getCamera(forID: device.uniqueID) {
                        observerCallback(camera, "Removed")
                        self.cache.removeValue(forKey: device.uniqueID)
                    }
                case let .insert(offset: _, element: device, associatedWith: _):
                    if let camera = Camera(uniqueID: device.uniqueID) {
                        observerCallback(camera, "Added")
                        self.cache[device.uniqueID] = camera
                    }
                }
            }
        })
    }

    /// Stop watching for camera addition/removal events
    @objc public func stopWatcher() {
        cameraObserver?.invalidate()
    }
}

@objc public class Camera : NSObject {
    /// Underlying AVFoundation camera object we represent
    @objc var camera: AVCaptureDevice
    /// Optional pointer storage for additional data that needs to be associated with instances of this class
    @objc public var userData: UnsafeMutableRawPointer?

    private var STATUS_PA = CMIOObjectPropertyAddress(
        mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
        mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
        mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard)
    )

    /// True if our `isInUse` watcher is running
    @objc public var isInUseWatcherRunning: Bool = false

    // This is ugly and awful, but CoreMediaIO is the only reliable way to tell if a camera is in use
    var connectionID: CMIOObjectID {
        camera.value(forKey: "_connectionID")! as! CMIOObjectID
    }

    /// External callback to be called when a watched property changes
    @objc public var isInUseWatcherCallbackProc: CMIOObjectPropertyListenerProc = { _,_,_,_ -> OSStatus in
        NSLog("Camera::isInUseWatcherCallbackProc called without initialisation")
        return 0
    }

    /// Initialiser
    /// - Parameter uniqueID: The UID of a camera object, as obtained from AVCaptureDevice.uniqueID
    @objc public init?(uniqueID: String) {
        guard let cameraDevice = AVCaptureDevice(uniqueID: uniqueID) else { return nil }
        self.camera = cameraDevice
    }
    
    /// The camera's unique ID
    @objc public var uniqueID: String {
        camera.uniqueID
    }
    
    /// The camera's model identifier
    @objc public var modelID: String {
        camera.modelID
    }
    
    /// Human readable name of the camera
    @objc public var name: String {
        camera.localizedName
    }
    
    /// The camera's manufacturer (often an empty string)
    @objc public var manufacturer: String {
        camera.manufacturer
    }
    
    /// True if someone is using the camera, otherwise False
    @objc public var isInUse: Bool {
        // Code taken from: https://github.com/wouterdebie/onair/blob/master/Sources/onair/Camera.swift
        // (although this is pretty much exactly how Hammerspoon's earlier versions did the same thing in Objective C)
        var (dataSize, dataUsed) = (UInt32(0), UInt32(0))
        if CMIOObjectGetPropertyDataSize(connectionID, &STATUS_PA, 0, nil, &dataSize) == OSStatus(kCMIOHardwareNoError) {
            if let data = malloc(Int(dataSize)) {
                CMIOObjectGetPropertyData(connectionID, &STATUS_PA, 0, nil, dataSize, &dataUsed, data)
                let output = data.assumingMemoryBound(to: UInt8.self).pointee > 0
                free(data)
                return output
            }
        }
        return false
    }
    
    /// Underlying interface by which the camera is connected
    @objc public var transportType: String {
        switch (camera.transportType) {
        case Int32(kIOAudioDeviceTransportTypeUSB):
            return "USB"
        case Int32(kIOAudioDeviceTransportTypeBuiltIn):
            return "BuiltIn"
        case Int32(kIOAudioDeviceTransportTypePCI):
            return "PCI"
        case Int32(kIOAudioDeviceTransportTypeVirtual):
            return "Virtual"
        case Int32(kIOAudioDeviceTransportTypeWireless):
            return "Wireless"
        case Int32(kIOAudioDeviceTransportTypeNetwork):
            return "Network"
        case Int32(kIOAudioDeviceTransportTypeFireWire):
            return "Firewire"
        case Int32(kIOAudioDeviceTransportTypeOther):
            return "Other"
        case Int32(kIOAudioDeviceTransportTypeBluetooth):
            return "Bluetooth"
        case Int32(kIOAudioDeviceTransportTypeDisplayPort):
            return "DisplayPort"
        case Int32(kIOAudioDeviceTransportTypeHdmi):
            return "HDMI"
        case Int32(kIOAudioDeviceTransportTypeAVB):
            return "AVB"
        case Int32(kIOAudioDeviceTransportTypeThunderbolt):
            return "Thunderbolt"
        default:
            return "Unknown kIOAudioDeviceTransportType \(camera.transportType). Please file a bug."
        }
    }

    /// Start watching `isInUse` for changes
    @objc public func startIsInUseWatcher() {
        if (isInUseWatcherRunning) { return }

        let result = CMIOObjectAddPropertyListener(connectionID,
                                                   &STATUS_PA,
                                                   self.isInUseWatcherCallbackProc,
                                                   Unmanaged.passUnretained(self).toOpaque())
        if (result == kCMIOHardwareNoError) {
            isInUseWatcherRunning = true
        } else {
            NSLog("Unable to add property listener block: \(result) (\(name))")
        }
    }
    
    /// Stop watching `isInUse`
    @objc public func stopIsInUseWatcher() {
        if (!isInUseWatcherRunning) { return }

        let result = CMIOObjectRemovePropertyListener(connectionID,
                                                      &STATUS_PA,
                                                      self.isInUseWatcherCallbackProc,
                                                      Unmanaged.passUnretained(self).toOpaque())
        if (result == kCMIOHardwareNoError) {
            isInUseWatcherRunning = false
        } else {
            NSLog("Unable to remove property listener block: \(result) (\(name))")
        }
    }
}
