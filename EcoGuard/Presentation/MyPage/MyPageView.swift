import SwiftUI

/// Figma `12 마이페이지` (823:2045) · `12 마이페이지 · 로그아웃 확인` (823:2770). 하단 탭 바는 앱 셸(`MainTabView`)이 얹는다.
/// 내 정보를 불러오지 못해도 메뉴와 로그아웃은 그대로 쓸 수 있다.
struct MyPageView: View {
    /// 화면 이동. 앱 셸(`MainTabView`)이 연결한다. 기본값은 아무것도 하지 않는다.
    struct Actions {
        var openCleaningArea: () -> Void = {}
        var openApplicationResult: () -> Void = {}
        var openAppeals: () -> Void = {}
        var openNotices: () -> Void = {}
        /// 도움말은 Figma 디자인이 없어(디자인 대기) 셸이 준비 중 토스트를 띄운다.
        var openHelp: () -> Void = {}
    }

    let viewModel: MyPageViewModel
    var actions = Actions()

    @Environment(\.openURL) private var openURL

    /// 회원탈퇴 실패 토스트. Figma 정의가 없어 다른 토스트와 같은 모양으로 위쪽에 띄운다.
    @State private var isWithdrawFailedToastPresented = false

    private static let withdrawFailedMessage: LocalizedStringResource = "탈퇴하지 못했어요. 잠시 후 다시 시도해 주세요"

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                profileSection
                sectionDivider
                EcoListCard {
                    EcoListRow(icon: nil, title: "내 청소 구역") {
                        EcoListRowDisclosure(value: summary?.cleaningAreaName)
                    }
                    .menuButton(action: actions.openCleaningArea)
                    EcoListRow(icon: nil, title: "신청 결과") {
                        EcoListRowDisclosure(value: summary?.hasApplied == true ? "신청 완료" : nil)
                    }
                    .menuButton(action: actions.openApplicationResult)
                    EcoToggleRow(
                        title: "청소 알림",
                        isOn: Binding(
                            get: { viewModel.isCleaningReminderOn },
                            set: { isOn in Task { await viewModel.setCleaningReminder(isOn) } }
                        )
                    )
                    // 로그아웃 확인 팝업과 같은 뷰에 두 개를 겹쳐 걸지 않도록 스위치 행에 건다.
                    .ecoDialog(isPresented: notificationDeniedBinding, onCancel: viewModel.dismissNotificationDenied) {
                        EcoDialog(
                            LocalizedStringKey(CleaningReminderCopy.Denied.title),
                            message: LocalizedStringKey(CleaningReminderCopy.Denied.message)
                        ) {
                            EcoButton(LocalizedStringKey(CleaningReminderCopy.Denied.cancel), style: .secondary, action: viewModel.dismissNotificationDenied)
                            EcoButton(LocalizedStringKey(CleaningReminderCopy.Denied.openSettings)) {
                                viewModel.dismissNotificationDenied()
                                guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
                                openURL(url)
                            }
                        }
                    }
                    EcoListRow(icon: nil, title: "이의신청 내역") {
                        EcoListRowDisclosure()
                    }
                    .menuButton(action: actions.openAppeals)
                }
                sectionDivider
                EcoListCard {
                    EcoListRow(icon: nil, title: "공지") {
                        EcoListRowDisclosure()
                    }
                    .menuButton(action: actions.openNotices)
                    EcoListRow(icon: nil, title: "도움말") {
                        EcoListRowDisclosure()
                    }
                    .menuButton(action: actions.openHelp)
                }
                sectionDivider
                accountActions
                #if DEBUG
                ScreenGalleryMenuRow()
                #endif
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.ecoCanvas)
        .task {
            // 불러온 화면이 없으면(처음, 탭을 떠나 취소됨) 다시 불러온다. 실패 화면은 사용자가 다시 시도한다.
            guard viewModel.state == .loading else { return }
            await viewModel.load()
        }
        .ecoDialog(
            isPresented: logoutConfirmBinding,
            onCancel: viewModel.cancelLogout,
            onDismiss: viewModel.logoutConfirmDidDismiss
        ) {
            EcoDialog("로그아웃할까요?", message: "다시 들어오려면 DataGSM으로 로그인해야 해요") {
                EcoButton("취소", style: .secondary, action: viewModel.cancelLogout)
                    .disabled(viewModel.isLoggingOut)
                EcoButton("로그아웃", style: .destructive, isLoading: viewModel.isLoggingOut) {
                    await viewModel.confirmLogout()
                }
            }
        }
        .overlay(alignment: .top) {
            if isWithdrawFailedToastPresented {
                EcoToast(message: Self.withdrawFailedMessage)
                    .padding(.top, Spacing.sm)
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .transition(.opacity)
            }
        }
        .animation(.default, value: isWithdrawFailedToastPresented)
        .onChange(of: viewModel.withdrawFailureCount) { old, new in
            guard new > old else { return }
            AccessibilityNotification.Announcement(String(localized: Self.withdrawFailedMessage)).post()
            isWithdrawFailedToastPresented = true
        }
        .task(id: viewModel.withdrawFailureCount) {
            guard isWithdrawFailedToastPresented else { return }
            // 다시 실패하면 이 작업은 취소되고 새 작업이 시간을 처음부터 센다.
            guard (try? await Task.sleep(for: EcoToast.displayDuration)) != nil else { return }
            isWithdrawFailedToastPresented = false
        }
    }

    private var summary: MyPageSummary? {
        if case .loaded(let summary) = viewModel.state { summary } else { nil }
    }

    @ViewBuilder
    private var profileSection: some View {
        switch viewModel.state {
        case .loading:
            // 불러온 프로필과 같은 높이를 차지해야 불러온 뒤 아래 메뉴가 밀려 내려가지 않는다(#89).
            // 글자 크기를 따라가도록 빈 프로필을 숨겨 높이를 잡고, 스켈레톤은 그 위에 얹는다.
            profileContent(name: " ", caption: " ", approvedCount: " ", activityTime: " ")
                .hidden()
                .overlay(alignment: .top) {
                    VStack(spacing: Spacing.md) {
                        EcoSkeleton(kind: .row)
                        EcoSkeleton(kind: .row)
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xl)
        case .failed:
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("내 정보를 불러오지 못했어요")
                    .ecoFont(.body2)
                    .foregroundStyle(Color.ecoTextSub)
                EcoButton("다시 시도", style: .secondary, size: .compact, action: viewModel.load)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.xl)
        case .loaded(let summary):
            profileContent(
                name: summary.profile.name,
                caption: MyPageFormatter.affiliation(of: summary.profile),
                approvedCount: MyPageFormatter.count(summary.monthlyApprovedCount),
                activityTime: MyPageFormatter.minutes(summary.monthlyActivityMinutes)
            )
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.xl)
        }
    }

    private func profileContent(name: String, caption: String, approvedCount: String, activityTime: String) -> some View {
        VStack(spacing: Spacing.xl) {
            EcoProfileHeader(name: name, caption: caption)
            HStack(spacing: Spacing.sm) {
                statTile(title: "이번 달 승인", value: approvedCount)
                statTile(title: "활동 시간", value: activityTime)
            }
        }
    }

    private func statTile(title: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .ecoFont(.captionMedium)
                .foregroundStyle(Color.ecoTextCaption)
            Text(value)
                .ecoFont(.title2)
                .foregroundStyle(Color.ecoTextPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .ecoCardBackground(cornerRadius: Radius.box)
        .accessibilityElement(children: .combine)
    }

    /// Figma `Section divider`. 화면 배경색 12 간격이다.
    private var sectionDivider: some View {
        Spacer()
            .frame(height: Spacing.md)
    }

    /// Figma 아래 줄: `로그아웃` · `회원탈퇴`(빨강), 사이 20, 위아래 16.
    private var accountActions: some View {
        HStack(spacing: Spacing.xl) {
            accountButton("로그아웃", color: .ecoTextCaption, action: viewModel.requestLogout)
            accountButton("회원탈퇴", color: .ecoDestructive, action: viewModel.requestWithdraw)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        // 로그아웃 확인 팝업과 같은 뷰에 두 개를 겹쳐 걸지 않도록 이 줄에 건다.
        .ecoDialog(
            isPresented: withdrawConfirmBinding,
            onCancel: viewModel.cancelWithdraw,
            onDismiss: viewModel.logoutConfirmDidDismiss
        ) {
            EcoDialog("회원탈퇴", message: "정말 탈퇴하시겠어요?") {
                EcoButton("취소", style: .secondary, action: viewModel.cancelWithdraw)
                    .disabled(viewModel.isWithdrawing)
                EcoButton("회원탈퇴", style: .destructive, isLoading: viewModel.isWithdrawing) {
                    await viewModel.confirmWithdraw()
                }
            }
        }
    }

    private func accountButton(_ title: LocalizedStringKey, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .ecoFont(.body2Medium)
                .foregroundStyle(color)
                .padding(.vertical, Spacing.lg)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// 팝업 바깥에서 닫히는 경우(시스템이 내림)도 취소로 본다. 로그아웃 중에는 `cancelLogout`이 무시한다.
    private var logoutConfirmBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isLogoutConfirmPresented },
            set: { isPresented in
                if !isPresented { viewModel.cancelLogout() }
            }
        )
    }

    /// 팝업 바깥에서 닫히는 경우도 취소로 본다. 탈퇴 중에는 `cancelWithdraw`가 무시한다.
    private var withdrawConfirmBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isWithdrawConfirmPresented },
            set: { isPresented in
                if !isPresented { viewModel.cancelWithdraw() }
            }
        )
    }

    private var notificationDeniedBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isNotificationDeniedPresented },
            set: { isPresented in
                if !isPresented { viewModel.dismissNotificationDenied() }
            }
        )
    }
}

