import SwiftUI
import UIKit

/// Figma `01 로그인 · 교사 계정 안내` (309:24). 교사 계정은 앱을 쓰지 않고 웹 주소 복사·공유와 로그아웃만 할 수 있다.
/// 웹 관리자 주소가 없으면 복사·공유 버튼을 숨긴다.
struct TeacherNoticeView: View {
    let webAdminURL: URL?
    let onLogout: () async -> Void

    private static let copiedMessage: LocalizedStringResource = "웹 주소를 복사했어요"

    @State private var copyCount = 0
    @State private var isShowingCopiedToast = false
    @State private var isLoggingOut = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: Spacing.lg) {
                HeroIcon(icon: .iconList, style: .badge)
                VStack(spacing: Spacing.sm) {
                    Text("선생님은 웹에서 이용해 주세요")
                        .ecoFont(.title2)
                        .foregroundStyle(Color.ecoTextPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text("모집·청소 구역·이의신청 관리는 웹 관리자 페이지에서 할 수 있어요")
                        .ecoFont(.body2)
                        .foregroundStyle(Color.ecoTextSub)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.bottom, Spacing.xxxl)
            Spacer(minLength: 0)
        }
        .safeAreaInset(edge: .bottom) {
            BottomCTA {
                if let webAdminURL {
                    EcoButton("웹 주소 복사", style: .secondary) {
                        copy(webAdminURL)
                    }
                    .disabled(isLoggingOut)
                    EcoShareButton("웹 주소 공유", style: .secondary, item: webAdminURL)
                        .disabled(isLoggingOut)
                }
                EcoButton("로그아웃", style: .secondary) {
                    isLoggingOut = true
                    await onLogout()
                    isLoggingOut = false
                }
            }
        }
        // 복사 완료 토스트는 Figma 정의가 없어 화면 위쪽에 문구만 띄운다.
        .overlay(alignment: .top) {
            if isShowingCopiedToast {
                EcoToast(message: Self.copiedMessage, icon: nil)
                    .padding(.top, Spacing.sm)
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .transition(.opacity)
            }
        }
        .animation(.default, value: isShowingCopiedToast)
        .task(id: copyCount) {
            guard copyCount > 0 else { return }
            isShowingCopiedToast = true
            // 다시 복사하면 이 작업은 취소되고 새 작업이 시간을 처음부터 센다.
            guard (try? await Task.sleep(for: EcoToast.displayDuration)) != nil else { return }
            isShowingCopiedToast = false
        }
    }

    private func copy(_ url: URL) {
        UIPasteboard.general.url = url
        copyCount += 1
        AccessibilityNotification.Announcement(String(localized: Self.copiedMessage)).post()
    }
}

#Preview("교사 · 웹 주소 있음") {
    // Preview 전용 예시 주소(example.com은 문서용 예약 도메인)다. 실제 주소는 빌드 설정 `ECO_WEB_ADMIN_HOST`로 넣는다.
    TeacherNoticeView(webAdminURL: AppConfig.webAdminURL(from: "https://example.com")) {}
}

#Preview("교사 · 웹 주소 없음") {
    TeacherNoticeView(webAdminURL: nil) {}
}
