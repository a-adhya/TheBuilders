//
//  swiftUIChatterApp.swift
//  swiftUIChatter
//
//  Created by Karthik Jonnalagadda on 10/7/25.
//

import SwiftUI
import Observation

@Observable
final class ChattViewModel {
    let appID = Bundle.main.bundleIdentifier
    let model = "tinyllama"
    let username = "tinyllama" // instead of uniqname
    let instruction = "Type a message…"

    var message = "What's the weather in this location?"
    var errMsg = ""
    var showError = false
}

@main
struct swiftUIChatterApp: App {
    let viewModel = ChattViewModel()
    init() {
        LocManager.shared.startUpdates()
    }
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView()
                    .onAppear {
                        let scenes = UIApplication.shared.connectedScenes
                        let windowScene = scenes.first as? UIWindowScene
                        
                        if let wnd = windowScene?.windows.first {
                            let lagFreeField = UITextField()
                            
                            wnd.addSubview(lagFreeField)
                            lagFreeField.becomeFirstResponder()
                            lagFreeField.resignFirstResponder()
                            lagFreeField.removeFromSuperview()
                        }
                    }
            }
            .environment(viewModel)
        }
    }
}
