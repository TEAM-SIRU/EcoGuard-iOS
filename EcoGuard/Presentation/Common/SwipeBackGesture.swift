import ObjectiveC
import SwiftUI
import UIKit

extension View {
    /// 시스템 내비게이션 바를 숨기고(`.toolbar(.hidden, for: .navigationBar)`) `EcoNavBar`를 쓰는 push 화면에서도
    /// 화면 왼쪽 끝에서 밀어 뒤로 갈 수 있게 한다. UIKit은 바를 숨기면 뒤로 가기 제스처를 시작하지 않는다(#92).
    /// 보내는 중처럼 뒤로 가면 안 되는 화면에는 붙이지 않는다.
    func swipeBackEnabled() -> some View {
        background {
            SwipeBackGestureEnabler()
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
    }
}

/// 화면이 나타나면 그 화면이 들어간 내비게이션 컨트롤러의 뒤로 가기 제스처 판단을 `SwipeBackGestureDelegate`에 맡긴다.
private struct SwipeBackGestureEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ controller: Controller, context: Context) {}

    final class Controller: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard let navigationController else { return }
            SwipeBackGestureDelegate.install(on: navigationController)
        }
    }
}

/// 내비게이션 컨트롤러마다 하나 붙여 두고 떼지 않는다(화면이 사라질 때 원래 delegate로 돌리면 밀다 멈춘 전환과 엇갈린다).
private final class SwipeBackGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    private static var key: UInt8 = 0
    private weak var navigationController: UINavigationController?

    private init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    static func install(on navigationController: UINavigationController) {
        guard let gesture = navigationController.interactivePopGestureRecognizer,
              !(gesture.delegate is SwipeBackGestureDelegate) else { return }
        let delegate = SwipeBackGestureDelegate(navigationController: navigationController)
        // gesture.delegate는 weak라 컨트롤러가 붙들고 있게 한다.
        objc_setAssociatedObject(navigationController, &key, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        gesture.delegate = delegate
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let navigationController else { return false }
        // 첫 화면에서 시작하거나 전환 중에 다시 시작하면 내비게이션이 멈추거나 화면이 엇갈린다.
        return navigationController.viewControllers.count > 1 && navigationController.transitionCoordinator == nil
    }
}
