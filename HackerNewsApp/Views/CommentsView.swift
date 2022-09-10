//
//  CommentsView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/26/22.
//

import SwiftUI

struct CommentsView: View {
    
    @Environment(\.dismiss) var dismiss
    @StateObject var vm = CommentsViewModel()
    @GestureState var dragOffset = CGSize.zero
    
    
    // MARK: Bindings
    @Binding var numComments: Int?
    @Binding var points: Int
    
    
    let story: Story
    let urlDomain: String?
    let storyDate: Int
    let title: String
    let author: String?
    let id: Int
    let url: String?
    
    var body: some View {
        
        VStack(spacing: 0) {
            
            // Navigation Back Button
            HStack {
                
                Image(systemName: "arrow.left")
                    .font(.title.weight(.semibold))
                    .foregroundColor(.primary)
                    .onTapGesture {
                        dismiss()
                    }
                
                Spacer()
            }
            .padding(.bottom, 30)
            .padding(.leading, 10)
            .background(Color("CardColor"))
            
            ScrollView {
                // Top section (Info Card with back navigation button)
                VStack {
                    
                    // Domain, Title, and meta info
                    VStack(alignment: .leading, spacing: 0) {
                        if let urlDomain {
                            Text(urlDomain)
                                .foregroundColor(Color("PostDateName"))
                                .font(.headline)
                                .padding(.bottom, 5)
                        }
                        
                        Text(url == nil ? "\(title)" : "\(title) \(Image(systemName: "arrow.up.forward.app"))")
                            .font(.title2.weight(.bold))
                            .padding(.bottom, 12)
                            .foregroundColor(Color("PostTitle"))
                            .onTapGesture {
                                vm.showStoryInComments = true
                            }
                        
                        HStack {
                            Text(Date.getTimeInterval(with: storyDate))
                            
                            Text("|")
                                .foregroundColor(Color("DateNameSeparator"))
                            
                            if let author { Text(author) }
                            
                            Spacer()
                        }
                        .foregroundColor(Color("PostDateName"))
                        .font(.subheadline)
                    }
                    .padding(.bottom, 35)
                    .padding(.horizontal)
                    
                    Rectangle()
                        .fill(.orange.opacity(0.21))
                        .frame(height: 2)
                    
                    // Points and Action Button
                    HStack {
                        Text(points == 1 ? "\(points) point" : "\(points) points")
                            .foregroundColor(.orange)
                            .font(.headline)
                        
                        Spacer()
                        
                        if let storyUrl = url {
                            ShareLink(item: storyUrl) {
                                Image(systemName: "square.and.arrow.up.fill")
                            }
                            .createPressableButton()
                        }
                        
                        
                    }
                    .padding()
                    
                    Rectangle()
                        .frame(height: 2)
                        .foregroundColor(.primary)
                }
                .background(Color("CardColor"))
                
                // Comment count
                HStack {
                    Text("\(numComments ?? 0) comments")
                        .padding()
                        .font(.title2.weight(.bold))
                    
                    Spacer()
                }
                
                VStack {
                    if let comments = vm.item?.children {
                        LazyVStack {
                            ForEach(comments) { comment in
                                if let _ = comment.text {
                                    SingleCommentView(comment: comment)
                                }
                            }
                        }
                    } else {
                        ProgressView()
                    }
                }
                .background(Color("BackgroundColor"))
                .onAppear {
                    vm.loadComments(forId: id)
                }
                .task {
                    if let (numComments, points) = await vm.getCommentAndPointCounts(forPostId: id) {
                        self.numComments = numComments
                        self.points = points
                    }
                }
                
                Spacer()
            }
            
            
            
        }
        .background(Color("BackgroundColor"))
        .fullScreenCover(isPresented: $vm.showStoryInComments) {
            SafariView(vm: vm, url: url)
        }
        .toolbar(.hidden, for: .navigationBar)
        .gesture(DragGesture().updating($dragOffset, body: { value, state, transaction in
            if value.startLocation.x < 20 && value.translation.width > 100 {
                dismiss()
            }
        }))
    }
}
        
extension CommentsView {
            
            var backButton: some View {
                HStack {
                    Image(systemName: "arrow.backward")
                        .font(.title.weight(.semibold))
                        .onTapGesture {
                            dismiss()
                        }
                    
                    Spacer()
                }
                .padding([.horizontal, .bottom])
            }
            
            var titlePalate: some View {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(Date.getTimeInterval(with: storyDate))
                            .font(.headline)
                            .foregroundColor(.black.opacity(0.5))
                        
                        Text(title)
                            .font(.title2.weight(.bold))
                        
                        if let urlDomain {
                            Text(urlDomain)
                                .font(.headline)
                                .foregroundColor(.black.opacity(0.5))
                        }
                        
                        
                    }
                    
                    Spacer()
                    
                    Image(systemName: "globe.europe.africa.fill")
                        .font(.title.weight(.bold))
                        .foregroundColor(.black)
                }
                .padding()
                .background(.white)
                .cornerRadius(12)
                .padding(.horizontal)
                .shadow(radius: 4)
                .padding(.bottom)
                .onTapGesture {
                    vm.showStoryInComments = true
                }
            }
            
            var metaInfoPalate: some View {
                HStack {
                    if let author {
                        Label(author, systemImage: "person.fill")
                    }
                    
                    Spacer()
                    
                    Text(points == 1 ? "\(points) Point" : "\(points) points")
                    
                    Spacer()
                    
                    Text(numComments == 1 ? "\(numComments ?? 0) comment" : "\(numComments ?? 0) comments")
                }
                .padding()
                .background(.black)
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding(.horizontal)
                .shadow(radius: 4)
            }
            
            init(story: Story, numComments: Binding<Int?>, points: Binding<Int>, urlDomain: String?) {
                self.story = story
                self._numComments = Binding(projectedValue: numComments)
                self._points = Binding(projectedValue: points)
                self.urlDomain = urlDomain
                self.storyDate = story.time
                self.title = story.title
                self.author = story.by
                self.id = story.id
                self.url = story.url
            }
            
        }


//struct CommentsView_Previews: PreviewProvider {
//    static var previews: some View {
//        CommentsView(numComments: .constant(20), points: .constant(25), story: <#T##Story#>, urlDomain: <#T##String?#>, storyDate: <#T##Int#>, title: <#T##String#>, author: <#T##String#>, id: <#T##String#>, url: <#T##String?#>)
//    }
//}


