//
//  SettingsView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/26/22.
//

import SwiftUI

struct SettingsView: View {
    
    @EnvironmentObject var globalSettings: GlobalSettingsViewModel
    @StateObject var vm = SettingsViewModel()
    
    @Namespace var namespace
    
    var body: some View {
        ZStack {
            Color.gray.opacity(0.2)
                .ignoresSafeArea()
                .zIndex(1)
            
            ScrollView {
                VStack {
                    
                    // Section 1
                    firstSection
                    
                    // Section 2
                    secondSection
                    
                    // Section 3
                    thirdSection
                }
            }
            .zIndex(2)
            
            if vm.showCardStylingOptions {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color("CardColor"))
                        .matchedGeometryEffect(id: "cardStyle", in: namespace)
                        .frame(width: 200, height: 200)
                }
                .zIndex(3)
            }
            
        }
    }
}


extension SettingsView {
    
    private var firstSection: some View {
        VStack() {
            
            // Section Label
            HStack {
                Text("Settings")
                    .font(.title.weight(.semibold))
                Spacer()
            }
            .padding(.horizontal)
            
            // Section item 1
            ZStack {
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("CardColor"))
                
                HStack {
                    Label("Story Feed Card Style", systemImage: "platter.2.filled.iphone")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(globalSettings.selectedCardStyle.rawValue)
                        .foregroundColor(.orange)
                }
                .padding()
            }
            .matchedGeometryEffect(id: "cardStyle", in: namespace)
            .padding(.horizontal, 10)
            .onTapGesture {
                withAnimation(.easeInOut) {
                    vm.showCardStylingOptions = true
                }
                
            }
            
            // Section item 2
            
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("CardColor"))
                
                HStack {
                    Label("Theme", systemImage: "paintbrush.fill")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(globalSettings.selectedTheme.rawValue)
                        .foregroundColor(.orange)
                }
                .padding()
            }
            .padding(.horizontal, 10)
        }
    }
    
    private var secondSection: some View {
        VStack() {
            
            // Section Label
            HStack {
                Text("Feedback")
                    .font(.title3.weight(.semibold))
                Spacer()
            }
            .padding(.horizontal)
            
            // Section item 1
            ZStack {
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("CardColor"))
                
                HStack {
                    Label("Rate and Review the app", systemImage: "star.bubble.fill")
                        .font(.headline)
                    
                    Spacer()
                    
                }
                .padding()
            }
            .padding(.horizontal, 10)
            
            // Section item 2
            
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("CardColor"))
                
                HStack {
                    Label("Report an issue", systemImage: "exclamationmark.bubble.fill")
                        .font(.headline)
                    
                    Spacer()
                    
                }
                .padding()
            }
            .padding(.horizontal, 10)
        }
        .padding(.top, 30)
    }
    
    private var thirdSection: some View {
        VStack() {
            
            // Section Label
            HStack {
                Text("About this app")
                    .font(.title3.weight(.semibold))
                Spacer()
            }
            .padding(.horizontal)
            
            // Section item 1
            ZStack {
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("CardColor"))
                
                HStack {
                    Label("Developer", systemImage: "person.fill")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("@tahabroach")
                        .foregroundColor(.mint)
                }
                .padding()
            }
            .padding(.horizontal, 10)
            
            // Section item 2
            
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("CardColor"))
                
                HStack {
                    Label("App Version", systemImage: "number.circle.fill")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("1.0")
                        .foregroundColor(.mint)
                }
                .padding()
            }
            .padding(.horizontal, 10)
        }
        .padding(.top, 30)
    }
    
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
