# ChalNa(찰나): Live Photo Vlog 메이커

라이브러리에 흩어져 있는 Live Photo와 짧은 동영상을 촬영일 순서로 이어 붙여, 촬영 부담 없는 9:16 Vlog를 만드는 iOS 앱입니다.

2026.05 ~ 서비스 중 · 개인 프로젝트 [App Store](https://apps.apple.com/kr/app/%EC%B0%B0%EB%82%98-chalna/id6773353791)

## 어떤 문제를 푸는가

사진은 셔터만 누르면 되지만 정적이고, 영상은 생동감이 있는 대신 촬영 자체가 부담입니다. Live Photo는 이 둘의 교집합입니다. 사진처럼 찍었을 뿐인데 셔터 전후 1.5초씩, 약 3초의 영상이 이미 담겨 있습니다. 그러니 새로 찍을 필요 없이 이미 잠들어 있는 영상을 시간순으로 이어 붙이기만 하면 Vlog가 된다는 가설로 시작했습니다.

만든 Vlog가 소비될 채널은 인스타그램 스토리로 정했습니다. 캔버스를 9:16(1080×1920) 하나로 고정한 이유입니다. 편집 기능도 이 경험을 해치지 않는 범위, 즉 클립별 크롭 조정과 시간 라벨까지만 두었습니다.

## 화면 흐름

```
홈 (만든 필름 보관함)
 ├─ 새 Vlog : 미디어 선택 → 타임라인 편집 (재생 프리뷰 · 크롭 조정 · 시간 라벨)
 │            → 익스포트 (1080×1920 mp4) → 보관함 저장
 ├─ 필름 상세 : 재생 · 공유
 └─ 설정 : 라벨 스타일 · 라벨 위치 · 언어 · 문의
```

<!-- TODO: 스크린샷 추가 후 주석 해제 (docs/screenshots/)
| 홈 | 타임라인 | 크롭 조정 | 익스포트 |
|---|---|---|---|
| ![홈](docs/screenshots/home.png) | ![타임라인](docs/screenshots/timeline.png) | ![크롭](docs/screenshots/crop.png) | ![익스포트](docs/screenshots/export.png) |
-->

## 빌드와 실행

Tuist 기반이라 `.xcodeproj`/`.xcworkspace`는 저장소에 없고 생성물입니다.

```bash
brew install tuist            # Tuist 미설치자 한해서
tuist install
tuist generate
open ChalNa.xcworkspace
```

## 아키텍처

앱 셸은 얇게 두고 13개 모듈로 나눴습니다. 의존은 위에서 아래로만 흐르고, 이 방향은 문서가 아니라 `Project.swift`가 강제합니다.

```
앱 셸       ChalNa (@main · AppFeature가 TCA 루트로서 네비게이션 해석)
              │
Feature     Home · MediaPicker · Timeline · Export · FilmDetail · Settings
(@Reducer)    │      
              │
서비스       AppCore(EditSession) · PhotosService · CompositionService · AnalyticsService
              │
모델·기반    Models ─ FileStorage          DesignSystem (의존 0, 최하단)
```

지키고 있는 규칙은 이렇습니다.
**편집 상태를 route payload로 나르지 않습니다.** 선택한 클립·제목·회전·크롭은 `@Observable`인 `EditSession` 한 인스턴스에 실어 MediaPicker → Timeline → Export로 흘립니다. Reducer는 `@Dependency`로, View는 `@Environment`로 같은 인스턴스를 봅니다.

**트랙 조작은 actor 밖으로 나오지 않습니다.** `AVMutableComposition`은 스레드 안전하지 않아서 합성 코드 전부를 `AVFoundationCompositionService` actor 안에 격리했고, 진행률은 `AsyncStream<ExportEvent>`로 내보냅니다. 동시성은 Swift Concurrency만 씁니다(GCD 금지, 콜백 API는 continuation으로 래핑).

## 기술적으로 공들인 지점

### 전체 라이브러리 권한을 요구하지 않습니다

앱의 가치를 체험하기도 전에 전체 라이브러리 접근부터 요구하면 그 지점에서 상당수가 이탈한다고 판단했습니다. `PHPickerViewController`로 사용자가 직접 고른 항목만 받고, Live Photo의 paired video는 picker 결과에서 곧바로 추출합니다. 앱이 라이브러리 전체를 볼 수 있는 순간은 없습니다.

### AI 에이전트와의 페어 개발을 전제로 한 환경

이 프로젝트는 처음부터 Claude Code와의 페어 개발을 전제로 시작했습니다. AI가 작성하는 코드의 품질을 문서 규칙과 리뷰만으로 일관되게 유지하기는 어렵다고 판단했고, 어길 수 없는 규칙은 사람이 아니라 도구가 지키게 했습니다.

## 기술 스택

Swift 6 · iOS 18+ · SwiftUI · The Composable Architecture 1.18+ · Swift Concurrency(actor, AsyncStream) · SwiftData · AVFoundation · PhotosUI(PHPicker) · Tuist · Firebase Analytics · Swift Testing
