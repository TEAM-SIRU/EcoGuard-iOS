# EcoGuard iOS Convention (초안)

> GitHub 관련 규칙(Commit / PR / Issue / Label)은 Android와 동일하다.
> `> 결정 필요` 표시는 팀 합의 전 제안 사항이다.

---

## Commit

- 형식: `타입: 작업 내용`
- 제목에 이모지를 쓰지 않는다.

| 타입 | 용도 | 예시 |
| --- | --- | --- |
| `feat` | 새 기능 | `feat: 로그인 기능 구현` |
| `fix` | 버그 수정 | `fix: 토큰 갱신 오류 수정` |
| `refactor` | 구조 개선 | `refactor: 로그인 상태 관리 구조 개선` |
| `chore` | 설정/빌드/dependency | `chore: dependency 버전 수정` |
| `!HOTFIX` | 긴급 수정 | `!HOTFIX : main에 반영된 사항 등 긴급한 수정` |

- 커밋 본문 또는 제목 끝에 이슈번호를 연결한다. 예: `feat: 청소 인증 촬영 화면 구현 (#12)`

---

## Branch

> 결정 필요 (Android와 합의 필요): Android 문서에 브랜치 규칙이 없다. 아래 형식을 제안한다.

- 형식: `타입/#이슈번호-작업명`
- 타입은 Commit 타입과 동일하게 소문자로 쓴다. (`feat`, `fix`, `refactor`, `chore`, `hotfix`)
- 작업명은 영문 소문자 + `-` 로 쓴다.

```
feat/#3-login
fix/#18-token-refresh
hotfix/#25-camera-crash
```

- 기본 브랜치: `dev` (통합, 기본 브랜치). `main` (배포). 작업 브랜치는 `dev`에서 분기하고 `dev`로 PR한다.

---

## Pull Request

- 제목: `[작업요약] -  #이슈번호 :: 작업명`
  - 예: `[Feat] -  #3 :: dataGSM 로그인 구현`
- 해당 작업에 맞는 Label을 선택한다.
- 본문:

```markdown
## 변경 사항
-

## 검증
- [ ] Build
- [ ] Unit Test
- [ ] Lint (SwiftLint)
- [ ] UI / SwiftUI Preview 확인

## 체크리스트
- [ ] DTO·APIService가 Presentation/Domain에 노출되지 않음
- [ ] 문자열·색상·간격 하드코딩 없음
- [ ] DI 등록 확인 (DIContainer / Environment 주입)
- [ ] 민감 정보 포함 없음 (토큰, 키, xcconfig 값 등)

## 관련 이슈
Closes #이슈번호
```

---

## Issue

- 제목: `[기능] 구현할 작업`
  - 예: `[기능] 청소 인증 카메라 촬영 화면 구현`
- 본문:

```markdown
## 작업 내용
-

## 완료 기준
- [ ]
- [ ]

## 참고 사항
-
```

- PR · Commit · Branch에 이슈번호를 연결한다.

---

## Label

Android와 동일하다.

| Label | 용도 |
| --- | --- |
| `✨ feature` | 새 기능 |
| `🚨 fix` | 버그 |
| `♻️ refactor` | 구조 개선 |
| `🔧 chore` | 설정/빌드/dependency |
| `🔥 hotfix` | 긴급 수정 |

---

## Architecture

- **SwiftUI + MVVM + Clean Architecture** (Presentation / Domain / Data)
- Android(Jetpack Compose + MVVM + Clean Architecture)와 레이어 구조를 맞춘다.

### 레이어 책임

| 레이어 | 포함 | 규칙 |
| --- | --- | --- |
| Presentation | View, ViewModel, UI 모델 | Domain만 의존한다. DTO·APIService를 모른다. |
| Domain | Entity, UseCase, Repository Protocol | 어떤 레이어에도 의존하지 않는다. SwiftUI·Foundation 네트워크 import 금지. |
| Data | DTO, APIService, Repository 구현체, Mapper | Domain Protocol을 구현한다. DTO → Entity 변환은 여기서 끝낸다. |

- 의존 방향: `Presentation → Domain ← Data`

### 기술 선택

