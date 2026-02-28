import SwiftUI
import UIKit

extension Color {
    init(hex: String) {
        self.init(uiColor: UIColor(hex: hex))
    }

    static func hex(_ hex: String) -> Color {
        Color(hex: hex)
    }
}

extension UIColor {
    convenience init(hex: String, alpha: CGFloat = 1) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleaned.hasPrefix("#") {
            cleaned.removeFirst()
        }

        var rgbValue: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgbValue)

        let r, g, b: CGFloat
        switch cleaned.count {
        case 6:
            r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255
            g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255
            b = CGFloat(rgbValue & 0x0000FF) / 255
        case 3:
            let rHex = (rgbValue & 0xF00) >> 8
            let gHex = (rgbValue & 0x0F0) >> 4
            let bHex = rgbValue & 0x00F
            r = CGFloat(rHex) / 15
            g = CGFloat(gHex) / 15
            b = CGFloat(bHex) / 15
        default:
            r = 1
            g = 1
            b = 1
        }

        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}
