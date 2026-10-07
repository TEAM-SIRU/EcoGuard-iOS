#if DEBUG
import SwiftUI

/// 디버그 빌드 전용 화면 모음(#78). 로그인 없이 실제 화면을 Mock 상태로 띄워 본다.
/// 항목은 `ScreenGalleryCatalog`에 있고, 각 항목은 앱 화면 컴포넌트에 Mock ViewModel·저장소를 넣어 만든다.
struct ScreenGalleryView: View {
    /// 실행 인자로 고른 항목. 갤러리가 열리면 바로 띄운다.
    let initialItemID: String?
    let close: () -> Void

    @State private var selectedItem: ScreenGalleryItem?
    @State private var hasOpenedInitialItem = false
    private let sections = ScreenGalleryCatalog.sections

    var body: some View {
        NavigationStack {
            List {
                ForEach(sections) { section in
                    Section(section.title) {
                        ForEach(section.items) { item in
                            Button(item.title) { open(item) }
                        }
                    }
                }
            }
            .navigationTitle("화면 둘러보기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기", action: close)
                }
            }
        }
        .fullScreenCover(item: $selectedItem) { item in
            ScreenGalleryItemHost(item: item) { selectedItem = nil }
        }
        .task {
            guard !hasOpenedInitialItem, let initialItemID else { return }
            hasOpenedInitialItem = true
            guard let item = sections.flatMap(\.items).first(where: { $0.id == initialItemID }) else { return }
            open(item)
        }
    }

    /// 목록에서 항목 화면으로 바로 넘어가게 전환 애니메이션을 끈다.
    private func open(_ item: ScreenGalleryItem) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { selectedItem = item }
    }
}

/// 항목 화면 하나를 띄운다. 화면은 처음 나타날 때 한 번만 만든다(상위가 다시 그려져도 ViewModel을 새로 만들지 않는다).
/// 탭 셸·마이페이지처럼 닫기 버튼이 없는 화면도 있어 끌어서 옮길 수 있는 닫기 버튼을 위에 얹는다.
private struct ScreenGalleryItemHost: View {
    let item: ScreenGalleryItem
    let close: () -> Void

    @State private var content: AnyView?
    @State private var closeButtonOffset: CGSize = .zero
    @GestureState private var dragTranslation: CGSize = .zero

    var body: some View {
        ZStack {
            Color.ecoCard.ignoresSafeArea()
            content
        }
        .overlay(alignment: .trailing) { closeButton }
        .task {
            guard content == nil else { return }
            // 전환이 끝난 뒤 만든다. 전환 중에는 화면이 처음부터 띄운 시트·팝업(인증 불가 시트, 로그아웃 확인)이 뜨지 않는다.
            try? await Task.sleep(for: Metrics.presentationDelay)
            content = item.makeContent(close)
        }
    }

    private var closeButton: some View {
        Button(action: close) {
            Image(systemName: "xmark")
                .foregroundStyle(Color.ecoOnToast)
                .frame(width: Metrics.closeButtonSize, height: Metrics.closeButtonSize)
                .background(Color.ecoToastBackground.opacity(Metrics.closeButtonOpacity), in: Circle())
        }
        .accessibilityLabel("화면 모음으로 돌아가기")
        .offset(
            x: closeButtonOffset.width + dragTranslation.width,
            y: closeButtonOffset.height + dragTranslation.height
        )
        .gesture(
            DragGesture()
                .updating($dragTranslation) { value, state, _ in state = value.translation }
                .onEnded { value in
                    closeButtonOffset.width += value.translation.width
                    closeButtonOffset.height += value.translation.height
                }
        )
        .padding(.trailing, Spacing.xs)
    }
}

/// 실행 인자 `-ScreenGallery [항목 ID]`. 항목 ID를 주면 그 화면을 바로 연다(예: `-ScreenGallery shell.recruiting`).
struct ScreenGalleryLaunch: Identifiable {
    static let argument = "-ScreenGallery"

    let id = UUID()
    let initialItemID: String?

    init(initialItemID: String? = nil) {
        self.initialItemID = initialItemID
    }

    init?(arguments: [String]) {
        guard let index = arguments.firstIndex(of: Self.argument) else { return nil }
        let next = arguments.index(after: index)
        let itemID = next < arguments.endIndex ? arguments[next] : nil
        self.init(initialItemID: itemID?.hasPrefix("-") == false ? itemID : nil)
    }
}

extension View {
    /// 화면 모음 진입점. `showsEntryButton`이면 위쪽에 `화면 둘러보기` 버튼을 띄우고(로그인 화면),
    /// 실행 인자 `-ScreenGallery`가 있으면 앱 시작 때 바로 연다.
    func screenGallery(showsEntryButton: Bool) -> some View {
        modifier(ScreenGalleryEntryModifier(showsEntryButton: showsEntryButton))
    }
}

private struct ScreenGalleryEntryModifier: ViewModifier {
    let showsEntryButton: Bool

    @State private var launch = ScreenGalleryLaunch(arguments: ProcessInfo.processInfo.arguments)

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if showsEntryButton {
                    entryButton
                }
            }
            .fullScreenCover(item: $launch) { launch in
                ScreenGalleryView(initialItemID: launch.initialItemID) { self.launch = nil }
            }
    }

    private var entryButton: some View {
        Button {
            launch = ScreenGalleryLaunch()
        } label: {
            Label("화면 둘러보기", systemImage: "square.grid.2x2")
                .ecoFont(.button)
                .foregroundStyle(Color.ecoOnPrimary)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .background(Color.ecoPrimary, in: Capsule())
        }
        .padding(.top, Spacing.sm)
    }
}

private enum Metrics {
    static let closeButtonSize: CGFloat = 36
    static let closeButtonOpacity: Double = 0.7
    static let presentationDelay: Duration = .milliseconds(600)
}
#endif
