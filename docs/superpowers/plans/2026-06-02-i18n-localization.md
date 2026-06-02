# ChalNa 전역 현지화(i18n) 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 앱 전체 사용자 노출 문자열(~210개)을 한국어(원본)+영어+일본어로 번역하고, 설정에 언어 선택(시스템/한국어/영어/일본어)을 추가해 **앱 재시작 없이 즉시 전환**되게 한다.

**Architecture:** 중앙 String Catalog 1개(`ChalNa/Resources/Localizable.xcstrings`, main 번들)에 한국어 원문을 키로 ko/en/ja 값을 담는다. SwiftUI `Text`/`String(localized:)`는 기본적으로 main 번들을 조회하므로 모듈에서 `bundle:` 인자 없이 자동 해석된다. 런타임 언어 전환은 `LanguageBundle`(Bundle 서브클래스 + `object_setClass(Bundle.main, …)`) 스위즐로 선택 언어 `.lproj`에 위임하고, `AppLanguageStore`(@Observable)가 환경 `\.locale`을 갱신해 라이브 재렌더한다.

**Tech Stack:** Swift 6, iOS 18, SwiftUI, TCA, Tuist, String Catalog(.xcstrings).

---

## 규칙 (Conventions — 모든 태스크에 적용)

이 규칙이 추출 단계의 일부 제안을 **덮어쓴다**(추출 에이전트는 최종 토폴로지를 모른 채 작성됨).

1. **`bundle:` 인자 금지.** 카탈로그는 main 번들에 있으므로 bare `Text("한국어")`는 자동 해석된다. `Text("…", bundle: .module)` 같은 변경은 하지 않는다.
2. **bare SwiftUI 리터럴 → 코드 변경 없음** (카탈로그 등록만):
   - `Text("한국어")`, `Button("한국어") { }`, `Label`, `.navigationTitle("한국어")`
   - `.accessibilityLabel("한국어")`, `.accessibilityHint("한국어")` (문자열 *리터럴*인 경우 — `LocalizedStringKey` 오버로드로 자동 현지화)
   - `confirmationDialog`/`alert`의 title·버튼·`message { Text("한국어") }` 리터럴
   - 이들에 `LocalizedStringKey(...)`나 `String(localized:)` 래핑을 **추가하지 않는다**.
3. **`String(localized:)`로 감쌀 대상 = String 타입 값만:**
   - computed `String` 프로퍼티 (예: `statusLine`, `confirmButtonTitle`, `ExportPhase.title`)
   - enum computed Korean 프로퍼티 (`koreanName`, `LabelKind.title/subtitle`)
   - reducer/state 에 저장되는 문자열 (`state.saveToast = …`, `AlertInfo(message: …)`)
   - `LocalizedError.errorDescription`
   - `String` 파라미터로 넘기는 한국어 리터럴 (예: `metaCell(label: "총 길이")` — `label`이 `String`)
4. **보간 문자열의 카탈로그 키 = 포맷 형태.** Swift가 `LocalizedStringKey`/`String(localized:)` 보간에서 방출하는 키와 정확히 일치해야 한다:
   - `Int` 보간 `\(x)` → `%lld`
   - `String` 보간 `\(s)` → `%@`
   - `Double`/`Float` 보간 → `%lf` (해당 시)
   - 예: `Text("\(films.count)편")` → 카탈로그 키 **`%lld편`**. `String(localized: "사진 로딩 중 · \(a)/\(b)")` → 키 **`사진 로딩 중 · %lld/%lld`**.
   - 단, `String(format: "%d CLIPS · %02d:%02d", …)`처럼 *이미 포맷 문자열*인 리터럴을 `String(localized:)`로 감싸는 경우엔 키가 그 리터럴 그대로다(`%d`/`%02d` 변환 없음 — 보간이 아니므로).
   - 보간 안에 한국어가 있으면(예: `\(isVideo ? "비디오" : "라이브 포토")`) 내부 문자열도 각각 `String(localized:)`로 감싸 키는 `%@`가 된다.
5. **브랜드 고정:** `Text("ChalNa")`/`Text("찰나")` → `Text(verbatim: "…")`. 모든 언어에서 동일 표기, 번역/추출 제외. (단 `"ChalNa"`가 다른 문장에 *포함*된 경우는 그 문장을 번역하되 브랜드 토큰은 보존.)
6. **`%.1f초`, `%02d:%02d` 같은 시계/숫자 포맷:** 숫자 자체는 로케일 중립. `초`/`s`/`秒`만 번역 대상.
7. **각 모듈 태스크 끝에서 빌드 그린 확인 + 커밋.** Tuist 리소스/Project 변경 후엔 `tuist generate` 먼저.

### 빌드/검증 명령

```bash
# Project/리소스 변경 후
cd /Users/ihchoi/Documents/Code/ChalNa && tuist generate

# 빌드 (시뮬레이터)
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# 테스트 (AppCore)
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test -only-testing:AppCoreTests
```

시각 검증은 `ios-build-run` 서브에이전트로 ko/en/ja 각각 실행해 스크린샷 확인.

---

## Task 0: Foundation — 언어 모델 · 스위즐 · 저장소 (AppCore)

**Files:**
- Create: `Modules/AppCore/Sources/AppLanguage.swift`
- Create: `Modules/AppCore/Sources/LanguageBundle.swift`
- Create: `Modules/AppCore/Sources/AppLanguageStore.swift`
- Test: `Modules/AppCore/Tests/AppLanguageStoreTests.swift`

- [ ] **Step 1: `AppLanguage.swift` 작성**

```swift
import Foundation

/// 앱 표시 언어. `system` 은 기기 언어를 따른다(오버라이드 없음).
public enum AppLanguage: String, CaseIterable, Sendable {
    case system
    case ko
    case en
    case ja

    /// 스위즐에 넘길 `.lproj` 코드. system 은 nil(오버라이드 없음).
    public var bundleCode: String? { self == .system ? nil : rawValue }

    /// 날짜/숫자 형식용 로케일.
    public var locale: Locale {
        switch self {
        case .system: return Locale.autoupdatingCurrent
        case .ko:     return Locale(identifier: "ko")
        case .en:     return Locale(identifier: "en")
        case .ja:     return Locale(identifier: "ja")
        }
    }

    /// 설정 화면 표시명. system 만 현지화, 나머지는 endonym 고정.
    public var displayName: String {
        switch self {
        case .system: return String(localized: "시스템 설정")
        case .ko:     return "한국어"
        case .en:     return "English"
        case .ja:     return "日本語"
        }
    }
}
```

- [ ] **Step 2: `LanguageBundle.swift` 작성 (스위즐)**

```swift
import Foundation

/// main 번들의 클래스를 이 서브클래스로 바꿔(`object_setClass`) 문자열 조회를
/// 선택 언어의 `.lproj` 로 위임한다. SwiftUI `Text` 와 `String(localized:)` 가
/// 모두 `Bundle.main.localizedString(forKey:value:table:)` 를 거치므로 둘 다 즉시 전환된다.
final class LanguageBundle: Bundle, @unchecked Sendable {
    /// 선택 언어의 `.lproj` 번들. nil 이면 시스템(super) 동작.
    nonisolated(unsafe) static var overrideBundle: Bundle?

    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let bundle = LanguageBundle.overrideBundle {
            return bundle.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}

public extension Bundle {
    /// 앱 언어를 설정한다. `code == nil` 이면 시스템 언어(오버라이드 해제).
    static func setLanguage(_ code: String?) {
        // main 번들의 클래스를 1회 교체(반복 호출 무해).
        object_setClass(Bundle.main, LanguageBundle.self)
        if let code, let path = Bundle.main.path(forResource: code, ofType: "lproj") {
            LanguageBundle.overrideBundle = Bundle(path: path)
        } else {
            LanguageBundle.overrideBundle = nil
        }
    }
}
```