| 항목 | 추천 | 이유 | 상태 |
| --- | --- | --- | --- |
| 최소 iOS 버전 | iOS 17 | `@Observable`, `NavigationStack` 개선 API를 그대로 쓸 수 있다. | `> 결정 필요` |
| 상태 관리 | `@Observable` (Observation) | `ObservableObject` + `@Published`보다 코드가 짧고 불필요한 re-render가 적다. | `> 결정 필요` |
| 의존성 관리 | SPM | Xcode 기본 도구라 추가 설정이 없다. CocoaPods는 쓰지 않는다. | 확정 제안 |
| DI | 생성자 주입 + `DIContainer` (수동) | 앱 규모에서 Swinject 등 서드파티 없이 충분하다. Android Hilt 대응. | `> 결정 필요` |
| 네트워크 | `URLSession` + `async/await` | 서드파티(Alamofire, Moya) 없이 요청/응답/토큰 갱신을 처리할 수 있다. | `> 결정 필요` |
| 토큰 저장 | Keychain | `UserDefaults`는 암호화되지 않는다. | 확정 제안 |
| 이미지 로딩 | `AsyncImage` 우선 | 캐싱이 부족해지면 그때 Kingfisher 도입을 논의한다. | `> 결정 필요` |
| 모듈화 | 단일 타깃 + 폴더 분리 | 초기 단계에서 멀티 모듈은 빌드 설정 비용이 크다. | `> 결정 필요` |

---

## 폴더 구조

```
EcoGuard/
├── App/                  # EcoGuardApp, DIContainer, RootView
├── Presentation/
│   ├── Login/            # LoginView, LoginViewModel
│   ├── Recruitment/      # 모집 공고 목록·상세·신청
│   ├── Map/              # 학교 도면, 내 청소구역
│   ├── Verification/     # 청소 인증 촬영, AI 검수 결과
│   ├── Activity/         # 활동 기록, 누적 봉사시간
│   ├── Appeal/           # 이의신청 작성·내역
│   ├── Notice/           # 메인 배너, 목록, 상세
│   ├── Setting/          # 알림 설정, 로그아웃
│   └── Common/           # 공용 컴포넌트
├── Domain/
│   ├── Entity/
│   ├── UseCase/
│   └── Repository/       # Protocol만
├── Data/
│   ├── DTO/
│   ├── Network/          # APIService, Endpoint, NetworkClient
│   ├── Repository/       # 구현체
│   └── Mapper/
├── DesignSystem/         # 색·폰트·간격 토큰, 공용 스타일
└── Resources/            # Assets, Localizable.xcstrings, Info.plist
```

- 기능 폴더 하나 = View + ViewModel + 해당 화면 전용 컴포넌트.
- 테스트 타깃은 `EcoGuardTests/` 에 같은 폴더 구조로 둔다.

---

## 네이밍

[Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)를 기준으로 Android 규칙을 옮긴다.

| 대상 | 규칙 | 예시 |
| --- | --- | --- |
| 변수 | lowerCamelCase, 명사 | `recruitmentList`, `totalVolunteerMinutes` |
| 함수 | lowerCamelCase, 동사 | `fetchNotices()`, `submitAppeal(_:)` |
| 타입 (class/struct/enum/protocol) | UpperCamelCase, 명사 | `NoticeDetail`, `VerificationResult` |
| 상수 | lowerCamelCase | `let maxCaptureCount = 1` |
| enum case | lowerCamelCase | `.pending`, `.approved`, `.manualReview` |
| Bool | `is` / `has` / `can` 접두 | `isLoading`, `hasCameraPermission`, `canVerifyNow` |
| View | UpperCamelCase + `View` | `NoticeListView` |
| ViewModel | 화면명 + `ViewModel` | `NoticeListViewModel` |
| UseCase | 동사 + 대상 + `UseCase` | `FetchNoticeDetailUseCase`, `ApplyRecruitmentUseCase` |
| Repository | 대상 + `Repository` (Protocol) / + `RepositoryImpl` (구현) | `NoticeRepository`, `NoticeRepositoryImpl` |
| DTO | 대상 + `DTO` / 요청은 `RequestDTO`, 응답은 `ResponseDTO` | `NoticeResponseDTO` |
| 파일명 | 대표 타입명과 동일 | `NoticeListView.swift` |

### Android와 다르게 한 부분

