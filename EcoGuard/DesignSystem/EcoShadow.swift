import SwiftUI

/// Figma Redesign 2 그림자. 색은 alpha가 들어간 colorset이다.
enum EcoShadow {
    /// 흰 카드 2단 그림자. `.ecoShadow(.card)`는 두 겹을 함께 건다. 0 / 1 / 3 grey/900 4% + 0 / 6 / 18 grey/900 7%.
    case card
    /// 하단 탭 바 (823:969). 0 / -4 / 16, grey/900 5%.
    case tabBar
    /// 가운데 카메라 버튼 (823:969 Camera FAB). 0 / 6 / 14, green/500 32%.
    case cameraButton

    fileprivate var layers: [Layer] {
        switch self {
        case .card:
            [Layer(color: .ecoShadowCardNear, blur: 3, offsetY: 1), Layer(color: .ecoShadowCard, blur: 18, offsetY: 6)]
        case .tabBar:
            [Layer(color: .ecoShadowTabBar, blur: 16, offsetY: -4)]
        case .cameraButton:
            [Layer(color: .ecoShadowCameraButton, blur: 14, offsetY: 6)]
        }
    }

    fileprivate struct Layer {
        let color: Color
        /// Figma blur. SwiftUI `radius`는 blur의 절반이다.
        let blur: CGFloat
        let offsetY: CGFloat
    }
}

extension View {
    func ecoShadow(_ shadow: EcoShadow) -> some View {
        let first = shadow.layers[0]
        // 한 겹짜리는 두 번째 그림자를 투명으로 둔다.
        let second = shadow.layers.dropFirst().first ?? EcoShadow.Layer(color: .clear, blur: 0, offsetY: 0)
        return self
            .shadow(color: first.color, radius: first.blur / 2, x: 0, y: first.offsetY)
            .shadow(color: second.color, radius: second.blur / 2, x: 0, y: second.offsetY)
    }

    /// Figma 흰 카드 배경: 흰색 + 1px grey/200 테두리 + 2단 그림자.
    /// 그림자를 배경 도형에만 줘야 안쪽 글자·버튼에 그림자가 번지지 않는다.
    func ecoCardBackground(cornerRadius: CGFloat) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.ecoCard)
                .ecoShadow(.card)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(Color.ecoBorder, lineWidth: 1)
                }
        }
    }
}