- [ ] **Step 3: `AppLanguageStore.swift` 작성**

```swift
import Foundation
import Observation

/// 앱 표시 언어의 런타임 단일 출처. UserDefaults 에 영속하고, 변경 시
/// 스위즐(`Bundle.setLanguage`)을 갱신한다. RootView 가 환경으로 주입.
@Observable
@MainActor
public final class AppLanguageStore {
    public static let storageKey = "appLanguage"

    public private(set) var language: AppLanguage

    public init() {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey)
        self.language = raw.flatMap(AppLanguage.init(rawValue:)) ?? .system
        Bundle.setLanguage(language.bundleCode)
    }

    public func set(_ newValue: AppLanguage) {
        guard newValue != language else { return }
        language = newValue
        UserDefaults.standard.set(newValue.rawValue, forKey: Self.storageKey)
        Bundle.setLanguage(newValue.bundleCode)
    }

    /// 환경 `\.locale` 로 주입 → 날짜/숫자 형식 + 라이브 재렌더 트리거.
    public var locale: Locale { language.locale }

    /// 첫 페인트 전 ChalNaApp.init 에서 호출(인스턴스 없이 스위즐만 설치).
    public nonisolated static func applyStoredLanguageAtLaunch() {
        let raw = UserDefaults.standard.string(forKey: storageKey)
        let lang = raw.flatMap(AppLanguage.init(rawValue:)) ?? .system
        Bundle.setLanguage(lang.bundleCode)
    }
}
```

- [ ] **Step 4: 실패하는 테스트 작성** — `Modules/AppCore/Tests/AppLanguageStoreTests.swift`

```swift
import Testing
import Foundation
@testable import AppCore

@MainActor
struct AppLanguageStoreTests {
    private func freshDefaults() {
        UserDefaults.standard.removeObject(forKey: AppLanguageStore.storageKey)
    }

    @Test func defaultsToSystemWhenUnset() {
        freshDefaults()
        let store = AppLanguageStore()
        #expect(store.language == .system)
    }

    @Test func persistsAndRestoresSelection() {
        freshDefaults()
        let store = AppLanguageStore()
        store.set(.ja)
        #expect(store.language == .ja)
        #expect(UserDefaults.standard.string(forKey: AppLanguageStore.storageKey) == "ja")
        // 새 인스턴스가 저장값을 복원
        let restored = AppLanguageStore()
        #expect(restored.language == .ja)
    }

    @Test func localeMapping() {
        #expect(AppLanguage.en.locale.identifier == "en")
        #expect(AppLanguage.ja.locale.identifier == "ja")
        #expect(AppLanguage.system.bundleCode == nil)
        #expect(AppLanguage.ko.bundleCode == "ko")
    }

    @Test func displayNamesAreNonEmpty() {
        for lang in AppLanguage.allCases {
            #expect(!lang.displayName.isEmpty)
        }
    }
}
```

- [ ] **Step 5: `AppCoreTests` 타깃 존재 확인 / 없으면 추가**

`Project.swift` 에 `Module.unitTests(for: "AppCore")` 가 있는지 확인. 없으면 추가 후 `tuist generate`.

Run: `grep -n "AppCore" Project.swift`
Expected: AppCore framework + (필요시) 테스트 타깃 라인.

- [ ] **Step 6: 테스트 실행 → 통과 확인**

Run:
```bash
cd /Users/ihchoi/Documents/Code/ChalNa && tuist generate && \
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test -only-testing:AppCoreTests
```
Expected: PASS (4 tests).

- [ ] **Step 7: 커밋**

```bash
git add Modules/AppCore/Sources/AppLanguage.swift Modules/AppCore/Sources/LanguageBundle.swift Modules/AppCore/Sources/AppLanguageStore.swift Modules/AppCore/Tests/AppLanguageStoreTests.swift Project.swift
git commit -m "✨ feat(AppCore): AppLanguage·AppLanguageStore·LanguageBundle 스위즐 추가"
```

---

## Task 1: 앱 셸 와이어링 — 부팅 적용 · 환경 주입 · 네비게이션

**Files:**
- Modify: `ChalNa/Sources/ChalNaApp.swift`
- Modify: `ChalNa/Sources/App/RootView.swift`
- Modify: `ChalNa/Sources/App/AppFeature.swift`
- Modify: `Modules/AppCore/Sources/AppRouter.swift`

- [ ] **Step 1: ChalNaApp 에 부팅 시 언어 적용**

`ChalNa/Sources/ChalNaApp.swift` 상단 import 에 `import AppCore` 추가(없으면). `init()` 의 `prepareDependencies { … }` 블록 닫힌 직후(현재 line 27 뒤)에 추가:

```swift
        // 저장된 앱 언어를 첫 페인트 전에 적용(스위즐 설치).
        AppLanguageStore.applyStoredLanguageAtLaunch()
```

- [ ] **Step 2: RootView 에 store + 환경 주입**

`ChalNa/Sources/App/RootView.swift` line 19(`@State private var session = EditSession()`) 다음에 추가:

```swift
    @State private var languageStore = AppLanguageStore()
```

`.environment(session)`(line 35) 다음에 추가:

```swift
        .environment(languageStore)
        .environment(\.locale, languageStore.locale)
```

`import AppCore` 가 이미 있는지 확인(AppRouter/EditSession 사용 중이므로 있음).

- [ ] **Step 3: AppRouter 에 language 라우트 추가**

`Modules/AppCore/Sources/AppRouter.swift` `Route` enum(line 13 `case support` 다음)에 추가:

```swift
    case language
```

- [ ] **Step 4: AppFeature 에 language 경로 + 인텐트 추가**

`ChalNa/Sources/App/AppFeature.swift`:
- `Path` enum(line 52 `case support(SupportFeature)` 다음)에:
  ```swift
        case language(LanguageFeature)
  ```
- `Action` enum(line 40 `case routerPushedSupport` 다음)에:
  ```swift
        case routerPushedLanguage
  ```
- Reduce 의 switch(`routerPushedSupport` 처리 다음)에:
  ```swift
            case .routerPushedLanguage:
                state.path.append(.language(LanguageFeature.State()))
                return .none
  ```
- 파일 상단 import 에 `SettingsFeature` 가 이미 있으면(LabelSettingsFeature 사용 중) 그대로. `LanguageFeature` 는 SettingsFeature 모듈에 추가될 예정(Task 2).

- [ ] **Step 5: RootView.wireRouterHandlers + destinationView 에 language 처리**

`RootView.swift` `wireRouterHandlers()` 의 push switch(`.support` 다음)에:

```swift
            case .language:
                store.send(.routerPushedLanguage)
```

`destinationView(for:)` switch(grep 으로 위치 확인 — `case .support` 미러)에:

```swift
            case .language(let childStore):
                LanguageView(store: childStore)
```

Run: `grep -n "destinationView\|case .support" ChalNa/Sources/App/*.swift`
Expected: destinationView 의 기존 case 들 위치 확인.

> 이 단계는 `LanguageFeature`/`LanguageView`(Task 2)가 있어야 컴파일된다. Task 2 와 함께 빌드한다.

---

## Task 2: 설정 — LanguageFeature · LanguageView · menuRow

**Files:**
- Create: `Modules/SettingsFeature/Sources/LanguageFeature.swift`
- Create: `Modules/SettingsFeature/Sources/LanguageView.swift`
- Modify: `Modules/SettingsFeature/Sources/SettingsView.swift`

- [ ] **Step 1: `LanguageFeature.swift` (얇은 셸)**

```swift
import ComposableArchitecture

@Reducer
public struct LanguageFeature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
        public init() {}
    }

    public enum Action: Equatable {}

    public var body: some ReducerOf<Self> {
        EmptyReducer()
    }
}
```