- **상수**: `UPPER_SNAKE_CASE` → `lowerCamelCase`. Swift API Design Guidelines는 상수도 lowerCamelCase로 쓴다.
- **backing property**: `_uiState` / `uiState` → `private(set) var state`. Swift는 접근 제어자로 읽기 전용 노출을 한 줄에 표현한다.
- **UseCase 동사**: `Get~` 보다 네트워크 조회는 `Fetch~` 를 쓴다. Swift/Apple 생태계에서 비동기 조회에 `fetch`가 관례다.
- **Composable → View**: SwiftUI View는 `struct` 타입이므로 타입 네이밍 규칙(UpperCamelCase)을 따른다.
- **패키지 소문자 → 폴더 UpperCamelCase**: Swift는 패키지 네임스페이스 대신 폴더 그룹을 쓰며 Xcode 관례상 대문자로 시작한다.
- **enum case**: 서버 값 `PENDING` 등은 `rawValue`/`CodingKeys`로 받고 case 이름은 lowerCamelCase로 쓴다.

```swift
enum ApplicationStatus: String, Decodable {
    case pending = "PENDING"
    case approved = "APPROVED"
    case rejected = "REJECTED"
    case unknown

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        self = ApplicationStatus(rawValue: rawValue) ?? .unknown
    }
}
```

---

## SwiftUI 규칙

- View는 화면 그리기만 한다. 로직·API 호출은 ViewModel → UseCase로 보낸다.
- ViewModel은 `@Observable` + `@MainActor` 로 선언한다.
- View에서 ViewModel 소유는 `@State`, 하위 전달은 값 또는 `@Bindable` 로 한다.
- `body`가 길어지면 (대략 50줄 이상) `private var` 서브뷰 또는 별도 View로 분리한다.
- 화면 단위 View(`~View` 중 화면 진입점)에는 `#Preview` 를 둔다. Preview는 Mock Repository/UseCase를 주입한다.
- 화면 상태는 enum 하나로 표현한다.

```swift
@Observable
@MainActor
final class NoticeListViewModel {
    private(set) var state: ViewState<[Notice]> = .idle

    private let fetchNoticesUseCase: FetchNoticesUseCase

    init(fetchNoticesUseCase: FetchNoticesUseCase) {
        self.fetchNoticesUseCase = fetchNoticesUseCase
    }

    func load() async {
        state = .loading
        do {
            state = .loaded(try await fetchNoticesUseCase.execute())
        } catch is CancellationError {
            return
        } catch {
            state = .failed(error)
        }
    }
}
```

---

## 동시성

- Swift Concurrency(`async/await`, `Task`)를 쓴다. completion handler, Combine은 새로 도입하지 않는다.
- UI 상태 변경은 `@MainActor` 에서만 한다.
- View의 비동기 작업은 `.task { }` 로 시작한다. (`onAppear` + `Task { }` 지양 — 화면 이탈 시 자동 취소되지 않는다.)
- 토큰 갱신처럼 공유 상태를 다루는 곳은 `actor` 로 감싼다.
  - actor는 재진입 가능하다. `await` 중에 다른 호출이 들어오므로 actor만으로는 중복 갱신이 막히지 않는다.
  - 진행 중인 갱신을 `Task<Token, Error>?` 로 저장하고, 뒤에 온 호출은 새로 요청하지 않고 그 Task를 `await` 한다. 끝나면 `nil` 로 비운다.
- Swift 6 language mode / Strict Concurrency Checking `Complete` 사용 제안. `> 결정 필요`

---

## SwiftLint

- SPM Build Tool Plugin으로 도입한다. (Homebrew 설치 의존 없이 CI와 로컬을 맞춘다.)
- 설정 파일은 레포 루트 `.swiftlint.yml` 하나로 관리한다.
- PR 전 경고 0개를 목표로 한다. `// swiftlint:disable` 은 이유 주석과 함께 줄 단위로만 쓴다.
- 우선 켤 규칙 제안: `force_unwrapping`, `force_cast`, `force_try`, `line_length(120)`, `file_length`, `type_body_length`, `unused_import`(`swiftlint analyze` 전용, 빌드 플러그인 lint에서는 동작하지 않음). `> 결정 필요`

---

## 디자인 시스템

