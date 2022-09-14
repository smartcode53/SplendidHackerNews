//
//  SortOptionsView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/14/22.
//

import SwiftUI

struct SortOptionsView: View {
    
    @ObservedObject var vm: ContentViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            
            Color("CardColor")
                .ignoresSafeArea()
            
            RoundedRectangle(cornerRadius: 12)
                .fill(.orange)
                .frame(width: 100, height: 100)
                .rotationEffect(Angle(degrees: 120))
                .position(x: 20, y: 20)
            
            RoundedRectangle(cornerRadius: 12)
                .fill(.orange)
                .frame(width: 100, height: 100)
                .rotationEffect(Angle(degrees: 350))
                .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
            
            RoundedRectangle(cornerRadius: 12)
                .fill(.orange)
                .frame(width: 100, height: 100)
                .rotationEffect(Angle(degrees: 350))
                .position(x: 400, y: 200)
            
            VStack {
                
                Text("Sort By")
                    .font(.title2.weight(.bold))
                    .foregroundColor(Color("PostTitle"))
                
                HStack {
                    ForEach(SortOptions.allCases, id: \.self) { option in
                        
                        Button {
                            switch option {
                            case .time:
                                vm.sortByTime(array: vm.topStories, direction: .ascending)
                            case .comments:
                                vm.sortByNumberOfComments(array: vm.topStories, direction: .descending)
                            case .points:
                                vm.sortByPoints(array: vm.topStories, direction: .descending)
                            }
                            
                            dismiss()
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .frame(height: 80)
                                    
                                Text(option.rawValue)
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color("PostTitle"))
                                
                            }
                            .padding()
                        }
                    }
                }
            }
        }
    }
}

struct SortOptionsView_Previews: PreviewProvider {
    static var previews: some View {
        SortOptionsView(vm: ContentViewModel())
    }
}