- [ ] **Step 2: `LanguageView.swift` (LabelSettingsView 패턴 미러)**

```swift
import SwiftUI
import ComposableArchitecture
import AppCore
import DesignSystem

public struct LanguageView: View {
    @Environment(AppRouter.self) private var router
    @Environment(AppLanguageStore.self) private var languageStore
    let store: StoreOf<LanguageFeature>

    public init(store: StoreOf<LanguageFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
                .chalNaHeaderBar(scrollProgress: 1)
                .zIndex(1)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(AppLanguage.allCases.enumerated()), id: \.element) { index, lang in
                        if index > 0 {
                            Divider().overlay(ChalNaColor.Gray.g100)
                        }
                        languageRow(lang)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                        .strokeBorder(ChalNaColor.Gray.g100, lineWidth: 1)
                )
                .padding(.horizontal, 24)
                .padding(.top, 12)
            }
        }
        .chalNaScreen()
    }

    private func languageRow(_ lang: AppLanguage) -> some View {
        Button {
            languageStore.set(lang)
        } label: {
            HStack(spacing: 12) {
                Text(lang.displayName)   // displayName 은 이미 해석된 String → verbatim 표시
                    .font(ChalNaTypography.krBody(ChalNaTypography.Size.body, weight: .regular))
                    .foregroundColor(ChalNaColor.ink)
                Spacer()
                if lang == languageStore.language {
                    ChalNaIcon(.check, size: 20)
                        .foregroundColor(ChalNaColor.coral)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        ZStack {
            Text("언어")
                .font(ChalNaTypography.title(ChalNaTypography.Size.h2, weight: .semibold))
                .foregroundColor(ChalNaColor.ink)
            HStack {
                Button { router.pop() } label: {
                    ChalNaIcon(.chevronLeft, size: 22)
                        .foregroundColor(ChalNaColor.ink)
                }
                .buttonStyle(.chalNaHeaderAction)
                .accessibilityLabel("뒤로")
                Spacer()
            }
        }
    }
}
```

> `Text(lang.displayName)`: `displayName` 은 `String` 이므로 `Text` 의 verbatim 오버로드가 선택돼 *이미 해석된* 문자열을 그대로 그린다(system 은 `String(localized:)` 로 해석됨). 의도한 동작.
> `ChalNaColor.coral`/`.chalNaHeaderAction`/`chalNaHeaderBar`/`ChalNaIcon(.check)` 가 실제 API 인지 빌드로 확인(없으면 LabelSettingsView 에서 쓰는 동일 토큰으로 교체).

- [ ] **Step 3: SettingsView 에 언어 menuRow 추가**

`Modules/SettingsFeature/Sources/SettingsView.swift` 에서 라벨 menuRow 닫힘(line 26) 다음, 기존 `Divider()`(line 27) 앞에 삽입:

```swift
                    Divider().overlay(ChalNaColor.Gray.g100)
                    menuRow(title: "언어", subtitle: "앱 표시 언어를 선택하세요") {
                        router.push(.language)
                    }
```

(결과: 라벨 → 언어 → 문의·신고 순. 중복 Divider 없도록 기존 라인 유지/정리.)

- [ ] **Step 4: 빌드 (Task 1 + 2 함께)**

Run:
```bash
cd /Users/ihchoi/Documents/Code/ChalNa && tuist generate && \
xcodebuild -workspace ChalNa.xcworkspace -scheme ChalNa \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 5: 카탈로그 스캐폴드 — `ChalNa/Resources/Localizable.xcstrings` 생성**

아직 번역 항목이 없어도 빈 카탈로그 + foundation 문자열을 만든다. 파일 내용:

```json
{
  "sourceLanguage" : "ko",
  "strings" : {
    "시스템 설정" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "System" } },
        "ja" : { "stringUnit" : { "state" : "translated", "value" : "システム設定" } }
      }
    },
    "언어" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Language" } },
        "ja" : { "stringUnit" : { "state" : "translated", "value" : "言語" } }
      }
    },
    "앱 표시 언어를 선택하세요" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Choose the app display language" } },
        "ja" : { "stringUnit" : { "state" : "translated", "value" : "アプリの表示言語を選択してください" } }
      }
    },
    "뒤로" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Back" } },
        "ja" : { "stringUnit" : { "state" : "translated", "value" : "戻る" } }
      }
    }
  },
  "version" : "1.0"
}
```

(이후 모듈 태스크에서 `strings` 객체에 항목을 누적한다. 키는 한국어 원문/포맷 문자열. ko 값은 키 자체이므로 별도 등재 불필요.)

- [ ] **Step 6: Project.swift Info.plist 현지화 키 추가**

`Project.swift` 앱 타깃 `infoPlist` 배열(UIAppFonts 다음, line 131 앞)에 추가:

```swift
                    "CFBundleDevelopmentRegion": "ko",
                    "CFBundleLocalizations": ["ko", "en", "ja"],