> 출처: Figma `환경지킴이 디자인 시스템` > 페이지 `App Screens · Redesign` > 프레임 `00 Foundations` (238:4).
> 값은 두 가지 출처다. (1) Figma Variables: 데스크톱 `get_variable_defs`(노드 238:2, 238:4)로 실제 조회. (2) 프레임의 라벨 텍스트: 원격 `get_metadata`(238:2)로 조회. 텍스트 스타일·버튼 높이·아이콘 등 변수에 없는 항목은 (2)뿐이다.
> **Variables와 라벨 값이 서로 다른 항목이 있다**(green 3종, radius/card). 아래 표에서 "충돌"로 표시했고 확정은 디자이너 확인이 필요하다.

### 원칙
- 색상·폰트·간격·라운드는 **하드코딩 금지, 토큰만 사용**한다.
  - 금지: `Color(hex:)`, `.font(.system(size: 17))`, `.padding(24)`, `.cornerRadius(16)` 같은 리터럴
  - 허용: `Color.ecoPrimary`, `.ecoFont(.body1)`, `.padding(Spacing.lg)`, `Radius.button`
- 토큰에 없는 값이 필요하면 코드에서 만들지 말고 디자이너에게 토큰 추가를 요청한다.
- 예외: `DesignSystem/Components`의 공통 컴포넌트는 Figma 컴포넌트 고유 치수(높이, 아이콘 크기, 내부 간격)를 파일 안 `private enum Metrics`에 이름 붙인 상수로 둘 수 있다. 화면 View에서는 금지한다.
- 상태는 색만으로 구분하지 않는다. 색 + 아이콘 + 텍스트를 함께 쓴다 (Figma `Status chip` 규칙, 색맹 대응).

### 색상
- **정의 방식 추천: Asset Catalog colorset** (`Assets.xcassets/Colors/`)
  - 이유 1: 나중에 다크 값이 생기면 같은 colorset에 Appearance만 추가하면 되고 코드 변경이 없다.
  - 이유 2: Xcode 15+ 심볼 자동 생성으로 오타가 컴파일 에러가 된다. 심볼 이름은 **colorset 이름을 그대로 따른다** (`ecoPrimary.colorset` → `Color.ecoPrimary`).
  - 이유 3: 디자이너가 Xcode에서 값을 바로 확인할 수 있다.
- **이름 규칙**: colorset 이름 = 시맨틱 이름 하나로 통일한다. 원시 팔레트(`green500` 등)용 colorset이나 별도 `Color` 확장은 만들지 않는다.
  - 형식: `eco` + Figma 역할(영문)의 UpperCamelCase. 텍스트 계열은 `ecoText` + 역할로 묶는다.
  - Figma 변수 이름(`green/500` 등)은 colorset 안에 주석이 없으므로 아래 표로만 대응을 관리한다.
  - 예: `green/500 · Primary` → `ecoPrimary.colorset` → `Color.ecoPrimary`
  - 예: `grey/900 · Text` → `ecoTextPrimary.colorset` → `Color.ecoTextPrimary`
  - 예: `grey/700 · Sub` → `ecoTextSub.colorset` → `Color.ecoTextSub`
  - 예: `red/500 · Rejected` → `ecoRejected.colorset` → `Color.ecoRejected`
  - 예: `orange/700 · Pending` → `ecoPending.colorset` → `Color.ecoPending`
  - 역할이 없는 변수는 colorset으로 등록하지 않는다(토큰 미등록). 역할이 정해지면 위 형식으로 등록한다.
- **다크모드**: Figma에 다크 값 없음. 임의 값을 만들지 않는다.
  - colorset의 Appearances는 `None`(단일 값)으로 둔다.
  - 다크 값이 생기기 전까지 `Info.plist`에 `UIUserInterfaceStyle = Light`를 넣어 라이트로 고정한다. `> 결정 필요`

#### 색상 토큰 (Variables 기준 16개 전체 / Foundations 라벨 13개)

- 변수 값은 Figma가 소문자로 반환한 그대로다. 라벨 값은 Foundations 프레임의 스와치 라벨 텍스트다.
- green/500, green/50, green/700은 **변수와 라벨이 다르다 → 충돌, 결정 필요**. 특히 변수에서 `green/500`과 `green/700`이 같은 #57c144다.
  - 흰 배경 대비: #57c144 **2.30:1**, #1EAA55 3.03:1, #13843F 4.77:1. `Text on white` 역할은 본문 텍스트라 4.5:1 이상이 필요하므로 변수 값(#57c144)으로는 기준 미달이다. 디자이너 확인 근거로 남긴다.

