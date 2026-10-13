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

    /// 모든 항목이 화면을 만든다(Mock 구성·처음 상태를 넣는 중에 멈추지 않는다).
    @Test func everyItemMakesContent() {
        let items = ScreenGalleryCatalog.sections.flatMap(\.items)
        #expect(!items.isEmpty)
        for item in items {
            _ = item.makeContent {}
        }
    }

    /// Redesign 2 이후 빠져 있던 화면·상태(#105 이후 보강).
    @Test(arguments: [
        "shell.longArea", "shell.excludedStill", "shell.excludedCheckFailed", "shell.helpUnavailable", "shell.submissionUnavailable",
        "recruitment.applyNameOnly", "recruitment.applyUnknownApplicant", "recruitment.applyOverLimit",
        "recruitment.applySubmitting", "recruitment.applyFailed",
        "appeal.formSubmitting", "notice.empty",
        "myPage.withdrawing", "myPage.withdrawFailed", "myPage.notificationDenied", "myPage.longText",
        "area.longText", "area.unknownZone", "records.holiday", "records.longArea"
    ])
    func addedItemExists(id: String) {
        #expect(ScreenGalleryCatalog.sections.flatMap(\.items).contains { $0.id == id })
    }

    @Test func searchMatchesTitleIDAndSection() {
        let sections = ScreenGalleryCatalog.sections
        #expect(ScreenGalleryCatalog.filter(sections, query: "").count == sections.count)
        #expect(ScreenGalleryCatalog.filter(sections, query: "  ").count == sections.count)

        // ID로 찾는다(대소문자 무시).
        let byID = ScreenGalleryCatalog.filter(sections, query: "MYPAGE.WITHDRAWFAILED").flatMap(\.items).map(\.id)
        #expect(byID == ["myPage.withdrawFailed"])

        // 이름으로 찾으면 맞는 항목만 남고 빈 섹션은 빠진다.
        let byTitle = ScreenGalleryCatalog.filter(sections, query: "도움말 준비 중")
        #expect(byTitle.map(\.items.count) == [1])
        #expect(byTitle.first?.items.first?.id == "shell.helpUnavailable")

        // 섹션 제목이 맞으면 섹션 전체를 남긴다.
        let bySection = ScreenGalleryCatalog.filter(sections, query: "이의신청")
        let appealSection = sections.first { $0.title == "이의신청" }
        #expect(bySection.first { $0.title == "이의신청" }?.items.count == appealSection?.items.count)

        #expect(ScreenGalleryCatalog.filter(sections, query: "없는화면xyz").isEmpty)
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