```

- [ ] **Step 7: 빌드 + 라이브 전환 시각 검증**

`tuist generate` 후 `ios-build-run` 으로 실행:
1. 설정 → 언어 진입, 4개 옵션 + 현재 체크 표시 확인.
2. 일본어 선택 → 설정/언어 화면 헤더("설정"/"언어")가 즉시 일본어로 바뀌는지(재시작 없이) 확인. 네비게이션 유지 확인.
3. 앱 종료 후 재실행 → 일본어 유지 확인.
4. 시스템으로 되돌리면 기기 언어로 복귀 확인.

> 일부 화면이 즉시 갱신되지 않으면(관찰 누락) RootView 의 `destination` 컨텐츠에 `.id(languageStore.language)` 를 보조로 추가(네비게이션 루트가 아닌 leaf 에). 단 스택 리셋을 유발하지 않는 위치인지 확인.

- [ ] **Step 8: 커밋**

```bash
git add ChalNa/ Modules/AppCore/Sources/AppRouter.swift Modules/SettingsFeature/Sources/LanguageFeature.swift Modules/SettingsFeature/Sources/LanguageView.swift Modules/SettingsFeature/Sources/SettingsView.swift Project.swift
git commit -m "✨ feat(i18n): 설정 언어 선택 + 즉시 전환 + 중앙 카탈로그 스캐폴드"
```

---

## 모듈별 마이그레이션 (Task 3–11)

각 모듈 태스크의 공통 절차:
1. **transformTasks** 의 코드 변경 적용(아래 각 표/블록).
2. **catalog 항목 추가**: 해당 모듈 표의 (키, en, ja[, plural])를 `Localizable.xcstrings` `strings` 에 추가. 형식은 Appendix A.
3. **빌드** 그린 확인.
4. **시각 검증**: ko/en/ja 로 해당 화면 확인(`ios-build-run`).
5. **커밋**: `🌐 i18n(<Module>): 문자열 현지화`.

> 표 범례: ⚠ = 검수 필요(번역 불확실). "키"는 카탈로그 키(보간은 `%lld`/`%@` 포맷 형태). ko 값 = 키.

---

### Task 3: Models

**transformTasks** (`String(localized:)` 래핑):

- `Modules/Models/Sources/LabelSettings.swift` — `LabelPosition.koreanName`, `LabelKind.title`, `.subtitle`, `.sampleText` 각 `return "…"` → `return String(localized: "…")`.
- `Modules/Models/Sources/Film.swift` — `metaLabel`:
  ```swift
  // before
  return String(format: "%d CLIPS · %02d:%02d", clipCount, m, s)
  // after
  return String(format: String(localized: "%d CLIPS · %02d:%02d"), clipCount, m, s)
  ```
  (보간 아님 — 키는 `%d CLIPS · %02d:%02d` 그대로.)
- `Modules/Models/Sources/Clip.swift` — `durationSecondsLabel`:
  ```swift
  // before
  String(format: "%.1fs", duration)
  // after
  String(format: String(localized: "%.1fs"), duration)
  ```
  `durationClockLabel`(`%02d:%02d`) — **변경 없음**(숫자 전용, 로케일 중립).
- `Modules/Models/Sources/SampleData.swift` — `filmTitle = "찰나의 순간 엮는 중"` → `= String(localized: "찰나의 순간 엮는 중")`. Clip `locationNote` 리터럴들 → 각 `String(localized: "…")`.

**카탈로그 항목:**

| 키 | EN | JA | ⚠ |
|---|---|---|---|
| 좌측 상단 | Top left | 左上 | |
| 중앙 상단 | Top center | 上中央 | |
| 우측 상단 | Top right | 右上 | |
| 좌측 중앙 | Middle left | 左中央 | |
| 정중앙 | Center | 中央 | |
| 우측 중앙 | Middle right | 右中央 | |
| 좌측 하단 | Bottom left | 左下 | |
| 중앙 하단 | Bottom center | 下中央 | |
| 우측 하단 | Bottom right | 右下 | |
| 시각 라벨 | Time label | 時刻ラベル | ⚠ |
| 날짜 라벨 | Date label | 日付ラベル | ⚠ |
| `%d CLIPS · %02d:%02d` | `%d CLIPS · %02d:%02d` | `%d クリップ · %02d:%02d` | ⚠ |
| `%.1fs` | `%.1fs` | `%.1fs` | |
| 찰나의 순간 엮는 중 | Weaving moments of ChalNa | ChalNaの瞬間を紡ぐ | ⚠ |
| 협재 해변 | Hyeopjae Beach | ヒョプジェビーチ | ⚠ |
| 중문 노을 | Jungmun Sunset | チュンムン夕焼け | ⚠ |
| 한라산 입구 | Hallasan Entrance | ハルラ山入口 | ⚠ |
| `소길리 · 오후 4시` | `Sogil-ri · 4 PM` | `ソギルリ · 午後4時` | ⚠ |
| 풀밭 | Grassy field | 草原 | |
| 숲길 | Forest trail | 森の道 | |
| 저녁 노을 | Evening sunset | 夕焼け | |
| 카페 | Cafe | カフェ | |

> `HH:mm`/`yyyy/MM/dd`/`12:30`/`2026/04/05`(LabelKind.subtitle/sampleText)는 형식 예시 — 전 언어 동일, ko=en=ja 동값으로 등재(또는 미등재 시 ko 폴백).

---

### Task 4: HomeFeature

**transformTasks:**
- `HomeView.swift` `Text("ChalNa")`(헤더 브랜드) → `Text(verbatim: "ChalNa")`.
- `.accessibilityLabel("설정")`, `.accessibilityLabel("새 Vlog 만들기")` — **변경 없음**(리터럴 자동 현지화). 카탈로그 등록만.
- 그 외 `Text("…")` 전부 변경 없음.

**카탈로그 항목:**

| 키 | EN | JA | ⚠ |
|---|---|---|---|
| 설정 | Settings | 設定 | |
| 오늘 찰나의 순간들 | Today's ChalNa moments | 今日のChalNaのひととき | ⚠ |
| `Live Photo와 짧은 영상을 촬영일 순서로 이어붙여\n한 편의 필름처럼 기록해요.` | `Connect Live Photos and short videos in capture order\nto record them like a single film.` | `ライブフォトと短い動画を撮影日順につなぎ、\n一本のフィルムのように記録します。` | ⚠ |
| 새 Vlog 만들기 | Create new Vlog | 新しいVlogを作成 | |
| 최근 필름 | Recent films | 最近のフィルム | |
| `%lld편` (← `\(films.count)편`) | one: `%lld film` / other: `%lld films` | `%lld本` | |
| 아직 만든 필름이 없어요. | No films yet. | まだフィルムがありません。 | |
| 첫 Vlog를 시작해보세요. | Start your first Vlog. | 最初のVlogを始めましょう。 | |

> `%lld편` 은 영어 plural variation 필요(Appendix A 참고). `ChalNa` 헤더는 verbatim → 카탈로그 미등재.

---

### Task 5: MediaPickerFeature

**transformTasks** (computed `String` 프로퍼티 — 각 프로퍼티 body 안의 *모든* 한국어 `return "…"`/`return "…\(x)…"` 을 `String(localized:)` 로 감쌈. bare `Text`/alert 리터럴은 손대지 않음):
- `MediaPickerView.swift` 의 다음 5개 computed `String` 프로퍼티의 각 return 을 래핑: `photoStatusMessage`, `confirmButtonTitle`, `photoLauncherTitle`, `photoLauncherSubtitle`, `photoEmptyMessage`. 예시(`confirmButtonTitle`):
  ```swift
  // before
  if selectedCount == 0 { return "선택 후 다음" }
  // after
  if selectedCount == 0 { return String(localized: "선택 후 다음") }
  // ... 그리고 return "Timeline으로 (\(selectedCount))" → return String(localized: "Timeline으로 (\(selectedCount))")
  ```
- 보간 내부 한국어: `\(asset.kind == .video ? "비디오" : "라이브 포토")를 선택에서 빼요` →
  ```swift
  String(localized: "\(asset.kind == .video ? String(localized: "비디오") : String(localized: "라이브 포토"))를 선택에서 빼요")
  ```
  (키: `%@를 선택에서 빼요`)
- `MediaPreviewSheet.swift` `String(format: "%.1f초", …)` → `String(format: String(localized: "%.1f초"), …)`.
- bare `Text`/alert/`.accessibilityLabel` 리터럴 — 변경 없음.

**카탈로그 항목** (발췌·전부 등재):

| 키 | EN | JA | ⚠ |
|---|---|---|---|
| Live Photo 권한이 필요해요 | Live Photo permission required | Live Photoの権限が必要です | |
| Live Photo를 영상으로 사용하려면 사진 보관함 접근 권한이 필요해요. | To use Live Photo as video, photo library access is required. | Live Photoを動画として使うには写真ライブラリへのアクセス許可が必要です。 | |
| 확인 | OK | OK | |
| 취소 | Cancel | キャンセル | |
| 미디어 선택 | Select media | メディアを選択 | |
| `TITLE · 이번 찰나 모음집의 제목` | `TITLE · Title of this ChalNa collection` | `TITLE · このChalNaコレクションのタイトル` | ⚠ |
| `찰나의 순간을\n천천히 골라보세요.` | `Pick your ChalNa moments\nslowly and carefully.` | `ChalNaの瞬間を\nゆっくり選んでください。` | ⚠ |
| `Live Photo와 짧은 영상을 불러올 수 있어요.\nLive Photo는 내부의 영상 부분을 사용합니다.` | `You can import Live Photos and short videos.\nLive Photo uses its internal video portion.` | `Live Photoと短い動画をインポートできます。\nLive Photoは内部の動画部分を使用します。` | |
| 예: 제주도, 우리의 봄 | e.g. Jeju, our spring | 例：済州島、私たちの春 | |
| 비워두면 나중에 자동으로 채워져요. | Leave empty to auto-fill later. | 空欄のままだと後で自動入力されます。 | |
| 사진을 불러오는 중 | Loading photos | 写真を読み込み中 | |
| Live Photo와 영상을 정성껏 추출하고 있어요 | Carefully extracting Live Photos and videos | Live Photoと動画を丁寧に抽出しています | |
| `선택한 미디어 · %lld` (← `\(selectedAssets.count)`) | `Selected media · %lld` | `選択したメディア · %lld` | |
| 사진을 불러오는 중이에요 | Loading photos | 写真を読み込んでいます | |
| 뒤로 | Back | 戻る | |
| Dev 미디어 소스 | Dev media source | Devメディアソース | |
| 번들 fixture로 실제 export까지 확인 | Verify export with bundled fixtures | バンドルfixtureでエクスポートまで確認 | |
| `%lld개 fixture 선택됨` | `%lld fixtures selected` | `%lld個のfixtureを選択` | |
| Dev 미디어를 준비하고 있어요 | Preparing dev media | Devメディアを準備中です | |
| `DEV FIXTURES · %lld` | `DEV FIXTURES · %lld` | `DEV FIXTURES · %lld` | |
| 이번 필름의 제목 | This film's title | このフィルムのタイトル | |
| `%lld개 중 %lld개 완료` | `%lld of %lld done` | `%lld個中%lld個完了` | |
| 탭하면 미리보기가 열려요 | Tap to open preview | タップでプレビューを開きます | |
| 선택에서 제외 | Remove from selection | 選択から除外 | |
| `%@를 선택에서 빼요` | `Remove %@ from selection` | `%@を選択から外します` | |
| 비디오 | Video | ビデオ | |
| 라이브 포토 | Live Photo | ライブフォト | ⚠ |
| 사진 | Photo | 写真 | |
| 종류 확인 중 | Checking type | タイプを確認中 | |
| 사진 권한 선택 | Choose photo permissions | 写真の権限を選択 | |
| 사진 권한 열기 | Open photo permissions | 写真の権限を開く | |
| 사진 추가하기 | Add photos | 写真を追加 | |
| 다시 고르기 | Choose again | 選び直す | |
| 먼저 권한 범위를 고른 뒤 선택해요 | Choose permission scope first, then select | まず権限の範囲を選んでから選択します | |
| 설정에서 사진 접근을 허용해 주세요 | Allow photo access in Settings | 設定で写真へのアクセスを許可してください | |
| 선택한 사진을 불러오는 중 | Loading selected photos | 選択した写真を読み込み中 | |
| Live Photo와 짧은 영상만 가져올 수 있어요 | Only Live Photos and short videos can be imported | Live Photoと短い動画のみインポートできます | |
| `%lld개 선택됨 · 탭해서 추가해요` | `%lld selected · Tap to add` | `%lld個選択 · タップして追加` | |
| 먼저 사진 권한 범위를 선택해 주세요 | Please choose a photo permission scope first | まず写真の権限範囲を選択してください | |
| 사진 권한을 허용해야 Live Photo 영상을 만들 수 있어요 | Photo permission is required to create Live Photo videos | Live Photo動画の作成には写真の権限が必要です | |
| 선택한 사진을 불러오고 있어요 | Loading selected photos | 選択した写真を読み込んでいます | |
| 아직 선택한 사진이 없어요. 위 카드를 눌러 골라보세요. | No photos selected yet. Tap the card above to choose. | まだ写真が選択されていません。上のカードをタップして選んでください。 | |
| 사진 권한을 허용해야 Live Photo 영상을 사용할 수 있어요. | Photo permission is required to use Live Photo videos. | Live Photo動画を使うには写真の権限が必要です。 | |
| 먼저 사진 권한 범위를 선택해 주세요. | Please choose a photo permission scope first. | まず写真の権限範囲を選択してください。 | |
| 선택한 항목을 불러오지 못했어요. 다시 선택해 주세요. | Failed to load the selected items. Please select again. | 選択項目を読み込めませんでした。もう一度選択してください。 | |
| `사진 로딩 중 · %lld/%lld` | `Loading photos · %lld/%lld` | `写真を読み込み中 · %lld/%lld` | |
| 선택 후 다음 | Select, then continue | 選択して次へ | |
| 원본 확인 필요 | Original needs checking | 元ファイルの確認が必要 | |
| 사진 로딩 중 | Loading photos | 写真を読み込み中 | |
| `Timeline으로 (%lld)` | `To Timeline (%lld)` | `Timelineへ (%lld)` | |
| `%.1f초` | `%.1f sec` | `%.1f秒` | |
| 재생 중. 탭하면 멈춰요 | Playing. Tap to pause. | 再生中。タップで一時停止します。 | |
| 일시정지. 탭하면 재생돼요 | Paused. Tap to play. | 一時停止中。タップで再生します。 | |
| 영상을 불러오지 못했어요 | Failed to load video | 動画を読み込めませんでした | |
| 영상을 탭하면 재생/일시정지돼요. | Tap the video to play/pause. | 動画をタップで再生／一時停止します。 | |
| 원본 영상이 없는 미디어예요. | This media has no original video. | 元の動画がないメディアです。 | |
| 불러오는 중 | Loading | 読み込み中 | |
| 썸네일 불러오기 실패 | Thumbnail load failed | サムネイル読み込み失敗 | |
| 영상 추출 실패 | Video extraction failed | 動画抽出失敗 | |
| 영상 X | Video X | 動画 X | ⚠ |
| `PICK · YOUR CHALNA` | `PICK · YOUR CHALNA` | `PICK · YOUR CHALNA` | |

---

### Task 6: TimelineFeature

**transformTasks:**
- `TimelineView.swift` `headerTitle` computed: `store.isPlaying ? "재생 중" : "편집"` → 각 `String(localized:)`.
- `FilmStripCollectionView.swift` `accessibilityLabel(for:index:isCurrent:)`:
  ```swift
  let kind = clip.kind == .live ? String(localized: "라이브 포토") : String(localized: "비디오")
  let selected = isCurrent ? String(localized: ", 선택됨") : ""
  return String(localized: "\(index + 1)번째 클립, \(kind), \(clip.durationSecondsLabel)\(selected)")
  ```
  (키: `%lld번째 클립, %@, %@%@`)
- 그 외 bare `Text`/`.accessibilityLabel`/`.accessibilityHint`/confirmationDialog/custom action 이름 리터럴 — 변경 없음.
- `AutoLabelsOverlay.swift` 의 날짜/시간 포매터는 **Task 9(영상 오버레이)**에서 다룬다(여기선 손대지 않음).

**카탈로그 항목:**

| 키 | EN | JA | ⚠ |
|---|---|---|---|
| 클립을 삭제할까요? | Delete this clip? | このクリップを削除しますか？ | |
| 삭제 | Delete | 削除 | |
| 취소 | Cancel | キャンセル | |
| 삭제한 클립은 현재 타임라인에서 제거됩니다. | The deleted clip will be removed from the current timeline. | 削除したクリップは現在のタイムラインから取り除かれます。 | |
| 뒤로 | Back | 戻る | |
| 재생 중 | Playing | 再生中 | |
| 편집 | Edit | 編集 | |
| `▶ NOW PLAYING · CLIP %lld` | `▶ NOW PLAYING · CLIP %lld` | `▶ NOW PLAYING · CLIP %lld` | ⚠ |
| `TIMELINE · %lld CLIPS` | `TIMELINE · %lld CLIPS` | `TIMELINE · %lld CLIPS` | ⚠ |
| `총 ` | `Total ` | `合計 ` | |
| 클립을 탭해 편집 · 길게 눌러서 끌어 이동 | Tap a clip to edit · long-press and drag to reorder | クリップをタップで編集 · 長押しでドラッグして並べ替え | |
| 라벨 | Label | ラベル | ⚠ |
| 저장 | Save | 保存 | |
| 자막 입력 | Enter subtitle | 字幕を入力 | |
| 크기 | Size | サイズ | |
| 회전 | Rotate | 回転 | |
| 선택한 클립을 삭제합니다. | Deletes the selected clip. | 選択したクリップを削除します。 | |
| 이전 클립 | Previous clip | 前のクリップ | |
| 다음 클립 | Next clip | 次のクリップ | |
| 일시정지 | Pause | 一時停止 | |
| 재생 | Play | 再生 | |
| 현재 클립 재생 상태를 전환합니다. | Toggles playback of the current clip. | 現在のクリップの再生状態を切り替えます。 | |
| 선택하려면 두 번 탭하고, 순서를 바꾸려면 사용자 동작을 사용하세요. | Double-tap to select, or use custom actions to reorder. | ダブルタップで選択、カスタム操作で並べ替えできます。 | |
| 앞으로 이동 | Move forward | 前へ移動 | |
| 뒤로 이동 | Move backward | 後ろへ移動 | |
| `%@ 촬영일` (← `\(dayKey) 촬영일`) | `Captured %@` | `%@ 撮影日` | |
| 라이브 포토 | Live Photo | ライブフォト | ⚠ |
| 비디오 | Video | ビデオ | |
| `, 선택됨` | `, selected` | `、選択済み` | |
| `%lld번째 클립, %@, %@%@` | `Clip %lld, %@, %@%@` | `%lld番目のクリップ、%@、%@%@` | |
| `%lld번째 위치로 이동했습니다.` | `Moved to position %lld.` | `%lld番目の位置に移動しました。` | |

---

### Task 7: ExportFeature

**transformTasks:**
- `ExportFeature.swift`: `ExportPhase.title` 각 `return "…"` → `String(localized:)`. `state.saveToast = "…"` 3곳(성공/거부/실패) → `String(localized:)`(실패는 `"저장 실패 — \(msg)"` → 키 `저장 실패 — %@`).
- `ExportView.swift`: `statusLabelLeft`, `statusLine` computed `String` → 각 `String(localized:)`. `.accessibilityValue("\(Int(store.progress * 100))퍼센트")` → `String(localized: "\(Int(store.progress * 100))퍼센트")`(키 `%lld퍼센트`).
- bare `Text(...)`/`Button("...")`/`.accessibilityLabel("...")`(예: 재생 닫기, 완성된 영상 재생, 공유하기, 저장하기, 다른 영상 만들기, 홈으로 →, 다시 시도, 편집으로 돌아가기, 내보낼 클립이 없어요, 내보내기 진행률, 잠깐만 기다려주세요) — **변경 없음**.

**카탈로그 항목:**

| 키 | EN | JA | ⚠ |
|---|---|---|---|
| 저장 중 | Saving | 保存中 | |
| 완성 | Done | 完成 | |
| 저장 실패 | Save failed | 保存失敗 | |
| `사진 앱에 저장됐어요 ✦` | `Saved to Photos ✦` | `写真アプリに保存しました ✦` | |
| 사진 보관함 접근 권한이 필요해요 | Photo library access is required | 写真ライブラリへのアクセス許可が必要です | |
| `저장 실패 — %@` | `Save failed — %@` | `保存失敗 — %@` | |
| 재생 닫기 | Close playback | 再生を閉じる | |
| 완성된 영상 재생 | Play finished video | 完成した動画を再生 | |
| 내보낼 클립이 없어요 | No clips to export | エクスポートするクリップがありません | |
| 내보내기 진행률 | Export progress | エクスポートの進捗 | |
| `%lld퍼센트` | `%lld percent` | `%lldパーセント` | |
| `EXPORT · IN PROGRESS` | `EXPORT · IN PROGRESS` | `EXPORT · IN PROGRESS` | |
| `EXPORT · COMPLETE` | `EXPORT · COMPLETE` | `EXPORT · COMPLETE` | |
| `EXPORT · FAILED` | `EXPORT · FAILED` | `EXPORT · FAILED` | |
| Vlog를 엮는 중… Live Photo의 영상 부분을 자동으로 추출해 이어 붙여요. | Weaving your Vlog… automatically extracting and stitching the video parts of your Live Photos. | Vlogを編んでいます… Live Photoの動画部分を自動で抽出してつなぎます。 | ⚠ |
| 필름이 완성되었어요. 공유하거나 사진 보관함에 저장할 수 있어요. | Your film is ready. You can share it or save it to your photo library. | フィルムが完成しました。共有や写真ライブラリへの保存ができます。 | |
| 저장 중 문제가 발생했어요. | Something went wrong while saving. | 保存中に問題が発生しました。 | |
| 잠깐만 기다려주세요 | Please wait a moment | 少々お待ちください | |
| 공유하기 | Share | 共有 | |
| 저장 중… | Saving… | 保存中… | |
| 저장하기 | Save | 保存 | |
| 다른 영상 만들기 | Create another | 別の動画を作成 | |
| `홈으로 →` | `Home →` | `ホームへ →` | |
| 다시 시도 | Try again | もう一度試す | |
| 편집으로 돌아가기 | Back to editing | 編集に戻る | |

---

### Task 8: FilmDetailFeature

**transformTasks:**
- `FilmDetailView.swift` `metaCell(label:value:)` 호출의 `label` 리터럴(String 파라미터):
  ```swift
  metaCell(label: String(localized: "총 길이"), value: …)
  metaCell(label: String(localized: "클립"), value: "\(film.clipCount)")
  metaCell(label: String(localized: "Live"), value: "\(film.liveCount)")
  metaCell(label: String(localized: "Video"), value: "\(videoCount)")
  ```
- 날짜 포맷(`ko_KR` 고정 DateFormatter)은 **Task 10** 에서.
- bare `Text(...)`/`Button(...)`/alert/`.accessibilityLabel` 리터럴 — 변경 없음. (추출이 제안한 `bundle: .module`·`Text(.., bundle:)` 는 **적용 안 함**.)

**카탈로그 항목:**

| 키 | EN | JA | ⚠ |
|---|---|---|---|
| 뒤로 | Back | 戻る | |
| 필름 정보 | Film details | フィルム情報 | |
| 필름을 삭제할까요? | Delete this film? | このフィルムを削除しますか？ | |
| 삭제 | Delete | 削除 | |
| 취소 | Cancel | キャンセル | |
| 이 필름과 영상 파일이 모두 사라져요. 되돌릴 수 없어요. | This film and its video file will be permanently deleted. This can't be undone. | このフィルムと動画ファイルが完全に削除されます。元に戻せません。 | |
| 총 길이 | Duration | 合計時間 | |
| 클립 | Clips | クリップ | ⚠ |
| Live | Live | ライブ | ⚠ |
| Video | Video | ビデオ | ⚠ |
| 영상 파일을 찾을 수 없어요 | Video file not found | 動画ファイルが見つかりません | |
| 앱을 다시 설치하셨거나 파일이 삭제되었어요. 재생과 공유는 불가능하고, 라이브러리에서 항목을 정리할 수 있어요. | The app may have been reinstalled or the file deleted. Playback and sharing aren't available, but you can tidy up items from the library. | アプリを再インストールしたか、ファイルが削除された可能性があります。再生と共有はできませんが、ライブラリで項目を整理できます。 | |
| 재생 | Play | 再生 | |
| 공유 | Share | 共有 | |
| 필름 삭제 | Delete film | フィルムを削除 | |
| 필름을 찾을 수 없어요 | Film not found | フィルムが見つかりません | |
| 이미 삭제되었거나 다른 기기에서 동기화 중일 수 있어요. | It may have been deleted or is syncing from another device. | すでに削除されたか、他のデバイスで同期中の可能性があります。 | |
| 홈으로 | Home | ホーム | |

---

### Task 9: SettingsFeature (Support/Label) + 서비스 에러

**transformTasks:**
- `Modules/SettingsFeature/Sources/Feedback.swift` `FeedbackCategory.koreanName` 각 `return "…"` → `String(localized:)`.
- `Modules/SettingsFeature/Sources/FeedbackClient.swift` `FeedbackError.errorDescription` 각 `return "…"` → `String(localized:)`.
- `Modules/SettingsFeature/Sources/SupportFeature.swift` `AlertInfo(message: "소중한 의견 감사합니다. 잘 전달했어요.", …)` → `message: String(localized: "…")`.
- `Modules/SettingsFeature/Sources/SupportView.swift` `private let placeholder = "…"` → `= String(localized: "…")`.
- bare `Text`/menuRow 리터럴 — 변경 없음.
- (LabelPosition/LabelKind 는 Task 3 Models 에서 이미 처리됨.)

**카탈로그 항목:**

| 키 | EN | JA | ⚠ |
|---|---|---|---|
| 설정 | Settings | 設定 | |
| 영상에 표시되는 시각·날짜 라벨 | Time and date labels shown on videos | 動画に表示される時刻・日付ラベル | |
| 문의·신고 | Contact & report | お問い合わせ・報告 | |
| 불편한 점이나 제안을 보내주세요 | Send issues or suggestions | ご不便な点やご提案をお送りください | |
| 위치 | Position | 位置 | |
| 투명도 | Opacity | 透明度 | |
| 불편한 점이나 제안을 자유롭게 적어주세요. | Feel free to write any issues or suggestions. | ご不便な点やご提案を自由にお書きください。 | |
| 모든 제보는 익명으로 전송돼요. | All reports are sent anonymously. | すべての報告は匿名で送信されます。 | |
| 전송 | Send | 送信 | |
| 버그 | Bug | バグ | |
| 제안 | Suggestion | 提案 | |
| 기타 | Other | その他 | |
| 알림 | Notice | お知らせ | |
| 소중한 의견 감사합니다. 잘 전달했어요. | Thanks for your feedback. We've received it. | 貴重なご意見ありがとうございます。しっかり受け取りました。 | |
| 전송에 실패했어요. 네트워크 상태를 확인하고 다시 시도해 주세요. | Sending failed. Check your network and try again. | 送信に失敗しました。ネットワークを確認して再度お試しください。 | |
| 전송에 실패했어요. 잠시 후 다시 시도해 주세요. | Sending failed. Please try again shortly. | 送信に失敗しました。しばらくしてからお試しください。 | |

> "라벨"/"시각 라벨"/"날짜 라벨"/"뒤로"/"확인"은 Task 3/이전에서 등재됨(중복 키는 한 번만).

---

### Task 10: CompositionService + PhotosService 에러 메시지

**transformTasks:**
- `CompositionService.swift` `ExportError.errorDescription` 각 `return "…"` → `String(localized:)`(마지막은 `"저장 중 문제가 생겼어요: \(msg)"` → 키 `저장 중 문제가 생겼어요: %@`). `?? "알 수 없는 오류"` → `?? String(localized: "알 수 없는 오류")`.
- `PhotosService/DevMediaSource.swift` `DevMediaError.errorDescription` 각 `return "…"` → `String(localized:)`(보간은 `%@` 키). DevMediaAsset `title`/`locationNote` 리터럴 → `String(localized:)`.
- `PhotosService/PhotoLibraryClient.swift` `?? "알 수 없는 오류"` → `?? String(localized: "알 수 없는 오류")`.

**카탈로그 항목:**

| 키 | EN | JA | ⚠ |
|---|---|---|---|
| 합성 가능한 영상이 없어요. 영상 또는 Live Photo를 골라주세요. | No videos to compose. Please choose a video or Live Photo. | 合成できる動画がありません。動画またはLive Photoを選んでください。 | ⚠ |
| 내보내기 세션을 준비하지 못했어요. | Couldn't prepare the export session. | エクスポートセッションを準備できませんでした。 | |
| 비디오 트랙을 만들 수 없어요. | Couldn't create the video track. | ビデオトラックを作成できません。 | |
| `저장 중 문제가 생겼어요: %@` | `A problem occurred while saving: %@` | `保存中に問題が発生しました: %@` | |
| 알 수 없는 오류 | Unknown error | 不明なエラー | |
| `알 수 없는 Dev fixture예요: %@` | `Unknown Dev fixture: %@` | `不明なDev fixtureです: %@` | ⚠ |
| `Dev fixture 파일을 찾을 수 없어요: %@` | `Dev fixture file not found: %@` | `Dev fixtureファイルが見つかりません: %@` | ⚠ |
| `Dev fixture 영상을 읽을 수 없어요: %@` | `Couldn't read Dev fixture video: %@` | `Dev fixture動画を読み込めません: %@` | ⚠ |
| 협재 바다 | Hyeopjae Sea | ヒョプジェの海 | ⚠ |
| `Dev · 협재 바다` | `Dev · Hyeopjae Sea` | `Dev · ヒョプジェの海` | |
| 카페 테이블 | Cafe table | カフェのテーブル | |
| `Dev · 카페` | `Dev · Cafe` | `Dev · カフェ` | |
| 노을 산책 | Sunset walk | 夕焼け散歩 | |
| `Dev · 노을` | `Dev · Sunset` | `Dev · 夕焼け` | |
| 숲의 빛 | Forest light | 森の光 | |
| `Dev · 숲길` | `Dev · Forest path` | `Dev · 森の道` | |

