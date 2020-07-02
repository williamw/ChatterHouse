//
//  ContentView.swift
//  ChatterHouse
//
//  Created by Bill Welense on 6/28/20.
//  Copyright © 2020 Bill Welense. All rights reserved.
//

import SwiftUI
import MultipeerKit
import Combine

final class ViewModel: ObservableObject {
    @Published var message: String = "Press ⌘+control+B to test"
}

struct ContentView: View {
    @ObservedObject private(set) var viewModel = ViewModel()
    @EnvironmentObject var dataSource: MultipeerDataSource
    
    var body: some View {
        Text(viewModel.message)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
