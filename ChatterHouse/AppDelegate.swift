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
    
    private lazy var dataSource: MultipeerDataSource = {
        MultipeerDataSource(transceiver: transceiver)
    }()
    
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Create the SwiftUI view that provides the window contents.
        let contentView = ContentView().environmentObject(dataSource)
        
        transceiver.resume()
        
        self.statusBarItem = NSStatusBar.system.statusItem(withLength: CGFloat(NSStatusItem.variableLength))
        if let button = self.statusBarItem.button {
            button.image = NSImage(named: "Icon")
            button.action = #selector(statusBarButtonClicked(sender:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            // button.action = #selector(togglePopover(_:))
        }
        
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView)
        self.popover = popover
        
        // ⌘ + Control + B
        guard let keyCombo = KeyCombo(key: .b, cocoaModifiers: [.command, .control]) else { return }
        let hotKey = HotKey(identifier: "CommandControlB",
                            keyCombo: keyCombo,
                            target: self,
                            action: #selector(AppDelegate.tappedHotKey))
        hotKey.register()
        
        // Close the pop-over when it loses focus
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let strongSelf = self, strongSelf.popover.isShown {
                strongSelf.statusBarItem.menu = nil
                strongSelf.closePopover(sender: event)
            }
        }
    }
    
    // Detect if left or right-click on icon
    @objc func statusBarButtonClicked(sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!

        if (event.type ==  NSEvent.EventType.rightMouseUp) ||
            (event.modifierFlags.contains(.control)) {
            constructMenu()
            sender.performClick(nil)
        } else {
            togglePopover(sender)
        }
    }
    
    // Show/hide main app popover
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
    
    @objc func tappedHotKey() {
        print("hotKey tapped locally")
        let payload = AudioPayload(message: "hotKey broadcast from \(config.peerName)")
        transceiver.broadcast(payload)
    }
    
    func constructMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit ChatterHouse", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusBarItem.menu = menu
        statusBarItem.menu?.delegate = self
    }
    
    @objc func menuDidClose(_ menu: NSMenu) {
        statusBarItem.menu = nil // remove menu so menu icon works as before
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
}

