import CoreGraphics

/// Figma Foundations 간격 스케일 4 · 8 · 12 · 16 · 20 · 24.
enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    /// Foundations 스케일 밖. Figma `01 로그인 · 교사 계정 안내` (309:42) 하단 패딩 실측값 32.
    static let xxxl: CGFloat = 32

    /// 화면 좌우 여백.
    static let screenHorizontal: CGFloat = 24
}
