import SwiftUI

struct TypeBadge: View {
    let category: TypeCategory

    var body: some View {
        Text(category.label)
            .font(Design.badgeFont)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Design.badgeColor(for: category).opacity(0.18))
            .foregroundColor(Design.badgeColor(for: category))
            .clipShape(Capsule())
    }
}
