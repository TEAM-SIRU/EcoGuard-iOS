#if DEBUG
import Testing
@testable import EcoGuard

@MainActor
struct ScreenGalleryTests {
    /// 실행 인자 `-ScreenGallery <id>`로 항목을 바로 열기 때문에 ID가 겹치면 안 된다.
    @Test func itemIDsAreUnique() {
        let ids = ScreenGalleryCatalog.sections.flatMap(\.items).map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func launchArgumentOpensGallery() {
        #expect(ScreenGalleryLaunch(arguments: ["EcoGuard"]) == nil)
        #expect(ScreenGalleryLaunch(arguments: ["EcoGuard", "-ScreenGallery"])?.initialItemID == nil)
        #expect(ScreenGalleryLaunch(arguments: ["EcoGuard", "-ScreenGallery", "shell.recruiting"])?.initialItemID == "shell.recruiting")
        // 다음 인자가 다른 옵션이면 항목 ID로 보지 않는다.
        #expect(ScreenGalleryLaunch(arguments: ["EcoGuard", "-ScreenGallery", "-ECO_USE_MOCK"])?.initialItemID == nil)
    }
}
#endif
