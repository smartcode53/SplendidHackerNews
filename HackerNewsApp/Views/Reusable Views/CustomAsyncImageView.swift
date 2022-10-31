//
//  CustomAsyncImageView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 10/26/22.
//

import SwiftUI

struct CustomAsyncImageView: View {

    
    @StateObject var imageViewModel: CustomAsyncImageViewModel
    let id: Int
    let sizeType: SizeTypes
    
    var body: some View {
        VStack {
            switch sizeType {
            case .compact:
                compactImage
            case .large:
                normalImage
            }
        }
        .task {
            await imageViewModel.loadImage()
        }
    }
}

extension CustomAsyncImageView {
    
    @ViewBuilder var compactImage: some View {
            if let cachedImage = imageViewModel.imageCacheManager.getFromCache(withKey: String(id)) {
                
                VStack {
                    cachedImage
                        .resizable()
                        .scaledToFill()
                        .layoutPriority(-1)
                }
                .frame(width: 100, height: 100)
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                .clipped()
            } else if imageViewModel.image != nil {
                VStack {
                    Image(uiImage: imageViewModel.image!)
                        .resizable()
                        .scaledToFill()
//                        .clipped()
                        .layoutPriority(-1)
                }
                .frame(width: 100, height: 100)
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                .onAppear {
                    imageViewModel.imageCacheManager.saveToCache(Image(uiImage: imageViewModel.image!), withKey: String(id))
                }
                .clipped()
            }
    }
    
    @ViewBuilder var normalImage: some View {
            if let cachedImage = imageViewModel.imageCacheManager.getFromCache(withKey: String(id)) {
                VStack {
                    GeometryReader { proxy in
                        cachedImage
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.frame(in: .local).width)
                            .clipped()
                    }
                }
                .frame(height: 270)
                .frame(maxWidth: .infinity)
                .clipped()
            } else if imageViewModel.image != nil {
                VStack {
                    GeometryReader { proxy in
                        Image(uiImage: imageViewModel.image!)
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.frame(in: .local).width)
                            .clipped()
                    }
                }
                .frame(height: 270)
                .frame(maxWidth: .infinity)
                .onAppear {
                    imageViewModel.imageCacheManager.saveToCache(Image(uiImage: imageViewModel.image!), withKey: String(id))
                }
                .clipped()
            }
    }
}

extension CustomAsyncImageView {
    
    init(url: String?, id: Int, sizeType: SizeTypes) {
        self._imageViewModel = StateObject(wrappedValue: CustomAsyncImageViewModel(url: url))
        self.id = id
        self.sizeType = sizeType
    }
    
}

struct CustomAsyncImageView_Previews: PreviewProvider {
    static var previews: some View {
        CustomAsyncImageView(url: "", id: 1, sizeType: .large)
    }
}
