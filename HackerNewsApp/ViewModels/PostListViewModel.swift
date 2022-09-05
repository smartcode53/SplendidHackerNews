//
//  PostListViewModel.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/5/22.
//

import Foundation

class PostListViewModel: ObservableObject {
    
    let networkManager = NetworkManager.instance
    
    @Published var urlDomain: String?
    @Published var imageUrl: URL?
    
    func loadUrlDomain(forUrl url: String) {
        urlDomain = networkManager.getUrlDomain(forUrl: url)
    }
    
    func loadImage(fromUrl url: String) {
        Task {
            let resultUrl = await networkManager.getImage(fromUrl: url)
            await MainActor.run { [weak self] in
                self?.imageUrl = resultUrl
            }
        }
    }
    
}
