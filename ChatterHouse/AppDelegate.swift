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

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var popover: NSPopover!
    var statusBarItem: NSStatusItem!


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Create the SwiftUI view that provides the window contents.
        let contentView = ContentView()
        
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView)
        self.popover = popover
        
        self.statusBarItem = NSStatusBar.system.statusItem(withLength: CGFloat(NSStatusItem.variableLength))
        if let button = self.statusBarItem.button {
             button.image = NSImage(named: "Icon")
             button.action = #selector(togglePopover(_:))
        }
        
        // ⌘ + Control + B
        guard let keyCombo = KeyCombo(key: .b, cocoaModifiers: [.command, .control]) else { return }
        let hotKey = HotKey(identifier: "CommandControlB",
                            keyCombo: keyCombo,
                            target: self,
                            action: #selector(AppDelegate.tappedHotKey))
        hotKey.register()
    
    
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
         if let button = self.statusBarItem.button {
              if self.popover.isShown {
                   self.popover.performClose(sender)
              } else {
                   self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
                    self.popover.contentViewController?.view.window?.becomeKey()
              }
         }
    }
    
    @objc func tappedHotKey() {
        print("hotKey tapped")
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

