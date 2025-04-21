import SwiftUI

struct SearchBarView: View {
    @Binding var isVisible: Bool
    @State private var searchText: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        GeometryReader { geometry in
            if isVisible {
                ZStack {
                    // Semi-transparent background
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.2)) {
                                isVisible = false
                            }
                        }
                    
                    // Search bar container
                    VStack(spacing: 0) {
                        // Search bar
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                                .font(.system(size: 20))
                            
                            TextField("Search", text: $searchText)
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(.system(size: 24))
                                .focused($isFocused)
                                .onSubmit {
                                    // Handle search submission
                                }
                                .onExitCommand { // This handles Escape key
                                    isVisible = false
                                }
                            
                            if !searchText.isEmpty {
                                Button(action: {
                                    searchText = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 16))
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.windowBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        
                        // Results container
                        if !searchText.isEmpty {
                            VStack {
                                Text("Search results will appear here")
                                    .foregroundColor(.secondary)
                            }
                            .frame(height: min(400, geometry.size.height * 0.6))
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.windowBackgroundColor))
                            )
                        }
                    }
                    .frame(width: min(600, geometry.size.width * 0.8))
                    .padding(.horizontal)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                .onAppear {
                    isFocused = true
                }
            }
        }
    }
}

// Preview provider for SwiftUI canvas
struct SearchBarView_Previews: PreviewProvider {
    static var previews: some View {
        SearchBarView(isVisible: .constant(true))
    }
} 