private extension View {
    /// 행 전체를 누를 수 있는 메뉴 버튼으로 만든다.
    func menuButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private func myPagePreview(
    _ scenario: MockMyPageRepository.Scenario = .guardian,
    delay: Duration = .zero,
    isCleaningReminderOn: Bool = true
) -> MyPageViewModel {
    // Preview가 앱 설정을 바꾸지 않게 따로 둔 저장소를 쓴다.
    let defaults = UserDefaults(suiteName: "preview.myPage") ?? .standard
    let settings = NotificationSettingRepositoryImpl(defaults: defaults)
    settings.setCleaningReminderOn(isCleaningReminderOn)
    let container = DIContainer(
        authRepository: MockAuthRepository(delay: .seconds(3600)),
        homeRepository: MockHomeRepository(delay: .zero),
        recruitmentRepository: MockRecruitmentRepository(delay: .zero),
        webAdminURL: nil
    )
    return container.makeMyPageViewModel(
        repository: MockMyPageRepository(scenario: scenario, delay: delay),
        notificationSettingRepository: settings,
        onLoggedOut: {}
    )
}

#Preview("환경지킴이") { MyPageView(viewModel: myPagePreview()) }
#Preview("청소 알림 끔") { MyPageView(viewModel: myPagePreview(isCleaningReminderOn: false)) }
#Preview("미신청") { MyPageView(viewModel: myPagePreview(.notApplied)) }
#Preview("로딩") { MyPageView(viewModel: myPagePreview(delay: .seconds(3600))) }
#Preview("조회 실패") { MyPageView(viewModel: myPagePreview(.failure)) }
#Preview("로그아웃 확인") {
    let viewModel = myPagePreview()
    MyPageView(viewModel: viewModel)
        .onAppear { viewModel.requestLogout() }
}
#Preview("로그아웃 중") {
    let viewModel = myPagePreview()
    MyPageView(viewModel: viewModel)
        .task {
            viewModel.requestLogout()
            await viewModel.confirmLogout()
        }
}
