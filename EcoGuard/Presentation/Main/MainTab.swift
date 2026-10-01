import SwiftUI

/// 학생 앱 하단 탭. 가운데 카메라 버튼은 탭이 아니다.
enum MainTab: CaseIterable {
    case home
    case area
    case records
    case myPage

    var title: LocalizedStringKey {
        switch self {
        case .home: "홈"
        case .area: "구역"
        case .records: "기록"
        case .myPage: "마이페이지"
        }
    }

    var icon: ImageResource {
        switch self {
        case .home: .iconTabHome
        case .area: .iconTabMap
        case .records: .iconTabRecords
        case .myPage: .iconTabMyPage
        }
    }
}
