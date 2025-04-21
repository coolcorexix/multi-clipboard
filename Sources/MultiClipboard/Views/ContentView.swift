import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Text("Multi-Clipboard")
                .font(.title)
            Text("Press Cmd + Y to open search")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
} 