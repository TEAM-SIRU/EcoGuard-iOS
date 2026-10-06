# EcoGuard-iOS
## 빌드 설정

앱 설정은 타깃 빌드 설정 → `EcoGuard/Resources/Info.plist`(`$(VAR)`)로 들어간다. 모두 앱 번들에 그대로 들어가므로 비밀 값(dataGSM client secret 등)은 넣지 않는다.

| 빌드 설정 | Info.plist 키 | 값 |
| --- | --- | --- |
| `ECO_API_HOST` | `EcoAPIBaseURL` (`https://` + 값) | `ecoguard.https.gsmsv.site` |
| `ECO_OAUTH_AUTHORIZE_HOST` | `EcoOAuthAuthorizeURL` (`https://` + 값) | `oauth.authorization.datagsm.kr/v1/oauth/authorize` |
| `ECO_OAUTH_CLIENT_ID` | `EcoOAuthClientID` | dataGSM 클라이언트 ID(공개 식별자) |
| `ECO_OAUTH_REDIRECT_URI` | `EcoOAuthRedirectURI` | `https://ecoguard.https.gsmsv.site/api/v1/auth/callback` — dataGSM·서버 등록값과 글자까지 같아야 한다 |
| `ECO_OAUTH_CALLBACK_URL` | `EcoOAuthCallbackURL` | `ecoguard://auth/callback` — 서버가 인가 코드를 붙여 302로 돌려보내는 앱 주소 |
| `ECO_WEB_ADMIN_HOST` | `EcoWebAdminURL` (`https://` + 값) | 미정(비우면 교사 안내 화면의 복사·공유 버튼을 숨김) |

- 로그인 흐름: 앱 → dataGSM 인가(`redirect_uri` = 서버 콜백) → 서버 `/api/v1/auth/callback` → 302 `ecoguard://auth/callback?code&state` → 앱이 state 확인 후 `POST /api/v1/auth/login`.
- 커스텀 스킴 콜백은 `ASWebAuthenticationSession`에 스킴을 넘겨 받으므로 `CFBundleURLTypes` 등록이 필요 없다.
- 빌드 설정(pbxproj)에서는 `https://`를 그대로 써도 되지만, xcconfig로 옮기면 `//`부터 주석이 된다. xcconfig에서는 `https:/$()/host/...`처럼 쓴다.

### Mock으로 실행

- Xcode: Scheme › Edit Scheme › Run › Arguments › Environment Variables에서 `ECO_USE_MOCK`(값 `1`)을 체크한다. DEBUG 빌드에서만 동작한다.
- 시뮬레이터 명령줄: `SIMCTL_CHILD_ECO_USE_MOCK=1 xcrun simctl launch <기기> com.teamsiru.ecoguard`
- 테스트 호스트로 실행될 때는 항상 Mock을 써서 실서버·키체인을 건드리지 않는다.

### 화면 둘러보기 (DEBUG)

- Debug 빌드 로그인 화면 위쪽 `화면 둘러보기` 버튼으로 탭 셸(홈 상태별)·각 흐름·상태 화면을 목록에서 연다. 서버 설정과 상관없이 Mock 저장소만 쓰며, Release 빌드에는 들어가지 않는다(`#if DEBUG`).
- 실행 인자 `-ScreenGallery`로 앱 시작 때 바로 열고, 항목 ID를 붙이면 그 화면을 연다: `xcrun simctl launch <기기> com.teamsiru.ecoguard -ScreenGallery shell.recruiting` (ID는 `ScreenGalleryCatalog.swift`).
- 항목 화면 오른쪽의 `✕` 버튼(끌어서 옮길 수 있음)이나 화면의 닫기·뒤로 버튼으로 목록에 돌아온다.
