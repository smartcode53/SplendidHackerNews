//
//  SettingsView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/26/22.
//

import SwiftUI

struct SettingsView: View {
    
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var globalSettings: GlobalSettingsViewModel
    @StateObject var vm = SettingsViewModel()
    
    @Namespace var namespace
    
    var body: some View {
        ZStack {
            Color("BackgroundColor")
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

                    #if DEBUG
                    debugSection
                    #endif
                }
            }
            .zIndex(2)
            
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

            readerSection
            
        }
    }
    
    private var feedStyleCollapsed: some View {
        HStack {
            Label("Story Feed Card Style", systemImage: "platter.2.filled.iphone")
                .font(.headline)
            
            Spacer()
            
            Text(globalSettings.selectedCardStyle.rawValue)
                .foregroundColor(.accentColor)
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
                        .foregroundColor(.accentColor)
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
                                    RoundedRectangle(cornerRadius: 12).fill(Color.accentColor).matchedGeometryEffect(id: "cardStyleText", in: namespace)
                                    :
                                        nil
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.2)) {
                                globalSettings.settings.cardStyleString = style.rawValue
                            }
                            
                            withAnimation(.spring().delay(1)) {
                                vm.showCardStylingOptions = false
                            }
                            
                        }
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
                    .foregroundColor(.accentColor)
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
                        .foregroundColor(.accentColor)
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
                                    .fill(Color.accentColor)
                                
                                Rectangle()
                                    .fill(Color(red: 7 / 255, green: 15 / 255, blue: 28 / 255))
                            }
                            .frame(height: 50)
                            .clipShape(Capsule())
                        case .light:
                            HStack(spacing: 2) {
                                Rectangle()
                                    .fill(Color.accentColor)
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
                                .foregroundColor(.accentColor)
                                .padding(.top, 20)
                        }
                    }
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            globalSettings.settings.themeString = theme.rawValue
                        }
                        
                        withAnimation(.spring(response: 0.2).delay(1)) {
                            vm.showThemeOptions = false
                        }
                    }
                }
            }
            .padding(.vertical)
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
            }
            .padding(.horizontal, 10)
            
            // Section item 2
//            if let mailUrl = vm.mailUrl {
//                Link(destination: mailUrl) {
//
//                }
//            }
            
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
            .onTapGesture {
                vm.openMail()
            }
            
        }
        .padding(.top, 30)
    }

    private var readerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Reader", systemImage: "text.book.closed")
                .font(.headline)

            Toggle("Open articles in Reader", isOn: $globalSettings.settings.openInReader)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Font Size")
                    Spacer()
                    Text("\(globalSettings.settings.readerFontScale, specifier: "%.2f")")
                        .foregroundColor(.secondary)
                }
                Slider(value: $globalSettings.settings.readerFontScale, in: 0.9...1.4, step: 0.05)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Line Spacing")
                    Spacer()
                    Text("\(globalSettings.settings.readerLineSpacing, specifier: "%.0f")")
                        .foregroundColor(.secondary)
                }
                Slider(value: $globalSettings.settings.readerLineSpacing, in: 1...10, step: 1)
            }
        }
        .padding()
        .background(content: {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("CardColor"))
        })
        .padding(.horizontal, 10)
        .padding(.top, 10)
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

    #if DEBUG
    private var debugSection: some View {
        VStack() {
            HStack {
                Text("Debug")
                    .font(.title3.weight(.semibold))
                Spacer()
            }
            .padding(.horizontal)

            NavigationLink(value: AppRoute.hnAccount) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color("CardColor"))

                    HStack {
                        Label("HN Account", systemImage: "person.badge.key")
                            .font(.headline)
                        Spacer()
                    }
                    .padding()
                }
                .padding(.horizontal, 10)
            }

            NavigationLink(value: AppRoute.hnDiagnostics) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color("CardColor"))

                    HStack {
                        Label("HN Diagnostics", systemImage: "stethoscope")
                            .font(.headline)
                        Spacer()
                    }
                    .padding()
                }
                .padding(.horizontal, 10)
            }

            NavigationLink(value: AppRoute.readerPreview) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color("CardColor"))

                    HStack {
                        Label("Reader Preview", systemImage: "text.book.closed")
                            .font(.headline)
                        Spacer()
                    }
                    .padding()
                }
                .padding(.horizontal, 10)
            }
        }
        .padding(.top, 30)
    }
    #endif
    
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
