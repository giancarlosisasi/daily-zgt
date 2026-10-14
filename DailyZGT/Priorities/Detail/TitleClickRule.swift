import CoreGraphics

enum TitleClickRule {
    static let movementTolerance: CGFloat = 3

    static func shouldOpen(down: CGPoint, up: CGPoint, selectionLength: Int) -> Bool {
        guard selectionLength == 0 else { return false }
        return abs(up.x - down.x) <= movementTolerance && abs(up.y - down.y) <= movementTolerance
    }
}