---

### Task 11: 영상 오버레이 날짜/시간 로케일화

**Files:**
- Modify: `Modules/CompositionService/Sources/CompositionService.swift` (오버레이 포매터 + export 시그니처)
- Modify: `Modules/TimelineFeature/Sources/AutoLabelsOverlay.swift` (프리뷰 오버레이 — 동일 포매터)
- Modify: `Modules/ExportFeature/Sources/ExportFeature.swift` (선택 언어 → export 로 전달)

- [ ] **Step 1: 공통 글리프-세이프 포매터**

오버레이는 KERISKEDU 폰트로 픽셀에 박히므로 CJK 글리프 의존을 피하고 로케일별 *숫자* 형식을 쓴다. CompositionService 에 헬퍼 추가:

```swift
import Foundation

enum OverlayDateFormat {
    /// 글리프-세이프(숫자+구분자) 날짜/시간 포맷. 로케일별 순서·12/24h 만 다르게.
    static func date(_ locale: Locale) -> DateFormatter {
        let f = DateFormatter()
        f.locale = locale
        switch locale.language.languageCode?.identifier {
        case "en": f.dateFormat = "MM/dd/yyyy"
        default:   f.dateFormat = "yyyy/MM/dd"   // ko, ja
        }
        return f
    }
    static func time(_ locale: Locale) -> DateFormatter {
        let f = DateFormatter()
        f.locale = locale
        switch locale.language.languageCode?.identifier {
        case "en": f.dateFormat = "h:mm a"       // 12h, AM/PM(Latin → 글리프 OK)
        default:   f.dateFormat = "HH:mm"        // ko, ja 24h
        }
        return f
    }
}
```