| Figma 변수 이름 | 변수 값 | 라벨 값 (역할) | colorset / Swift 심볼 제안 |
|---|---|---|---|
| green/500 | #57c144 | #1EAA55 (Primary) **충돌** | `Color.ecoPrimary` |
| green/50 | #edf8eb | #EDF8F0 (Tint) **충돌** | `Color.ecoPrimaryTint` |
| green/700 | #57c144 | #13843F (Text on white) **충돌** | `Color.ecoPrimaryText` |
| grey/900 | #1a1f1d | #1A1F1D (Text) | `Color.ecoTextPrimary` |
| grey/700 | #4e5753 | #4E5753 (Sub) | `Color.ecoTextSub` |
| grey/600 | #6b7470 | #6B7470 (Caption) | `Color.ecoTextCaption` |
| grey/400 | #b3bab6 | #B3BAB6 (Disabled) | `Color.ecoDisabled` |
| grey/200 | #e5e9e7 | #E5E9E7 (Border) | `Color.ecoBorder` |
| grey/100 | #f2f4f3 | #F2F4F3 (Divider) | `Color.ecoDivider` |
| grey/50 | #f8faf9 | #F8FAF9 (Surface) | `Color.ecoSurface` |
| red/500 | #d83b3b | #D83B3B (Rejected) | `Color.ecoRejected` |
| orange/700 | #b35f00 | #B35F00 (Pending) | `Color.ecoPending` |
| orange/500 | #f08c00 | #F08C00 (Pending icon) | `Color.ecoPendingIcon` |
| white | #ffffff | 라벨 없음 (primary 위 글자·아이콘) | `Color.ecoOnPrimary` |
| grey/300 | #c9d0cd | 라벨 없음 (역할 미확인) | 토큰 미등록 (역할 결정 필요) |
| fg/default | #1F2328 | 라벨 없음 (역할 미확인, 앱 토큰인지 불명) | 토큰 미등록. 다른 라이브러리(GitHub Primer `fg.default`와 같은 값) 변수일 가능성 |

컴포넌트 전용 시맨틱 colorset (값은 위 변수와 같아도 역할이 달라 따로 둔다):

| 출처 | 값 | 역할 | colorset / Swift 심볼 |
|---|---|---|---|
| grey/900 (`Toast` 243:131 배경) | #1A1F1D | 토스트 배경 | `Color.ecoToastBackground` |
| white (`Toast` 문구) | #FFFFFF | 토스트 위 글자 | `Color.ecoOnToast` |
| `Toast` icon/alert SVG stroke (변수 아님) | #FF9B9B | 토스트 아이콘 | `Color.ecoToastIcon` |
| grey/100 (교사 안내 309:54 원 배경) | #F2F4F3 | 원형 아이콘 배지 배경 | `Color.ecoBadgeBackground` |

### 타이포그래피
- **폰트: Noto Sans KR** (커스텀 폰트). 앱 번들에 포함하고 `Info.plist`의 `UIAppFonts`에 등록한다. PostScript 이름(예: `NotoSansKR-Bold`)은 폰트 파일 기준으로 확인 필요.
- **매핑 규칙**: Figma `{이름} · {size}/{lineHeight} {Weight}` → `EcoTextStyle` enum 케이스 1개 + `ViewModifier`. 뷰에서는 `.ecoFont(.title1)` 형태로만 쓴다.
  - size는 `Font.custom(_, size:, relativeTo:)`로 Dynamic Type 대응을 권장한다 (적용 여부는 결정 필요).
  - `.lineSpacing`은 폰트 자체 줄높이(`UIFont.lineHeight`) 위에 더해진다. `lineHeight - size`로 계산하지 않는다.
  - 규칙: `lineSpacing = max(0, lineHeight - UIFont(name: postScriptName, size: size).lineHeight)`. 값은 `EcoTextStyle`에서 계산하고 뷰에서 숫자를 쓰지 않는다.
- 예:
  - `Title 1 · 26/36 Bold` → `.ecoFont(.title1)` = Noto Sans KR Bold 26, lineHeight 36
  - `Body 1 · 17/25 Medium` → `.ecoFont(.body1)` = Medium 17, lineHeight 25
  - `Caption · 13/18 Bold` → `.ecoFont(.caption)` = Bold 13, lineHeight 18

