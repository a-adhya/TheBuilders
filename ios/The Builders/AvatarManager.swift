//
//  AvatarManager.swift
//  TheBuilders
//
//  Observable object to manage avatar image state across the app
//

import SwiftUI
import UIKit
import Combine

class AvatarManager: ObservableObject {
    @Published var avatarImage: UIImage? //if UIimage changes, the object will be updated automatically
    
    func updateAvatar(_ image: UIImage?) {
        DispatchQueue.main.async { [weak self] in // weak self to avoid strong reference cycle
            self?.avatarImage = image
        } // in case the UIkit only updates the image on the main thread
    }
}

