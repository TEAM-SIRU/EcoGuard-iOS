import SwiftUI
import Testing
@testable import EcoGuard

struct HomeNoticeBodyTests {
    @Test func keepsLineBreaks() {
        let text = HomeNoticeBody.attributed(from: "첫 줄\n둘째 줄\n\n넷째 줄")

        #expect(String(text.characters) == "첫 줄\n둘째 줄\n\n넷째 줄")
    }

    @Test func removesMarkersAndHighlightsStrongText() {
        let text = HomeNoticeBody.attributed(from: "매일 **08:00 – 08:10**에 청소")

        #expect(String(text.characters) == "매일 08:00 – 08:10에 청소")
        let strong = text.runs.filter { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true }
        #expect(strong.count == 1)
        #expect(strong.allSatisfy { $0.foregroundColor == .ecoTextPrimary })
        #expect(text.runs.filter { $0.inlinePresentationIntent == nil }.allSatisfy { $0.foregroundColor == .ecoTextSub })
    }
}