#### 텍스트 스타일 (Foundations 7개 + 컴포넌트 4개)

| Figma 이름 | 값 | Swift 이름 제안 |
|---|---|---|
| Title 1 | 26/36 Bold | `.title1` |
| Title 2 | 22/31 Bold | `.title2` |
| Title 3 | 20/29 Bold | `.title3` |
| Body 1 | 17/25 Medium | `.body1` |
| Body 2 | 15/22 Regular | `.body2` |
| Sub | 14/20 Regular | `.sub` |
| Caption | 13/18 Bold | `.caption` |
| Button Large (컴포넌트) | 19/26 Bold | `.buttonLarge` |
| Button (컴포넌트) | 17/24 Bold | `.button` |
| Caption Regular (컴포넌트) | 13/18 Regular | `.captionRegular` |
| Toast 문구 (컴포넌트) | 15/22 Medium | `.body2Medium` |

- 모든 텍스트 스타일에 자간 -1%(size × -0.01)를 적용한다.
- Noto Sans KR 기본 줄높이(약 1.448em)보다 작은 lineHeight는 iOS에서 줄일 수 없어 Figma보다 줄마다 0.3~1.7pt 커진다(title1·title2·sub·caption·buttonLarge·button·captionRegular).


### 간격 / 라운드 / 레이아웃
- Figma 변수로 실제 존재하는 것(4개): `spacing/2` = 8, `spacing/6` = 24, `radius/app-button` = 16, `radius/app-card` = 24
- 라벨(Foundations 텍스트)의 스케일: 간격 4 · 8 · 12 · 16 · 20 · 24 (6개), 라운드 6 태그 · 12 타일·입력 · 16 버튼·박스 · 20 카드 · 999 칩 (5개). 변수는 이 중 일부만 정의돼 있다. `spacing/6` = 24는 라벨 스케일의 6번째와 일치하고, `spacing/2` = 8은 두 번째와 일치한다.
- **충돌:** 카드 라운드가 변수 `radius/app-card` = 24, 라벨 = 20 → 결정 필요.

| 용도 (라벨) | 변수 값 | 라벨 값 | Swift 이름 제안 |
|---|---|---|---|
| 태그 | 없음 | 6 | `Radius.tag` |
| 타일·입력 | 없음 | 12 | `Radius.tile` |
| 버튼·박스 | 16 (`radius/app-button`) | 16 | `Radius.button` |
| 카드 | 24 (`radius/app-card`) | 20 **충돌** | `Radius.card` |
| 칩 | 없음 | 999 | `Radius.chip` |

- `Spacing.xxxl` = 32: Foundations 스케일 밖. Figma `01 로그인 · 교사 계정 안내` (309:42) 하단 패딩 실측값으로 추가했다.
- Swift 제안: `Spacing.xs/sm/md/lg/xl/xxl/xxxl`, `Radius.tag/tile/button/card/chip` (이름은 제안). `spacing/N`은 N번째 단계(4부터)로 읽었으나 Figma에 단계 정의는 없어 추정이다.
- 화면 좌우 여백: 24 (라벨) → `Spacing.screenHorizontal`
- 버튼: 높이 56, 풀와이드, radius 16 (`Button/primary`, `Button/secondary`, `Button/disabled`)
- 리스트 행: 아이콘 타일 44, 본문 17(`body1`), 보조 14(`sub`)
- 화면 기준 프레임: 390 x 844 (iPhone 기준), 상태바 44, 상단바 56

### 아이콘
- Figma 컴포넌트명: `icon/cam`, `icon/check`, `icon/clock`, `icon/alert`, `icon/circle`, `icon/pin` (6개, 버튼 내 아이콘 20x20 확인)
- 상태 칩 매핑: `Chip/ok`(icon/check, 승인), `Chip/wait`(icon/clock, 검수 중), `Chip/rej`(icon/alert, 반려), `Chip/none`(icon/circle, 미제출)
- SF Symbol로 대체할지, 커스텀 에셋으로 넣을지는 **결정 필요** (Figma에서 벡터 원본 미확인).