- [ ] **Step 2: export API 에 localeIdentifier 전달**

`CompositionClient.export(...)` 시그니처에 `localeIdentifier: String` 추가(기본값 `Locale.current.identifier` 로 기존 호출 호환). 내부 CATextLayer 생성 시 기존 하드코딩 `"yyyy/MM/dd"`/`"HH:mm"` 포매터를 `OverlayDateFormat.date/time(Locale(identifier: localeIdentifier))` 로 교체.

- [ ] **Step 3: ExportFeature 에서 선택 언어 주입**

`ExportFeature` 가 export effect 호출 시 현재 `AppLanguage.locale.identifier` 를 전달. 언어는 `@Dependency` 로 노출하거나(권장: `AppLanguageStore` 를 의존성으로 래핑) 환경에서 읽어 액션 페이로드로 넘긴다. 최소안: `UserDefaults.standard.string(forKey: "appLanguage")` → `AppLanguage` → `.locale.identifier`(system 은 `Locale.current.identifier`).

- [ ] **Step 4: AutoLabelsOverlay 동기화**

`AutoLabelsOverlay.swift` 의 `en_US_POSIX` 하드코딩 포매터를 동일 `OverlayDateFormat` 으로 교체해 프리뷰와 출력 형식을 일치시킨다.

- [ ] **Step 5: 빌드 + 검증**

