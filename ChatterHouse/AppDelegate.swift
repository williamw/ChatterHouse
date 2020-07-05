//
//  AppDelegate.swift
//  ChatterHouse
//
//  Created by Bill Welense on 6/28/20.
//  Copyright © 2020 Bill Welense. All rights reserved.
//

import Cocoa
import SwiftUI
import AVFoundation

import MultipeerKit
import Magnet

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    
    let audioEngine = AVAudioEngine()
    let audioPermission = AVCaptureDevice.authorizationStatus(for: .audio)
    
    var sharedBroadcastStatus: Bool!
    var sharedListeningStatus: Bool!
    
    var popover: NSPopover!
    var statusBarItem: NSStatusItem!
    var eventMonitor: EventMonitor?
    var config = MultipeerConfiguration.default
    
    private lazy var transceiver: MultipeerTransceiver = {
        config.serviceType = "ChatterHouse"
        config.peerName = Host.current().name!
        let t = MultipeerTransceiver(configuration: config)
        
        t.receive(AudioPayload.self) { [weak self] payload in
            print(payload.message)
            NSSound(named: .pop)?.play()
        }
        return t
    }()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Keep track of whether or not we're broadcasting
        sharedBroadcastStatus = false
        
        // Keep track of whether or not we're listening
        sharedListeningStatus = true
        
        // Start listening for broadcasts
        transceiver.resume()
        
        // Handle microphone permission
        // TODO: Add button to preference for requesting audio permission if not authorized
        switch (audioPermission) {
        case .notDetermined:
            requestAudioPermission()
            break
            
        case .authorized: break
            
        case .denied: break
            
        case .restricted: break
            
        default: break }
        
        // Tap the audio input
        let inputNode = audioEngine.inputNode
        inputNode.installTap(
            onBus: 0,         // mono input
            bufferSize: 1024, // a request, not a guarantee
            format: nil,      // no format translation
            block: { buffer, when in
                print("Audio: \(String(describing: buffer))") // AVAudioPCMBuffer
        })
        
        // Setup the menubar icon
        self.statusBarItem = NSStatusBar.system.statusItem(withLength: CGFloat(NSStatusItem.variableLength))
        if let button = self.statusBarItem.button {
            button.image = NSImage(named: "Icon-Off")
            button.action = #selector(statusBarButtonClicked(sender:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // Create the SwiftUI view that provides the Preferences popover
        let contentView = ContentView()
        
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 350, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView)
        self.popover = popover
        
        // Close the Preferences popover when it loses focus
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let strongSelf = self, strongSelf.popover.isShown {
                strongSelf.statusBarItem.menu = nil
                strongSelf.closePopover(sender: event)
            }
        }
        
        // Setup the global hotkey
        guard let keyCombo = KeyCombo(doubledCocoaModifiers: .control) else { return }
        // guard let keyCombo = KeyCombo(key: .b, cocoaModifiers: [.command, .control]) else { return }
        let hotKey = HotKey(identifier: "CommandControlB",
                            keyCombo: keyCombo,
                            target: self,
                            action: #selector(AppDelegate.toggleBroadcastStatus))
        hotKey.register()
    }
    
    // Detect if left or right-click on icon
    @objc func statusBarButtonClicked(sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        
        if (event.type ==  NSEvent.EventType.rightMouseUp) ||
            (event.modifierFlags.contains(.control)) ||
            (audioPermission != .authorized) {
            // Right-click or ctrl+click
            presentMenu()
            sender.performClick(nil)
        } else {
            // Left-click
            toggleBroadcastStatus()
        }
    }
    
    // Grant permission to microphone
    @objc func requestAudioPermission() {
        AVCaptureDevice.requestAccess(for: .audio) { (accessGranted) in
            print("Audio Permission: \(accessGranted)")
        }
    }
    
    @objc func openSystemPreferences() {
        let url: String = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        NSWorkspace.shared.open(URL(string: url)!)
    }
    
    // Start / stop broadcasting
    @objc func toggleBroadcastStatus() {
        if sharedBroadcastStatus {
            stopBroadcasting()
        } else {
            startBroadcasting()
        }
    }
    
    func startBroadcasting() {
        if (audioPermission == .authorized) {
            sharedBroadcastStatus = true
            
            let message = AudioPayload(message: "\(config.peerName) started broadcasting")
            transceiver.broadcast(message)
            
            do {
                try audioEngine.start()
            } catch let error as NSError {
                print("Got an error starting audioEngine: \(error.domain), \(error)")
            }
            
            if let button = self.statusBarItem.button {
                button.image = NSImage(named: "Icon-On")
            }
        } else {
            
        }
    }
    
    func stopBroadcasting() {
        sharedBroadcastStatus = false
        if audioPermission == .authorized { audioEngine.stop() }
        
        if let button = self.statusBarItem.button {
            button.image = NSImage(named: "Icon-Off")
        }
    }
    
    // Start / stop listening
    @objc func toggleListeningStatus() {
        if let button = self.statusBarItem.button {
            if sharedListeningStatus {
                sharedListeningStatus = false
                stopBroadcasting()
                transceiver.stop()
                button.image = NSImage(named: "Icon-Silenced")
            } else {
                sharedListeningStatus = true
                transceiver.resume()
                button.image = NSImage(named: "Icon-Off")

            }
        }
    }
    
    // Show/hide Preferences popover
    @objc func togglePopover(_ sender: Any?) {
        if popover.isShown {
            closePopover(sender: sender)
        } else {
            showPopover(sender: sender)
        }
    }
    
    func showPopover(sender: Any?) {
        if let button = statusBarItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
        }
        
        eventMonitor?.start()
    }
    
    func closePopover(sender: Any?) {
        popover.performClose(sender)
        eventMonitor?.stop()
    }
    
    // Setup the icon's right-click menu
    // Ctrl character: ⌃
    func presentMenu() {
        let menu = NSMenu()
        
        if audioPermission == .authorized {
            var startStop: String!
            if sharedBroadcastStatus {
                startStop = "Stop"
            } else {
                startStop = "Start"
            }
        
            menu.addItem(NSMenuItem(title: "\(startStop!) Broadcasting", action: #selector(toggleBroadcastStatus), keyEquivalent: ""))
        } else {
            menu.addItem(NSMenuItem(title: "Provide Access to Microphone...", action: #selector(openSystemPreferences), keyEquivalent: ""))
        }
        
        let silenceItem: NSMenuItem = NSMenuItem(title: "Silence", action: #selector(toggleListeningStatus), keyEquivalent: "")
        if sharedListeningStatus == true {
            silenceItem.state = NSControl.StateValue.off
        } else {
            silenceItem.state = NSControl.StateValue.on
        }

        menu.addItem(silenceItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(togglePopover(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit ChatterHouse", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
        
        statusBarItem.menu = menu
        statusBarItem.menu?.delegate = self
    }
    
    // Reset left/right-click detection when menu closes
    @objc func menuDidClose(_ menu: NSMenu) {
        statusBarItem.menu = nil // remove menu so menu icon works as before
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
}
