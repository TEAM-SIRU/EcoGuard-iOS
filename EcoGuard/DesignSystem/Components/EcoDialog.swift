import SwiftUI

/// Figma `Dialog` (309:161). 화면 가운데 확인 팝업. 제목(title3) + 설명(body2) + 가로 버튼 두 개.
/// 탭 바까지 덮어야 해서 띄울 때는 `.ecoDialog(isPresented:onCancel:)`를 쓴다.
struct EcoDialog<Buttons: View>: View {
    private let title: LocalizedStringKey
    private let message: LocalizedStringKey
    private let buttons: Buttons

    init(_ title: LocalizedStringKey, message: LocalizedStringKey, @ViewBuilder buttons: () -> Buttons) {
        self.title = title
        self.message = message
        self.buttons = buttons()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .ecoFont(.title3)
                .foregroundStyle(Color.ecoTextPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .ecoFont(.body2)
                .foregroundStyle(Color.ecoTextSub)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Spacing.sm) {
                buttons
            }
            .padding(.top, Spacing.lg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.xxl)
        .padding(.top, Metrics.topPadding)
        .padding(.bottom, Spacing.xl)
        .background(Color.ecoCard, in: RoundedRectangle(cornerRadius: Radius.card))
    }
}

extension View {
    /// 화면 전체(탭 바 포함)를 `Dim`으로 덮고 가운데에 `dialog`를 띄운다.
    /// 바깥을 눌러도 닫지 않는다. VoiceOver 닫기 동작(두 손가락 문지르기)은 `onCancel`을 부른다.
    /// `onDismiss`는 팝업이 화면에서 다 내려간 뒤 불린다.
    func ecoDialog<Dialog: View>(
        isPresented: Binding<Bool>,
        onCancel: @escaping () -> Void,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder dialog: @escaping () -> Dialog
    ) -> some View {
        modifier(EcoDialogModifier(isPresented: isPresented, onCancel: onCancel, onDismiss: onDismiss, dialog: dialog))
    }
}

private struct EcoDialogModifier<Dialog: View>: ViewModifier {
    @Binding var isPresented: Bool
    let onCancel: () -> Void
    let onDismiss: (() -> Void)?
    let dialog: () -> Dialog

    func body(content: Content) -> some View {
        content
            // fullScreenCover의 아래에서 올라오는 전환 대신 Dim이 스스로 나타나게 한다.
            .transaction(value: isPresented) { $0.disablesAnimations = true }
            .fullScreenCover(isPresented: $isPresented, onDismiss: onDismiss) {
                EcoDialogContainer(onCancel: onCancel, dialog: dialog)
                    .presentationBackground(.clear)
            }
    }
}

private struct EcoDialogContainer<Dialog: View>: View {
    let onCancel: () -> Void
    let dialog: () -> Dialog

    @State private var isVisible = false

    var body: some View {
        ZStack {
            Color.ecoDim
                .ignoresSafeArea()
                .accessibilityHidden(true)
            dialog()
                .padding(.horizontal, Spacing.screenHorizontal)
                .accessibilityAddTraits(.isModal)
                .accessibilityAction(.escape, onCancel)
        }
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: Metrics.appearDuration)) {
                isVisible = true
            }
        }
    }
}

private enum Metrics {
    /// Figma 위 여백 28. Foundations 간격 스케일 밖이다.
    static let topPadding: CGFloat = 28
    static let appearDuration: Double = 0.2
}

#Preview {
    Color.ecoCard
        .ecoDialog(isPresented: .constant(true), onCancel: {}) {
            EcoDialog("로그아웃할까요?", message: "다시 들어오려면 DataGSM으로 로그인해야 해요") {
                EcoButton("취소", style: .secondary) {}
                EcoButton("로그아웃", style: .destructive) {}
            }
        }
}
