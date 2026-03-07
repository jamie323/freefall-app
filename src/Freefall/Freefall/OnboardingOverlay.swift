import SwiftUI

struct OnboardingOverlay: View {
    let world: WorldDefinition
    let onDismiss: () -> Void

    @State private var currentStep = 0
    @State private var stepScale: CGFloat = 0.8
    @State private var stepOpacity: CGFloat = 0

    private let steps: [(icon: String, title: String, body: String)] = [
        ("hand.tap.fill", "TAP TO FLIP", "Tap anywhere to flip gravity.\nTime your flips to dodge obstacles."),
        ("diamond.fill", "COLLECT DIAMONDS", "Grab every diamond for Rank S.\nCombos multiply your score."),
        ("star.fill", "CHASE 3 STARS", "Score 550+ for three stars.\nCollect all diamonds to unlock Rank S.")
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                if currentStep < steps.count {
                    let step = steps[currentStep]

                    VStack(spacing: 16) {
                        Image(systemName: step.icon)
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(world.primaryColor)
                            .shadow(color: world.primaryColor.opacity(0.6), radius: 12)

                        Text(step.title)
                            .font(.system(size: 32, weight: .black, design: .default))
                            .foregroundStyle(.white)

                        Text(step.body)
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .scaleEffect(stepScale)
                    .opacity(stepOpacity)
                }

                Spacer()

                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { i in
                        Circle()
                            .fill(i == currentStep ? world.primaryColor : .white.opacity(0.2))
                            .frame(width: 8, height: 8)
                    }
                }

                Button(action: advanceOrDismiss) {
                    Text(currentStep < steps.count - 1 ? "NEXT" : "LET'S GO")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(world.primaryColor)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(world.primaryColor, lineWidth: 2)
                        )
                }
                .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            animateStepIn()
        }
    }

    private func advanceOrDismiss() {
        if currentStep < steps.count - 1 {
            withAnimation(.easeOut(duration: 0.15)) {
                stepOpacity = 0
                stepScale = 0.8
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                currentStep += 1
                animateStepIn()
            }
        } else {
            onDismiss()
        }
    }

    private func animateStepIn() {
        stepScale = 0.8
        stepOpacity = 0
        withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
            stepScale = 1.0
            stepOpacity = 1.0
        }
    }
}
