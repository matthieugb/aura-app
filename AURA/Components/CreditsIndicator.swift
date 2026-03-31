import SwiftUI

struct CreditsIndicator: View {
    @EnvironmentObject private var credits: CreditsService

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "circle.hexagongrid.fill")
                .font(.system(size: 12))
            Text("\(credits.balance)")
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundColor(Color(hex: "C4894A"))
        .frame(minWidth: 44)
    }
}
