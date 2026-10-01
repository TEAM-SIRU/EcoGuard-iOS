import SwiftUI

/// 학생 로그인 후 진입하는 메인 화면 자리. 메인 이슈에서 교체한다.
struct MainPlaceholderView: View {
    var body: some View {
        Text(verbatim: "메인")
            .ecoFont(.title1)
            .foregroundStyle(Color.ecoTextPrimary)
    }
}

#Preview {
    MainPlaceholderView()
}
