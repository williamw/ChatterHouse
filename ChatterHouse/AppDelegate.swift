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
    
    var audioPermission = AVCaptureDevice.authorizationStatus(for: .audio)
    let audioEngine = AVAudioEngine()
    let audioPlayer = AVAudioPlayerNode()
    let audioBus = 0
    lazy var inputNode = audioEngine.inputNode
    lazy var audioFormat = inputNode.inputFormat(forBus: audioBus)
//    let audioFormat = AVAudioFormat(
//    commonFormat: .pcmFormatFloat32,
//    sampleRate: 44100,
//    channels: 1,
//    interleaved: true )!
    
    var broadcastActive: Bool!
    var listeningActive: Bool!
    
    var popover: NSPopover!
    var statusBarItem: NSStatusItem!
    var eventMonitor: EventMonitor?
    
    var multipeerConfig = MultipeerConfiguration.default
    private lazy var transceiver: MultipeerTransceiver = {
        multipeerConfig.serviceType = "ChatterHouse"
        multipeerConfig.peerName = Host.current().name!
        let t = MultipeerTransceiver(configuration: multipeerConfig)
        
        t.receive(AudioPayload.self) { [weak self] payload in
            self!.receiveBroadcast(payload)
        }
        return t
    }()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Keep track of whether or not we're broadcasting
        broadcastActive = false
        
        // Keep track of whether or not we're listening
        listeningActive = true
        
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
        inputNode.installTap(
            onBus: 0,         // mono input
            bufferSize: 2048, // a request, not a guarantee
            format: audioFormat,      // no format translation
            block: { buffer, when in
                self.broadcastAudio(buffer)
        })
        
        // Setup the audio player and output
        audioEngine.attach(audioPlayer)
        audioEngine.connect(audioPlayer, to:audioEngine.outputNode, format: nil)
        
        do {
            try audioEngine.start()
            audioPlayer.play()
        } catch let error as NSError {
            print("Got an error starting audioEngine: \(error.domain), \(error)")
        }
        
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
        
        // Setup the global broadcast hotkey
        guard let keyCombo = KeyCombo(doubledCocoaModifiers: .control) else { return }
        // guard let keyCombo = KeyCombo(key: .b, cocoaModifiers: [.command, .control]) else { return }
        let hotKey = HotKey(identifier: "CommandControlB",
                            keyCombo: keyCombo,
                            target: self,
                            action: #selector(AppDelegate.toggleBroadcastStatus))
        hotKey.register()
    }
    
    func broadcastAudio(_ buffer: AVAudioPCMBuffer) {
        if self.broadcastActive == true {
            let bufferData = Data(buffer: buffer)
            // print("Data: \(String(describing: bufferData))")
            
            let payload = AudioPayload(from: self.multipeerConfig.peerName, status: "buffer", data: bufferData)
            self.transceiver.send(payload, to: transceiver.availablePeers)
            //self.transceiver.broadcast(payload)
            //receiveBroadcast(payload)
        }
    }
    
    func receiveBroadcast(_ payload:AudioPayload) {
        switch (payload.status) {
        case "start", "stop":
            NSSound(named: .pop)?.play()
            break
            
        case "buffer":
            if listeningActive == true {
                let buffer = payload.data?.makePCMBuffer(format: audioFormat)
                audioPlayer.scheduleBuffer(buffer!,
                                                 at: nil,
                                                 options: AVAudioPlayerNodeBufferOptions(),
                                                 completionHandler: nil)
            }
            break
            
        default: break
        }

        print("Received \(payload.status) from \(payload.from) \(String(describing: payload.data))")
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
            self.audioPermission = AVCaptureDevice.authorizationStatus(for: .audio)
            print("Audio Permission: \(accessGranted)")
        }
    }
    
    @objc func openSystemPreferences() {
        let url: String = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        NSWorkspace.shared.open(URL(string: url)!)
    }
    
    // Start / stop broadcasting
    @objc func toggleBroadcastStatus() {
        if broadcastActive {
            stopBroadcasting()
        } else {
            startBroadcasting()
        }
    }
    
    func startBroadcasting() {
        if (audioPermission == .authorized) {
            broadcastActive = true
            listeningActive = false
            
            NSSound(named: .pop)?.play()
            
            let payload = AudioPayload(from: multipeerConfig.peerName, status: "start", data: nil)
            transceiver.broadcast(payload)
            
            if let button = self.statusBarItem.button {
                button.image = NSImage(named: "Icon-On")
            }
        }
    }
    
    func stopBroadcasting() {
        broadcastActive = false
        listeningActive = true
        
        NSSound(named: .pop)?.play()
        
        let payload = AudioPayload(from: multipeerConfig.peerName, status: "stop", data: nil)
        transceiver.broadcast(payload)
        
        if let button = self.statusBarItem.button {
            button.image = NSImage(named: "Icon-Off")
        }
    }
    
    // Start / stop listening
    @objc func toggleListeningStatus() {
        if let button = self.statusBarItem.button {
            if listeningActive {
                stopBroadcasting()
                listeningActive = false
                transceiver.stop()
                button.image = NSImage(named: "Icon-Silenced")
            } else {
                transceiver.resume()
                listeningActive = true
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
            if broadcastActive {
                startStop = "Stop"
            } else {
                startStop = "Start"
            }
        
            menu.addItem(NSMenuItem(title: "\(startStop!) Broadcasting", action: #selector(toggleBroadcastStatus), keyEquivalent: ""))
        } else {
            menu.addItem(NSMenuItem(title: "Provide Access to Microphone...", action: #selector(openSystemPreferences), keyEquivalent: ""))
        }
        
        let silenceItem: NSMenuItem = NSMenuItem(title: "Silence", action: #selector(toggleListeningStatus), keyEquivalent: "")
        if listeningActive == true {
            silenceItem.state = NSControl.StateValue.off
        } else {
            silenceItem.state = NSControl.StateValue.on
        }

        if !broadcastActive { menu.addItem(silenceItem) }
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
        stopBroadcasting()
    }
}
