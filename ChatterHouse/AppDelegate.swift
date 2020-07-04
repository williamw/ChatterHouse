//
//  AppDelegate.swift
//  ChatterHouse
//
//  Created by Bill Welense on 6/28/20.
//  Copyright © 2020 Bill Welense. All rights reserved.
//

import Cocoa
import SwiftUI
import Magnet
import MultipeerKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    
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
        popover.contentSize = NSSize(width: 400, height: 400)
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
            (event.modifierFlags.contains(.control)) {
            // Right-click or ctrl+click
            presentMenu()
            sender.performClick(nil)
        } else {
            // Left-click
            toggleBroadcastStatus()
        }
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
        if let button = self.statusBarItem.button {
            let payload = AudioPayload(message: "\(config.peerName) started broadcasting")
            
            sharedBroadcastStatus = true
            button.image = NSImage(named: "Icon-On")
            
            transceiver.broadcast(payload)
        }
    }
    
    func stopBroadcasting() {
        if let button = self.statusBarItem.button {
            sharedBroadcastStatus = false
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
        var startStop: String!
        
        if sharedBroadcastStatus {
            startStop = "Stop"
        } else {
            startStop = "Start"
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "\(startStop!) Broadcasting", action: #selector(toggleBroadcastStatus), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Silence", action: #selector(toggleListeningStatus), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(togglePopover(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit ChatterHouse", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
        
        if let listeningItem = menu.item(withTitle: "Silence") {
            if sharedListeningStatus == true {
                listeningItem.state = NSControl.StateValue.off
            } else {
                listeningItem.state = NSControl.StateValue.on
            }
        }
        
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
