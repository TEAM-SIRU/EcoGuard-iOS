import SwiftUI

/// Figma `01 로그인 · 기본` (238:122) · `로딩` (238:141) · `실패` (238:162).
struct LoginView: View {
    let viewModel: LoginViewModel

    @State private var isReviewLoginPresented = false
    @State private var reviewCode = ""

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
        .alert(ReviewLoginText.title, isPresented: $isReviewLoginPresented) {
            SecureField(ReviewLoginText.codePlaceholder, text: $reviewCode)
            Button(ReviewLoginText.cancel, role: .cancel) {
                reviewCode = ""
            }
            Button(ReviewLoginText.submit) {
                let code = reviewCode
                reviewCode = ""
                Task { await viewModel.login(reviewCode: code) }
            }
            .disabled(!LoginViewModel.canSubmit(reviewCode: reviewCode))
        } message: {
            Text(ReviewLoginText.message)
        }
    }

    /// 앱 심사자용 데모 계정 진입(#101). 일반 사용자 눈에 띄지 않게 로고·앱 이름을 길게 눌러야 열린다. Release 빌드에도 들어간다.
    private func presentReviewLogin() {
        guard viewModel.state != .loading else { return }
        reviewCode = ""
        isReviewLoginPresented = true
    }

    private var header: some View {
        VStack(spacing: Spacing.lg) {
            HeroIcon(icon: .iconSprout, style: .logo)
            VStack(spacing: Spacing.sm) {
                Text("환경지킴이")
                    .ecoFont(.title1)
                    .foregroundStyle(Color.ecoTextPrimary)
                    .accessibilityAddTraits(.isHeader)
                    // 로고는 VoiceOver에서 숨겨져 있어 길게 누르기 대신 제목의 동작으로 연다.
                    .accessibilityAction(named: ReviewLoginText.accessibilityAction, presentReviewLogin)
                Text("학교를 깨끗하게, 함께 만드는 습관")
                    .ecoFont(.body2)
                    .foregroundStyle(Color.ecoTextSub)
            }
        }
        .multilineTextAlignment(.center)
        .contentShape(Rectangle())
        // 우연히 열리지 않게 2초를 누르고 있어야 한다.
        .onLongPressGesture(minimumDuration: 2, perform: presentReviewLogin)
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

/// 심사용 로그인 문구. 기획 확인 대상이라 한 곳에 모은다.
private enum ReviewLoginText {
    static let title: LocalizedStringKey = "심사용 로그인"
    static let message: LocalizedStringKey = "전달받은 심사용 코드를 입력해 주세요"
    static let codePlaceholder: LocalizedStringKey = "심사용 코드"
    static let submit: LocalizedStringKey = "로그인"
    static let cancel: LocalizedStringKey = "취소"
    static let accessibilityAction: LocalizedStringKey = "심사용 로그인"
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