ko/en/ja 각각으로 export 실행 → 오버레이 날짜/시간이 로케일 형식으로 표시되고 글리프 깨짐 없는지 확인. `CompositionServiceTests` 그린 확인.

- [ ] **Step 6: 커밋** `🌐 i18n(overlay): 영상 날짜/시간 로케일 형식`

---

### Task 12: UI 날짜/기간 형식 로케일화

**Files:**
- Modify: `Modules/FilmDetailFeature/Sources/FilmDetailView.swift`

- [ ] **Step 1: `ko_KR` 고정 포매터 제거**

`FilmDetailView` 의 `DateFormatter`(locale `ko_KR`, `"yyyy년 M월 d일 EEEE"`)로 만든 텍스트를 환경 locale 추종 형식으로 교체:

```swift
// before: 고정 ko_KR DateFormatter 사용
// after:
Text(film.createdAt, format: .dateTime.year().month().day().weekday())
```

(`Text(_:format:)` 는 환경 `\.locale`(= languageStore.locale)을 따른다.)

- [ ] **Step 2: 빌드 + 검증**

en 선택 시 영문 날짜, ja 선택 시 일본어 날짜로 표시되는지 확인.

- [ ] **Step 3: 커밋** `🌐 i18n(FilmDetail): 날짜 형식 로케일화`

