import SwiftUI

/// Figma `12 전체` (240:221) · `12 전체 · 로그아웃 확인` (309:64). 하단 탭 바는 앱 셸(`MainTabView`)이 얹는다.
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

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                profileSection
                sectionDivider
                EcoListRow(icon: nil, title: "내 청소 구역", horizontalPadding: Spacing.screenHorizontal) {
                    EcoListRowDisclosure(value: summary?.cleaningAreaName)
                }
                .menuButton(action: actions.openCleaningArea)
                EcoListRow(icon: nil, title: "신청 결과", horizontalPadding: Spacing.screenHorizontal) {
                    EcoListRowDisclosure(value: summary?.hasApplied == true ? "신청 완료" : nil)
                }
                .menuButton(action: actions.openApplicationResult)
                EcoToggleRow(
                    title: "청소 알림",
                    isOn: Binding(get: { viewModel.isCleaningReminderOn }, set: viewModel.setCleaningReminder),
                    horizontalPadding: Spacing.screenHorizontal
                )
                EcoListRow(icon: nil, title: "이의신청 내역", horizontalPadding: Spacing.screenHorizontal) {
                    EcoListRowDisclosure()
                }
                .menuButton(action: actions.openAppeals)
                sectionDivider
                EcoListRow(icon: nil, title: "공지", horizontalPadding: Spacing.screenHorizontal) {
                    EcoListRowDisclosure()
                }
                .menuButton(action: actions.openNotices)
                EcoListRow(icon: nil, title: "도움말", horizontalPadding: Spacing.screenHorizontal) {
                    EcoListRowDisclosure()
                }
                .menuButton(action: actions.openHelp)
                sectionDivider
                logoutButton
                #if DEBUG
                ScreenGalleryMenuRow()
                #endif
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.ecoCard)
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
            profileContent(initials: " ", name: " ", caption: " ", approvedCount: " ", activityTime: " ")
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
                initials: MyPageFormatter.initials(of: summary.profile.name),
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

    private func profileContent(initials: String, name: String, caption: String, approvedCount: String, activityTime: String) -> some View {
        VStack(spacing: Spacing.xl) {
            EcoProfileHeader(initials: initials, name: name, caption: caption)
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
        .background(Color.ecoSurface, in: RoundedRectangle(cornerRadius: Radius.button))
        .accessibilityElement(children: .combine)
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.ecoDivider)
            .frame(height: Spacing.md)
            .accessibilityHidden(true)
    }

    private var logoutButton: some View {
        Button(action: viewModel.requestLogout) {
            Text("로그아웃")
                .ecoFont(.body2Medium)
                .foregroundStyle(Color.ecoTextCaption)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.screenHorizontal)
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
