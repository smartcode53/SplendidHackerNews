//
//  CustomAsyncImageView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 10/26/22.
//

import SwiftUI

struct CustomAsyncImageView: View {
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @StateObject var imageViewModel: CustomAsyncImageViewModel
    let id: Int
    let width: CGFloat
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
                cachedImage
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipped()
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
            } else if imageViewModel.image != nil {
                Image(uiImage: imageViewModel.image!)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipped()
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                    .onAppear {
                        imageViewModel.imageCacheManager.saveToCache(Image(uiImage: imageViewModel.image!), withKey: String(id))
                    }
            }
    }
    
    @ViewBuilder var normalImage: some View {
            if let cachedImage = imageViewModel.imageCacheManager.getFromCache(withKey: String(id)) {
                cachedImage
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: 270)
                    .clipped()
            } else if imageViewModel.image != nil {
                Image(uiImage: imageViewModel.image!)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: 270)
                    .clipped()
                    .onAppear {
                        imageViewModel.imageCacheManager.saveToCache(Image(uiImage: imageViewModel.image!), withKey: String(id))
                    }
            }
    }
}

extension CustomAsyncImageView {
    
    init(url: String?, id: Int, width: CGFloat, sizeType: SizeTypes) {
        self._imageViewModel = StateObject(wrappedValue: CustomAsyncImageViewModel(url: url))
        self.width = width
        self.id = id
        self.sizeType = sizeType
    }
    
}

struct CustomAsyncImageView_Previews: PreviewProvider {
    static var previews: some View {
        CustomAsyncImageView(url: "", id: 1, width: 200, sizeType: .large)
    }
}