---

### Task 13: Info.plist 권한 안내문 현지화

**Files:**
- Create: `ChalNa/Resources/en.lproj/InfoPlist.strings`
- Create: `ChalNa/Resources/ja.lproj/InfoPlist.strings`
- (ko 는 `Project.swift` Info.plist 의 기존 값이 base)

- [ ] **Step 1: en.lproj/InfoPlist.strings**

```
"NSPhotoLibraryUsageDescription" = "Connects video from inside your Live Photos to stitch a Vlog, so photo library access is needed.";
"NSPhotoLibraryAddUsageDescription" = "Permission is needed to save your finished Vlog to your photo library.";
```

- [ ] **Step 2: ja.lproj/InfoPlist.strings**

```
"NSPhotoLibraryUsageDescription" = "Live Photo内の動画を読み込んでVlogにつなぐため、写真ライブラリへのアクセスが必要です。";
"NSPhotoLibraryAddUsageDescription" = "完成したVlogを写真ライブラリに保存するために権限が必要です。";
```

- [ ] **Step 3: tuist generate + 빌드 확인**

`ChalNa/Resources` 가 buildableFolders 에 있으므로 `.lproj` 가 포함된다. 빌드 후 번들에 `en.lproj/InfoPlist.strings`, `ja.lproj/InfoPlist.strings` 가 들어갔는지 확인.

> 한계: OS 권한 다이얼로그는 *기기 언어*를 따른다(앱 내 언어 오버라이드 미적용). 기기가 en/ja 인 사용자에게만 이 번역이 보인다.

- [ ] **Step 4: 커밋** `🌐 i18n(InfoPlist): 사진 권한 안내문 en/ja`

---

### Task 14: 최종 검증 + 번역 검수

- [ ] **Step 1: 전 언어 빌드/실행 시각 검증**

`ios-build-run` 으로 ko → en → ja 순으로 실행하며 전 화면(홈/미디어선택/타임라인/내보내기/필름상세/설정 전체) 스크린샷. 확인:
- 미번역(한국어 잔존) 없음(브랜드 '찰나/ChalNa' 제외).
- 보간/복수형 문자열이 올바른 값으로 렌더(키 불일치 시 한국어 키가 그대로 보임 → Appendix A 의 포맷 키 재확인).
- 레이아웃 잘림/오버플로 없음(특히 영어 장문, 일본어).
- 언어 라이브 전환 시 즉시 반영 + 네비게이션 유지.

- [ ] **Step 2: 복수형(en) 적용 확인**

`%lld편`/`%lld film(s)` 등 카운트 문구가 영어에서 1 vs N 으로 올바르게 표시되는지(Appendix A plural).

- [ ] **Step 3: 검수 대상(⚠) 목록 정리**

표에서 ⚠ 표시된 항목(도메인/톤 민감)을 모아 사용자에게 검수 요청. 주요 항목: 브랜드 인접 문구("오늘 찰나의 순간들", "찰나의 순간 엮는 중"), "라벨"/"클립"/"라이브 포토"/"필름" 용어 일관성, 지명(협재/중문/한라산 등) 음역, "Live"/"Video" 메타 라벨.

- [ ] **Step 4: 최종 커밋 + 정리**

```bash
git add -A && git commit -m "🌐 i18n: 전 언어 검증 + 카탈로그 마무리"
```

---

## Appendix A: String Catalog(.xcstrings) 형식 & 보간 키 규칙

### 항목 추가 형식

```json
"키문자열" : {
  "localizations" : {
    "en" : { "stringUnit" : { "state" : "translated", "value" : "English" } },
    "ja" : { "stringUnit" : { "state" : "translated", "value" : "日本語" } }
  }
}
```
- `sourceLanguage` 가 `ko` 이므로 ko 값은 키 자체 → 별도 localization 불필요(원하면 ko 도 명시 가능).
- 키는 **한국어 원문**(공백·줄바꿈 `\n`·문장부호 정확히). 보간은 포맷 형태(`%lld`/`%@`).

### 영어 복수형(plural variation)

`%lld편` 처럼 카운트 문구는 영어만 plural 분기:

```json
"%lld편" : {
  "localizations" : {
    "en" : {
      "variations" : {
        "plural" : {
          "one"   : { "stringUnit" : { "state" : "translated", "value" : "%lld film" } },
          "other" : { "stringUnit" : { "state" : "translated", "value" : "%lld films" } }
        }
      }
    },
    "ja" : { "stringUnit" : { "state" : "translated", "value" : "%lld本" } }
  }
}
```
- ko/ja 는 단수형만(굴절 없음).
- 복수형 대상(표에서 plural 명시): `%lld편`(Home). 그 외 카운트 문구(`%lld개 선택됨…`, `Timeline으로 (%lld)`, `%lld fixtures…`)는 영어가 어차피 "N selected" 형태라 단일형으로 충분 — 필요 판단 시 동일 패턴 적용.

### 보간 → 포맷 키 규칙 (재확인)

| 소스 | 카탈로그 키 |
|---|---|
| `Text("\(intVal)편")` | `%lld편` |
| `String(localized: "· \(a)/\(b)")` (Int) | `· %lld/%lld` |
| `String(localized: "...\(strVal)")` (String) | `...%@` |
| `String(format: "%d ...", ...)` 를 `String(localized:)` 로 감쌈 | `%d ...` (그대로, 보간 아님) |

검증으로 안전망: 빌드 후 해당 문자열이 키(한국어) 그대로 보이면 키 불일치 → 방출 키 확인 후 수정.

## Appendix B: 미적용(추출 제안 중 폐기) 목록

추출 에이전트가 제안했으나 **중앙 카탈로그 토폴로지상 적용하지 않는** 것:
- `Text("…", bundle: .module)` — 모두 폐기(중앙 카탈로그는 main 번들).
- bare `Text`/`Button`/`.accessibilityLabel` 리터럴의 `LocalizedStringKey(...)`/`String(localized:)` 래핑 — 폐기(자동 현지화).
- `Film.metaLabel`/`Clip.durationSecondsLabel` 의 중첩 `String(localized:)` 보간 형태 — 대신 `String(format: String(localized: "포맷"), …)` 사용(Task 3).
