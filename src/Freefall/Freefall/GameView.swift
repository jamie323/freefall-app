import SwiftUI

struct GameView: View {
    @Environment(GameState.self) private var gameState

    let world: WorldDefinition
    let level: LevelDefinition
    let onQuit: () -> Void

    @State private var proxy = SceneProxy()
    @State private var debugLines: [String] = []
    @State private var tapCount = 0
    @State private var debugTimer: Timer?

    var body: some View {
        ZStack {
            SpriteKitView(level: level, world: world, proxy: proxy)
                .ignoresSafeArea()

            // Full-screen tap target — Color.clear needs contentShape to receive taps
            // Use opacity(0.001) as belt-and-braces: guarantees hit testing works
            Color.white.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture {
                    tapCount += 1
                    proxy.handleTap()
                }

            // HUD — level label
            Text("L\(level.levelId)")
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.leading, 16)
                .padding(.top, 16)
                .allowsHitTesting(false)

            // Pause button
            Button(action: { }) {
                Image(systemName: "pause.circle")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.trailing, 4)
            .padding(.top, 8)

            // ── DEBUG OVERLAY ──────────────────────────────────────
            VStack(alignment: .leading, spacing: 2) {
                ForEach(debugLines, id: \.self) { line in
                    Text(line)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.yellow)
                }
            }
            .padding(8)
            .background(Color.black.opacity(0.7))
            .cornerRadius(6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.bottom, 40)
            .padding(.leading, 8)
            .allowsHitTesting(false)
            // ── END DEBUG ──────────────────────────────────────────
        }
        .navigationBarBackButtonHidden(true)
        .onAppear { startDebugTimer() }
        .onDisappear { debugTimer?.invalidate() }
    }

    private func startDebugTimer() {
        debugTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            refreshDebug()
        }
    }

    private func refreshDebug() {
        guard let scene = proxy.coordinator?.scene else {
            debugLines = ["proxy=NIL — tap not wired!"]
            return
        }
        let sphere = scene.sphereNode
        let pos = sphere?.position ?? .zero
        let vel = sphere?.physicsBody?.velocity ?? .zero
        let isDyn = sphere?.physicsBody?.isDynamic ?? false
        let grav = scene.physicsWorld.gravity
        let state = scene.sceneState.rawValue
        let sz = scene.size

        let flips = scene.flipCount
        debugLines = [
            "TAPS:\(tapCount) FLIPS:\(flips) STATE:\(state)",
            "POS x:\(Int(pos.x)) y:\(Int(pos.y))",
            "VEL dx:\(Int(vel.dx)) dy:\(Int(vel.dy))",
            "GRAV dy:\(Int(grav.dy)) DYN:\(isDyn ? "Y" : "N")",
            "SCENE \(Int(sz.width))x\(Int(sz.height))",
            "PROXY:\(proxy.coordinator == nil ? "NIL" : "OK")",
        ]
    }
}
