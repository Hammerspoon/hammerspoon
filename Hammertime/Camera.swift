//
//  Camera.swift
//  Hammertime
//
//  Created by Chris Jones on 20/12/2023.
//  Copyright © 2023 Hammerspoon. All rights reserved.
//

import Foundation
import AVFoundation
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

public typealias CameraPropertyCallback = @convention(block) (Camera, Bool) -> Void

// FIXME: Documentation
@objc public class Camera : NSObject {
    @objc var camera: AVCaptureDevice

    @objc public var observerCallback: CameraPropertyCallback?
    @objc public var callbackRef: Int32 = LUA_NOREF // FIXME: This is a smell, Hammertime shouldn't know about Lua
    var isInUseObserver: NSKeyValueObservation? = nil

    @objc public init?(uniqueID: String) {
        guard let cameraDevice = AVCaptureDevice(uniqueID: uniqueID) else { return nil }
        self.camera = cameraDevice
    }

    @objc public var uniqueID: String {
        camera.uniqueID
    }

    @objc public var modelID: String {
        camera.modelID
    }

    @objc public var name: String {
        camera.localizedName
    }

    @objc public var manufacturer: String {
        camera.manufacturer
    }

    @objc public var isInUse: Bool {
        camera.isInUseByAnotherApplication
    }

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
        default:
            return "Unknown kIOAudioDeviceTransportType \(camera.transportType). Please file a bug."
        }
    }

    @objc public var isInUseWatcherRunning: Bool {
        isInUseObserver != nil
    }

    @objc public func startIsInUseWatcher() {
        guard let observerCallback = self.observerCallback else { return }
        if (isInUseObserver != nil) { return }

        isInUseObserver = observe(\.camera.isInUseByAnotherApplication, options: [], changeHandler: { object, _ in
            observerCallback(self, self.camera.isInUseByAnotherApplication)
        })
    }

    @objc public func stopIsInUseWatcher() {
        isInUseObserver?.invalidate()
        isInUseObserver = nil
    }
}
