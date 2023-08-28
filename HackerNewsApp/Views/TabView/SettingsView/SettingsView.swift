//
//  SettingsView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/26/22.
//

import SwiftUI
import MessageUI

struct SettingsView: View {
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var globalSettings: GlobalSettingsViewModel
    @StateObject var vm = SettingsViewModel()
    @EnvironmentObject var nav: GlobalNavigator
    
    @Namespace var namespace
    
    var body: some View {
        NavigationStack(path: $nav.settingsRoutes) {
            ZStack {
                Color("SettingsBackgroundColor")
                    .ignoresSafeArea()
                    .zIndex(1)
                
                ScrollView {
                    if verticalSizeClass == .regular && horizontalSizeClass == .regular {
                        content
                            .frame(width: UIScreen.main.bounds.width * 0.7)
                    } else {
                        content
                    }
                    
                }
                .zIndex(2)
                
            }
            .navigationTitle("Settings")
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarLeading) {
                    Logo()
                        .frame(width: 30, height: 30)
                        .foregroundStyle(LinearGradient(colors: [.orange, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            })
        }
    }
}


extension SettingsView {
    
    private var content: some View {
        VStack {
            
            // Section 1
            firstSection
            
            // Section 2
            secondSection
            
            // Section 3
            thirdSection
        }
    }
    
    private var firstSection: some View {
        VStack() {
            
            // Section item 1
            if vm.showCardStylingOptions {
                feedStyleExpanded
            } else {
                feedStyleCollapsed
            }
            
            // Section item 2
            if vm.showThemeOptions {
                themeExpanded
            } else {
                themeCollapsed
            }
            
        }
        .padding(.top)
    }
    
    private var feedStyleCollapsed: some View {
        HStack {
            Label("Story Feed Card Style", systemImage: "platter.2.filled.iphone")
                .font(.headline)
            
            Spacer()
            
            Text(globalSettings.selectedCardStyle.rawValue)
                .foregroundColor(.orange)
                .matchedGeometryEffect(id: "cardStyleText", in: namespace)
        }
        .padding()
        .background(content: {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("CardColor"))
                .matchedGeometryEffect(id: "backgroundRect", in: namespace)
        })
        .padding(.horizontal, 10)
        .onTapGesture {
            withAnimation(.spring(response: 0.2)) {
                vm.showCardStylingOptions = true
            }
            
        }
    }
    
    private var feedStyleExpanded: some View {
        VStack {
            HStack {
                Label("Story Feed Card Style", systemImage: "platter.2.filled.iphone")
                    .font(.headline)
                
                Spacer()
                
                if !vm.showCardStylingOptions {
                    Text(globalSettings.selectedCardStyle.rawValue)
                        .foregroundColor(.orange)
                }
                
            }
            .onTapGesture {
                withAnimation(.spring(response: 0.2)) {
                    vm.showCardStylingOptions = false
                }
                
            }
            
            HStack {
                ForEach(Settings.CardStyle.allCases, id: \.self) { style in
                    Text(style.rawValue)
                        .font(.title3)
                        .foregroundColor(globalSettings.selectedCardStyle == style ? .white : .primary)
                        .padding()
                        .background(globalSettings.selectedCardStyle == style ?
                                    RoundedRectangle(cornerRadius: 12).fill(.orange).matchedGeometryEffect(id: "cardStyleText", in: namespace)
                                    :
                                        nil
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.2)) {
                                globalSettings.settings.cardStyleString = style.rawValue
                            }
                            
                        }
                }
            }
            
