import SwiftUI

/// Figma `01 로그인 · 기본` (238:122) · `로딩` (238:141) · `실패` (238:162).
struct LoginView: View {
    let viewModel: LoginViewModel

    var body: some View {
        GeometryReader { proxy in
            // Spacer는 VStack 안에서 폭이 0이라 토스트를 얹을 수 없다. 위아래 여백을 같은 Color.clear로 나눠 가운데 정렬한다.
            VStack(spacing: 0) {
                Color.clear
                VStack(spacing: 0) {
                    header
                    BottomCTA(caption: "학교 계정으로만 로그인할 수 있어요") {
                        loginButton
                    }
                    // Figma는 CTA 아래 홈 인디케이터 영역까지 한 덩어리로 세로 가운데 정렬한다.
                    .padding(.bottom, proxy.safeAreaInsets.bottom)
                }
                Color.clear
                    .overlay(alignment: .top) {
                        if viewModel.state == .failed {
                            EcoToast(message: "로그인하지 못했어요. 다시 시도해 주세요")
                                .padding(.top, Spacing.sm)
                                .padding(.horizontal, Spacing.screenHorizontal)
                        }
                    }
            }
        }
        // 입력란이 없는 화면이다. dataGSM 로그인 창에서 올린 키보드에 밀려 올라갔다가 창이 닫힐 때 내려오지 않게 한다(#69).
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onChange(of: viewModel.state) { _, state in
            guard state == .failed else { return }
            AccessibilityNotification.Announcement(String(localized: "로그인하지 못했어요. 다시 시도해 주세요")).post()
        }
    }

    private var header: some View {
        VStack(spacing: Spacing.lg) {
            HeroIcon(icon: .iconSprout, style: .logo)
            VStack(spacing: Spacing.sm) {
                Text("환경지킴이")
                    .ecoFont(.title1)
                    .foregroundStyle(Color.ecoTextPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("학교를 깨끗하게, 함께 만드는 습관")
                    .ecoFont(.body2)
                    .foregroundStyle(Color.ecoTextSub)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, Spacing.screenHorizontal)
    }

    private var loginButton: some View {
        EcoButton(buttonTitle, isLoading: viewModel.state == .loading) {
            await viewModel.login()
        }
    }

    private var buttonTitle: LocalizedStringKey {
        switch viewModel.state {
        case .loading: "로그인하는 중이에요"
        case .failed: "다시 시도하기"
        default: "DataGSM으로 로그인"
        }
    }
}

#Preview("기본") {
    LoginView(viewModel: DIContainer.preview().makeLoginViewModel())
}

#Preview("로딩") {
    LoginView(viewModel: DIContainer.preview().makeLoginViewModel(state: .loading))
}

#Preview("실패") {
    LoginView(viewModel: DIContainer.preview(outcome: .failure).makeLoginViewModel(state: .failed))
}
