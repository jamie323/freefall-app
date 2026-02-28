import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("Freefall")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(Color.cyan)
        }
    }
}

#Preview {
    ContentView()
}