            HStack {
                Text("Done")
                    .foregroundColor(.orange)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Material.thinMaterial)
            .cornerRadius(12)
            .padding(.top)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    vm.showCardStylingOptions = false
                }
            }
            
        }
        .padding()
        .background(content: {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("CardColor"))
                .matchedGeometryEffect(id: "backgroundRect", in: namespace)
        })
        .padding(.horizontal, 10)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                vm.showCardStylingOptions = true
            }
            
        }
    }
    
    private var themeCollapsed: some View {
            HStack {
                Label("Theme", systemImage: "paintbrush.fill")
                    .font(.headline)
                
                Spacer()
                
                Text(globalSettings.selectedTheme.rawValue)
                    .foregroundColor(.orange)
                    .matchedGeometryEffect(id: "themeSelectorText", in: namespace)
            }
            .padding()
            .background(content: {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("CardColor"))
            })
            .padding(.horizontal, 10)
            .onTapGesture {
                withAnimation(.spring(response: 0.2)) {
                    vm.showThemeOptions = true
                }
            }
        
    }
    
    private var themeExpanded: some View {
            
        VStack {
            HStack {
                Label("Theme", systemImage: "paintbrush.fill")
                    .font(.headline)
                
                Spacer()
                
                if !vm.showThemeOptions {
                    Text(globalSettings.selectedTheme.rawValue)
                        .foregroundColor(.orange)
                }
            }
            .onTapGesture {
                withAnimation(.spring(response: 0.2)) {
                    vm.showThemeOptions = false
                }
            }
            
            HStack {
                
                ForEach(Settings.Theme.allCases, id: \.self) { theme in
                    VStack {
                        
                        switch theme {
                        case .automatic:
                            HStack(spacing: 2) {
                                Rectangle()
                                    .fill(.orange)
                                
                                Rectangle()
                                    .fill(Color(red: 7 / 255, green: 15 / 255, blue: 28 / 255))
                            }
                            .frame(height: 50)
                            .clipShape(Capsule())
                        case .light:
                            HStack(spacing: 2) {
                                Rectangle()
                                    .fill(.orange)
                            }
                            .frame(height: 50)
                            .clipShape(Capsule())
                        case .dark:
                            HStack(spacing: 2) {
                                Rectangle()
                                    .fill(Color(red: 7 / 255, green: 15 / 255, blue: 28 / 255))
                            }
                            .frame(height: 50)
                            .clipShape(Capsule())
                        }
                        
                        if globalSettings.selectedTheme == theme {
                            Text(theme.rawValue)
                                .font(.headline.weight(.medium))
                                .matchedGeometryEffect(id: "themeSelectorText", in: namespace)
                        } else {
                            Text(theme.rawValue)
                                .font(.headline.weight(.medium))
                        }
                        
                        
                        if globalSettings.selectedTheme == theme {
                            Image(systemName: "triangle.fill")
                                .matchedGeometryEffect(id: "themeSelector", in: namespace)
                                .foregroundColor(.green)
                                .padding(.top, 20)
                        }
                    }
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            globalSettings.settings.themeString = theme.rawValue
                        }
                    }
                }
            }
            .padding(.vertical)
            
            HStack {
                Text("Done")
                    .foregroundColor(.orange)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Material.thinMaterial)
            .cornerRadius(12)
            .padding(.top)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    vm.showThemeOptions = false
                }
            }
            
        }
        .padding()
        .background(content: {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("CardColor"))
        })
        .padding(.horizontal, 10)
        
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
                .onTapGesture {
                    globalSettings.writeReview()
                }
            }
            .padding(.horizontal, 10)
            
            if MFMailComposeViewController.canSendMail() {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color("CardColor"))
                    
                    HStack {
                        Label("Tell the developer about bugs or give feedback", systemImage: "exclamationmark.bubble.fill")
                            .font(.headline)
                        
                        Spacer()
                        
                    }
                    .padding()
                }
                .padding(.horizontal, 10)
                .onTapGesture {
                    vm.sendEmail = true
                }
                .sheet(isPresented: $vm.sendEmail) {
                    MailView()
                }
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color("CardColor"))
                    
                    HStack {
                        VStack(spacing: 30) {
                            Label("Tell the developer about bugs or give feedback", systemImage: "exclamationmark.bubble.fill")
                                .font(.headline)
                            
                            Text("Please set a Mail account on your device in order to leave feedback")
                                .foregroundColor(.red.opacity(0.7))
                                .font(.caption)
                            
                        }
                        
                        Spacer()
                        
                    }
                    .padding()
                }
                .padding(.horizontal, 10)
            }
            
            
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
            devTwitterHandle
            
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
    
    @ViewBuilder private var devTwitterHandle: some View {
        
        if let twitterURL = URL(string: "https://twitter.com/TahaBroach") {
            Link(destination: twitterURL) {
                ZStack {
                    
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color("CardColor"))
                    
                    HStack {
                        Label("Developer", systemImage: "person.fill")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("@tahabroach")
                            .foregroundColor(.mint)
                    }
                    .padding()
                }
                .padding(.horizontal, 10)
            }
        } else {
            ZStack {
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("CardColor"))
                
                HStack {
                    Label("Developer", systemImage: "person.fill")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("@tahabroach")
                        .foregroundColor(.mint)
                }
                .padding()
            }
            .padding(.horizontal, 10)
        }
    }
    
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
