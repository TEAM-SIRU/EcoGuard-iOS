import Testing
@testable import EcoGuard

@MainActor
struct ApplicationMotivationTests {
    @Test(arguments: ["", "   ", "\n\t "])
    func blankIsEmpty(text: String) {
        #expect(ApplicationMotivation.validate(text) == .empty)
    }

    @Test func upToMaxLengthIsValid() {
        let text = String(repeating: "가", count: ApplicationMotivation.maxLength)

        #expect(ApplicationMotivation.validate(text) == .valid)
    }

    @Test func overMaxLengthIsTooLong() {
        let text = String(repeating: "가", count: ApplicationMotivation.maxLength + 1)

        #expect(ApplicationMotivation.validate(text) == .tooLong)
    }

    /// 화면 글자 수와 같게 이모지 하나를 한 글자로 센다.
    @Test func countsUserPerceivedCharacters() {
        let text = String(repeating: "👍🏽", count: ApplicationMotivation.maxLength)

        #expect(ApplicationMotivation.validate(text) == .valid)
    }

    @Test func lengthIgnoresSurroundingWhitespace() {
        let text = "  " + String(repeating: "가", count: ApplicationMotivation.maxLength) + " \n"

        #expect(ApplicationMotivation.length(of: text) == ApplicationMotivation.maxLength)
        #expect(ApplicationMotivation.validate(text) == .valid)
    }

    @Test func trimsSurroundingWhitespace() {
        #expect(ApplicationMotivation.trimmed("  교실을 깨끗하게\n") == "교실을 깨끗하게")
    }
}