### 미확인 / 결정 필요
- **충돌(결정 필요):** green/500·green/50·green/700 변수 값과 라벨 값이 다름, radius/app-card 24 vs 라벨 20. 어느 쪽이 최신인지 미확인.
- 텍스트 스타일은 `get_variable_defs` 응답에 없어 라벨 텍스트(size/lineHeight/weight)만 근거다. Figma Text Style 정의는 미조회.
- 변수 중 역할 미확인: `grey/300`, `fg/default`, `white`. 스와치 실제 fill도 조회하지 않았다.
- 다크모드 값 없음(변수에 모드 정보는 응답에 없음) → 결정 필요.
- Dynamic Type 적용 여부, 폰트 PostScript 이름, 아이콘 방식(SF Symbol vs 커스텀) 결정 필요.
- Swift 이름(`eco...`, `Spacing.*`, `Radius.*`)은 전부 제안이며 Figma에 없는 이름이다.

---

## 피해야 할 구현

### 구조

- View에서 `URLSession`/APIService를 직접 호출하기
- DTO를 ViewModel·View까지 전달하기 (Mapper로 Entity 변환 후 전달)
- Domain 레이어에서 `SwiftUI`, DTO, APIService import하기
- ViewModel 안에서 다른 ViewModel을 생성하기 (DIContainer에서 주입)
- 싱글톤(`static let shared`)으로 의존성 숨기기 (테스트에서 교체 불가)

### 코드

- 색상·폰트·간격을 `Color(red:...)`, `.padding(13)` 처럼 하드코딩하기 (디자인 토큰 사용)
- 다크 모드 값을 임의로 정하기 (디자인 토큰에 정의된 값만 사용)
- 강제 언래핑(`!`), `try!`, `as!` 남용하기 (`guard let` / `if let` / `do-catch`)
- 에러를 `catch { }` 로 삼키기 (사용자 안내 또는 로깅 필수)
- 토큰·키를 `UserDefaults`, 코드, 로그에 남기기 (사용자 토큰은 Keychain)
- xcconfig를 비밀 보관소로 쓰기
  - xcconfig 값은 빌드 시 Info.plist를 거쳐 앱 번들에 그대로 들어간다. 서버 URL 같은 환경 설정용으로만 쓴다.
  - `Secrets.xcconfig`는 `.gitignore`, `Secrets.xcconfig.example`을 커밋한다. 상위 xcconfig에서 `#include? "Secrets.xcconfig"`로 불러와 파일이 없어도 빌드가 깨지지 않게 한다.
- `print` 로 디버그 출력 남기기 (`os.Logger` 사용, 릴리즈에서 민감 정보 제외)

### 기능별

- **청소 인증 시간(08:00~08:10) · 당일 1회 판단을 클라이언트 시간만으로 하기**
  - 기기 시간은 사용자가 바꿀 수 있다. 최종 판단은 서버 응답 기준으로 한다.
  - 클라이언트 시간은 버튼 활성화 같은 UI 힌트로만 쓴다.
- **청소 인증에 앨범 사진 허용하기**
  - `PhotosPicker` 사용 금지. 카메라 촬영만 허용한다.
- **카메라 권한 거부 시 아무 반응 없이 두기**
  - `.denied` / `.restricted` 면 설정 앱 이동 안내(`UIApplication.openSettingsURLString`)를 보여준다.
- **AI 검수 결과를 앱에서 폴링으로 무한 반복하기**
  - `PROCESSING` 상태는 재진입/당겨서 새로고침 또는 푸시로 갱신한다. 폴링이 필요하면 횟수·간격 제한을 둔다. `> 결정 필요`
- **상태 값을 문자열로 비교하기**
  - `"APPROVED"` 문자열 비교 대신 enum(`ApplicationStatus`, `VerificationStatus`)으로 디코딩한다.
  - 알 수 없는 값이 오면 크래시 대신 `unknown` case로 처리한다.
- **누적 봉사시간을 클라이언트에서 재계산하기**
  - 10분 단위 누적 값은 서버 값을 그대로 표시한다. 표시 포맷만 클라이언트가 담당한다.
- **교사 계정으로 학생 화면 진입시키기**
  - 로그인 응답의 역할이 교사면 "웹에서 이용해 주세요" 안내만 보여주고 토큰을 저장하지 않는다.
- **로그아웃 시 토큰만 지우기**
  - Keychain 토큰, 메모리 캐시, 푸시 토큰 등록 해제를 함께 처리한다.
