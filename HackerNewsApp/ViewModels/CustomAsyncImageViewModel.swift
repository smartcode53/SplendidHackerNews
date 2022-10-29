//
//  CustomAsyncImageViewModel.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 10/26/22.
//

import Foundation
import SwiftUI

class CustomAsyncImageViewModel: ObservableObject {
    
    let url: String?
    
    @Published var image: UIImage? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    lazy var imageCacheManager: UltimatePostViewModel.ImageCache = .instance
    lazy var networkManager: NetworkManager = .instance
    
    init(url: String?) {
        self.url = url
    }
    
    func loadImage() async {
        
        guard image == nil else {
            return
        }
        guard let url = self.url, let usableUrl = await networkManager.getImage(fromUrl: url) else {
            return
        }
        
//        await MainActor.run { [weak self] in
//            self?.isLoading = true
//            self?.errorMessage = nil
//        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: usableUrl)
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                await MainActor.run { [weak self] in
                    self?.errorMessage = "There was HTTP error with status code: \(httpResponse.statusCode)"
                }
                return
            }
            await MainActor.run { [weak self] in
//                self?.isLoading = false
                self?.image = UIImage(data: data)
            }
        } catch let error {
            print("There was an error loading the image. Here's the error description: \(error.localizedDescription)")
        }
        
    }
    
}
