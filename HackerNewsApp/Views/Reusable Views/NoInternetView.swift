//
//  NoInternetView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 10/17/22.
//

import SwiftUI

struct NoInternetView: View {
    
    @ObservedObject var vm: FeedViewModel
    
    var body: some View {
        VStack {
            
            Spacer()
            
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 70))
                .padding(40)
                .background(.regularMaterial)
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                .padding(.bottom)
            
            Text("You're not connected to the Internet")
                .font(.title3.bold())
                .padding(.bottom)
            
            Button {
                Task {
                    vm.refreshStories()
                }
            } label: {
                Text("Retry")
                    .fontWeight(.bold)
                    .frame(width: 60)
                    .padding()
                    .foregroundColor(.white)
                    .background(Color("NavigationBarColor"))
                    .cornerRadius(12)
                
            }
            
            Spacer()
        }
    }
}

struct NoInternetView_Previews: PreviewProvider {
    static var previews: some View {
        NoInternetView(vm: FeedViewModel())
    }
}
