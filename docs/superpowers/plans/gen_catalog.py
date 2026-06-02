#!/usr/bin/env python3
"""ChalNa 중앙 String Catalog 생성기.

(key, en, ja) 튜플 목록에서 Localizable.xcstrings 를 생성한다.
- key = 한국어 원문(보간은 %lld/%@ 포맷 형태). sourceLanguage=ko 이므로 ko 값은 키 자체.
- 키 중복은 자동 병합(마지막 정의가 우선; 동일 키는 동일 번역이어야 함).
- PLURALS[key] = (en_one, en_other) 가 있으면 en 을 plural variation 으로.
- en 또는 ja 가 None 이면 해당 언어는 생략(소스=ko 로 폴백). 순수 영문/포맷 스타일 문구는 등재 안 함.
"""
import json
import collections

# (key, en, ja). en/ja 가 None 이면 생략(키로 폴백).
ENTRIES = [
    # --- Foundation ---
    ("시스템 설정", "System", "システム設定"),
    ("언어", "Language", "言語"),
    ("앱 표시 언어를 선택하세요", "Choose the app display language", "アプリの表示言語を選択してください"),
    ("설정", "Settings", "設定"),
    ("뒤로", "Back", "戻る"),

    # --- Home ---
    ("오늘 찰나의 순간들", "Today's ChalNa moments", "今日のChalNaのひととき"),
    ("Live Photo와 짧은 영상을 촬영일 순서로 이어붙여\n한 편의 필름처럼 기록해요.",
     "Connect Live Photos and short videos in capture order\nto record them like a single film.",
     "ライブフォトと短い動画を撮影日順につなぎ、\n一本のフィルムのように記録します。"),
    ("새 Vlog 만들기", "Create new Vlog", "新しいVlogを作成"),
    ("최근 필름", "Recent films", "最近のフィルム"),
    ("%lld편", "%lld films", "%lld本"),  # en plural below
    ("아직 만든 필름이 없어요.", "No films yet.", "まだフィルムがありません。"),
    ("첫 Vlog를 시작해보세요.", "Start your first Vlog.", "最初のVlogを始めましょう。"),

    # --- MediaPicker ---
    ("Live Photo 권한이 필요해요", "Live Photo permission required", "Live Photoの権限が必要です"),
    ("Live Photo를 영상으로 사용하려면 사진 보관함 접근 권한이 필요해요.",
     "To use Live Photo as video, photo library access is required.",
     "Live Photoを動画として使うには写真ライブラリへのアクセス許可が必要です。"),
    ("확인", "OK", "OK"),
    ("취소", "Cancel", "キャンセル"),
    ("미디어 선택", "Select media", "メディアを選択"),
    ("TITLE · 이번 찰나 모음집의 제목", "TITLE · Title of this ChalNa collection",
     "TITLE · このChalNaコレクションのタイトル"),
    ("찰나의 순간을\n천천히 골라보세요.", "Pick your ChalNa moments\nslowly and carefully.",
     "ChalNaの瞬間を\nゆっくり選んでください。"),
    ("Live Photo와 짧은 영상을 불러올 수 있어요.\nLive Photo는 내부의 영상 부분을 사용합니다.",
     "You can import Live Photos and short videos.\nLive Photo uses its internal video portion.",
     "Live Photoと短い動画をインポートできます。\nLive Photoは内部の動画部分を使用します。"),
    ("예: 제주도, 우리의 봄", "e.g. Jeju, our spring", "例：済州島、私たちの春"),
    ("비워두면 나중에 자동으로 채워져요.", "Leave empty to auto-fill later.", "空欄のままだと後で自動入力されます。"),
    ("사진을 불러오는 중", "Loading photos", "写真を読み込み中"),
    ("Live Photo와 영상을 정성껏 추출하고 있어요", "Carefully extracting Live Photos and videos",
     "Live Photoと動画を丁寧に抽出しています"),
    ("선택한 미디어 · %lld", "Selected media · %lld", "選択したメディア · %lld"),
    ("사진을 불러오는 중이에요", "Loading photos", "写真を読み込んでいます"),
    ("Dev 미디어 소스", "Dev media source", "Devメディアソース"),
    ("번들 fixture로 실제 export까지 확인", "Verify export with bundled fixtures",
     "バンドルfixtureでエクスポートまで確認"),
    ("%lld개 fixture 선택됨", "%lld fixtures selected", "%lld個のfixtureを選択"),
    ("Dev 미디어를 준비하고 있어요", "Preparing dev media", "Devメディアを準備中です"),
    ("이번 필름의 제목", "This film's title", "このフィルムのタイトル"),
    ("%lld개 중 %lld개 완료", "%1$lld of %2$lld done", "%1$lld個中%2$lld個完了"),
    ("탭하면 미리보기가 열려요", "Tap to open preview", "タップでプレビューを開きます"),
    ("선택에서 제외", "Remove from selection", "選択から除外"),
    ("%@를 선택에서 빼요", "Remove %@ from selection", "%@を選択から外します"),
    ("비디오", "Video", "ビデオ"),
    ("라이브 포토", "Live Photo", "ライブフォト"),
    ("사진", "Photo", "写真"),
    ("종류 확인 중", "Checking type", "タイプを確認中"),
    ("사진 권한 선택", "Choose photo permissions", "写真の権限を選択"),
    ("사진 권한 열기", "Open photo permissions", "写真の権限を開く"),
    ("사진 추가하기", "Add photos", "写真を追加"),
    ("다시 고르기", "Choose again", "選び直す"),
    ("먼저 권한 범위를 고른 뒤 선택해요", "Choose permission scope first, then select",
     "まず権限の範囲を選んでから選択します"),
    ("설정에서 사진 접근을 허용해 주세요", "Allow photo access in Settings", "設定で写真へのアクセスを許可してください"),
    ("선택한 사진을 불러오는 중", "Loading selected photos", "選択した写真を読み込み中"),
    ("Live Photo와 짧은 영상만 가져올 수 있어요", "Only Live Photos and short videos can be imported",
     "Live Photoと短い動画のみインポートできます"),
    ("%lld개 선택됨 · 탭해서 추가해요", "%lld selected · Tap to add", "%lld個選択 · タップして追加"),
    ("먼저 사진 권한 범위를 선택해 주세요", "Please choose a photo permission scope first",
     "まず写真の権限範囲を選択してください"),
    ("사진 권한을 허용해야 Live Photo 영상을 만들 수 있어요", "Photo permission is required to create Live Photo videos",
     "Live Photo動画の作成には写真の権限が必要です"),
    ("선택한 사진을 불러오고 있어요", "Loading selected photos", "選択した写真を読み込んでいます"),
    ("아직 선택한 사진이 없어요. 위 카드를 눌러 골라보세요.",
     "No photos selected yet. Tap the card above to choose.",
     "まだ写真が選択されていません。上のカードをタップして選んでください。"),
    ("사진 권한을 허용해야 Live Photo 영상을 사용할 수 있어요.", "Photo permission is required to use Live Photo videos.",
     "Live Photo動画を使うには写真の権限が必要です。"),
    ("먼저 사진 권한 범위를 선택해 주세요.", "Please choose a photo permission scope first.",
     "まず写真の権限範囲を選択してください。"),
    ("선택한 항목을 불러오지 못했어요. 다시 선택해 주세요.", "Failed to load the selected items. Please select again.",
     "選択項目を読み込めませんでした。もう一度選択してください。"),
    ("사진 로딩 중 · %lld/%lld", "Loading photos · %1$lld/%2$lld", "写真を読み込み中 · %1$lld/%2$lld"),
    ("선택 후 다음", "Select, then continue", "選択して次へ"),
    ("원본 확인 필요", "Original needs checking", "元ファイルの確認が必要"),
    ("사진 로딩 중", "Loading photos", "写真を読み込み中"),
    ("Timeline으로 (%lld)", "To Timeline (%lld)", "Timelineへ (%lld)"),
    ("%.1f초", "%.1f sec", "%.1f秒"),
    ("재생 중. 탭하면 멈춰요", "Playing. Tap to pause.", "再生中。タップで一時停止します。"),
    ("일시정지. 탭하면 재생돼요", "Paused. Tap to play.", "一時停止中。タップで再生します。"),
    ("영상을 불러오지 못했어요", "Failed to load video", "動画を読み込めませんでした"),
    ("영상을 탭하면 재생/일시정지돼요.", "Tap the video to play/pause.", "動画をタップで再生／一時停止します。"),
    ("원본 영상이 없는 미디어예요.", "This media has no original video.", "元の動画がないメディアです。"),
    ("불러오는 중", "Loading", "読み込み中"),
    ("썸네일 불러오기 실패", "Thumbnail load failed", "サムネイル読み込み失敗"),
    ("영상 추출 실패", "Video extraction failed", "動画抽出失敗"),
    ("영상 X", "Video X", "動画 X"),

    # --- Timeline ---
    ("클립을 삭제할까요?", "Delete this clip?", "このクリップを削除しますか？"),
    ("삭제", "Delete", "削除"),
    ("삭제한 클립은 현재 타임라인에서 제거됩니다.", "The deleted clip will be removed from the current timeline.",
     "削除したクリップは現在のタイムラインから取り除かれます。"),
    ("재생 중", "Playing", "再生中"),
    ("편집", "Edit", "編集"),
    ("▶ NOW PLAYING · CLIP %lld", None, "▶ 再生中 · CLIP %lld"),
    ("TIMELINE · %lld CLIPS", None, "タイムライン · %lldクリップ"),
    ("총 ", "Total ", "合計 "),
    ("클립을 탭해 편집 · 길게 눌러서 끌어 이동", "Tap a clip to edit · long-press and drag to reorder",
     "クリップをタップで編集 · 長押しでドラッグして並べ替え"),
    ("라벨", "Label", "ラベル"),
    ("저장", "Save", "保存"),
    ("자막 입력", "Enter subtitle", "字幕を入力"),
    ("크기", "Size", "サイズ"),
    ("회전", "Rotate", "回転"),
    ("선택한 클립을 삭제합니다.", "Deletes the selected clip.", "選択したクリップを削除します。"),
    ("이전 클립", "Previous clip", "前のクリップ"),
    ("다음 클립", "Next clip", "次のクリップ"),
    ("일시정지", "Pause", "一時停止"),
    ("재생", "Play", "再生"),
    ("현재 클립 재생 상태를 전환합니다.", "Toggles playback of the current clip.", "現在のクリップの再生状態を切り替えます。"),
    ("선택하려면 두 번 탭하고, 순서를 바꾸려면 사용자 동작을 사용하세요.",
     "Double-tap to select, or use custom actions to reorder.",
     "ダブルタップで選択、カスタム操作で並べ替えできます。"),
    ("앞으로 이동", "Move forward", "前へ移動"),
    ("뒤로 이동", "Move backward", "後ろへ移動"),
    ("%@ 촬영일", "Captured %@", "%@ 撮影日"),
    (", 선택됨", ", selected", "、選択済み"),
    ("%lld번째 클립, %@, %@%@", "Clip %1$lld, %2$@, %3$@%4$@", "%1$lld番目のクリップ、%2$@、%3$@%4$@"),
    ("%lld번째 위치로 이동했습니다.", "Moved to position %lld.", "%lld番目の位置に移動しました。"),

    # --- Export ---
    ("저장 중", "Saving", "保存中"),
    ("완성", "Done", "完成"),
    ("저장 실패", "Save failed", "保存失敗"),
    ("사진 앱에 저장됐어요 ✦", "Saved to Photos ✦", "写真アプリに保存しました ✦"),
    ("사진 보관함 접근 권한이 필요해요", "Photo library access is required", "写真ライブラリへのアクセス許可が必要です"),
    ("저장 실패 — %@", "Save failed — %@", "保存失敗 — %@"),
    ("재생 닫기", "Close playback", "再生を閉じる"),
    ("완성된 영상 재생", "Play finished video", "完成した動画を再生"),
    ("내보낼 클립이 없어요", "No clips to export", "エクスポートするクリップがありません"),
    ("내보내기 진행률", "Export progress", "エクスポートの進捗"),
    ("%lld퍼센트", "%lld percent", "%lldパーセント"),
    ("Vlog를 엮는 중… Live Photo의 영상 부분을 자동으로 추출해 이어 붙여요.",
     "Weaving your Vlog… automatically extracting and stitching the video parts of your Live Photos.",
     "Vlogを編んでいます… Live Photoの動画部分を自動で抽出してつなぎます。"),
    ("필름이 완성되었어요. 공유하거나 사진 보관함에 저장할 수 있어요.",
     "Your film is ready. You can share it or save it to your photo library.",
     "フィルムが完成しました。共有や写真ライブラリへの保存ができます。"),
    ("저장 중 문제가 발생했어요.", "Something went wrong while saving.", "保存中に問題が発生しました。"),
    ("잠깐만 기다려주세요", "Please wait a moment", "少々お待ちください"),
    ("공유하기", "Share", "共有"),
    ("저장 중…", "Saving…", "保存中…"),
    ("저장하기", "Save", "保存"),
    ("다른 영상 만들기", "Create another", "別の動画を作成"),
    ("홈으로 →", "Home →", "ホームへ →"),
    ("다시 시도", "Try again", "もう一度試す"),
    ("편집으로 돌아가기", "Back to editing", "編集に戻る"),

    # --- FilmDetail ---
    ("필름 정보", "Film details", "フィルム情報"),
    ("필름을 삭제할까요?", "Delete this film?", "このフィルムを削除しますか？"),
    ("이 필름과 영상 파일이 모두 사라져요. 되돌릴 수 없어요.",
     "This film and its video file will be permanently deleted. This can't be undone.",
     "このフィルムと動画ファイルが完全に削除されます。元に戻せません。"),
    ("총 길이", "Duration", "合計時間"),
    ("클립", "Clips", "クリップ"),
    ("Live", "Live", "ライブ"),
    ("Video", "Video", "ビデオ"),
    ("영상 파일을 찾을 수 없어요", "Video file not found", "動画ファイルが見つかりません"),
    ("앱을 다시 설치하셨거나 파일이 삭제되었어요. 재생과 공유는 불가능하고, 라이브러리에서 항목을 정리할 수 있어요.",
     "The app may have been reinstalled or the file deleted. Playback and sharing aren't available, but you can tidy up items from the library.",
     "アプリを再インストールしたか、ファイルが削除された可能性があります。再生と共有はできませんが、ライブラリで項目を整理できます。"),
    ("공유", "Share", "共有"),
    ("필름 삭제", "Delete film", "フィルムを削除"),
    ("필름을 찾을 수 없어요", "Film not found", "フィルムが見つかりません"),
    ("이미 삭제되었거나 다른 기기에서 동기화 중일 수 있어요.",
     "It may have been deleted or is syncing from another device.",
     "すでに削除されたか、他のデバイスで同期中の可能性があります。"),
    ("홈으로", "Home", "ホーム"),

    # --- Settings (Support/Label) ---
    ("영상에 표시되는 시각·날짜 라벨", "Time and date labels shown on videos", "動画に表示される時刻・日付ラベル"),
    ("문의·신고", "Contact & report", "お問い合わせ・報告"),
    ("불편한 점이나 제안을 보내주세요", "Send issues or suggestions", "ご不便な点やご提案をお送りください"),
    ("위치", "Position", "位置"),
    ("투명도", "Opacity", "透明度"),
    ("불편한 점이나 제안을 자유롭게 적어주세요.", "Feel free to write any issues or suggestions.",
     "ご不便な点やご提案を自由にお書きください。"),
    ("모든 제보는 익명으로 전송돼요.", "All reports are sent anonymously.", "すべての報告は匿名で送信されます。"),
    ("전송", "Send", "送信"),
    ("버그", "Bug", "バグ"),
    ("제안", "Suggestion", "提案"),
    ("기타", "Other", "その他"),
    ("알림", "Notice", "お知らせ"),
    ("소중한 의견 감사합니다. 잘 전달했어요.", "Thanks for your feedback. We've received it.",
     "貴重なご意見ありがとうございます。しっかり受け取りました。"),
    ("전송에 실패했어요. 네트워크 상태를 확인하고 다시 시도해 주세요.",
     "Sending failed. Check your network and try again.",
     "送信に失敗しました。ネットワークを確認して再度お試しください。"),
    ("전송에 실패했어요. 잠시 후 다시 시도해 주세요.", "Sending failed. Please try again shortly.",
     "送信に失敗しました。しばらくしてからお試しください。"),

    # --- Models (positions / labels / sample) ---
    ("좌측 상단", "Top left", "左上"),
    ("중앙 상단", "Top center", "上中央"),
    ("우측 상단", "Top right", "右上"),
    ("좌측 중앙", "Middle left", "左中央"),
    ("정중앙", "Center", "中央"),
    ("우측 중앙", "Middle right", "右中央"),
    ("좌측 하단", "Bottom left", "左下"),
    ("중앙 하단", "Bottom center", "下中央"),
    ("우측 하단", "Bottom right", "右下"),
    ("시각 라벨", "Time label", "時刻ラベル"),
    ("날짜 라벨", "Date label", "日付ラベル"),
    ("%d CLIPS · %02d:%02d", "%d clips · %02d:%02d", "%d クリップ · %02d:%02d"),
    ("찰나의 순간 엮는 중", "Weaving moments of ChalNa", "ChalNaの瞬間を紡ぐ"),
    ("협재 해변", "Hyeopjae Beach", "ヒョプジェビーチ"),
    ("중문 노을", "Jungmun Sunset", "チュンムン夕焼け"),
    ("한라산 입구", "Hallasan Entrance", "ハルラ山入口"),
    ("소길리 · 오후 4시", "Sogil-ri · 4 PM", "ソギルリ · 午後4時"),
    ("풀밭", "Grassy field", "草原"),
    ("숲길", "Forest trail", "森の道"),
    ("저녁 노을", "Evening sunset", "夕焼け"),
    ("카페", "Cafe", "カフェ"),

    # --- CompositionService / PhotosService (errors + dev fixtures) ---
    ("합성 가능한 영상이 없어요. 영상 또는 Live Photo를 골라주세요.",
     "No videos to compose. Please choose a video or Live Photo.",
     "合成できる動画がありません。動画またはLive Photoを選んでください。"),
    ("내보내기 세션을 준비하지 못했어요.", "Couldn't prepare the export session.",
     "エクスポートセッションを準備できませんでした。"),
    ("비디오 트랙을 만들 수 없어요.", "Couldn't create the video track.", "ビデオトラックを作成できません。"),
    ("저장 중 문제가 생겼어요: %@", "A problem occurred while saving: %@", "保存中に問題が発生しました: %@"),
    ("알 수 없는 오류", "Unknown error", "不明なエラー"),
    ("알 수 없는 Dev fixture예요: %@", "Unknown Dev fixture: %@", "不明なDev fixtureです: %@"),
    ("Dev fixture 파일을 찾을 수 없어요: %@", "Dev fixture file not found: %@", "Dev fixtureファイルが見つかりません: %@"),
    ("Dev fixture 영상을 읽을 수 없어요: %@", "Couldn't read Dev fixture video: %@", "Dev fixture動画を読み込めません: %@"),
    ("협재 바다", "Hyeopjae Sea", "ヒョプジェの海"),
    ("Dev · 협재 바다", "Dev · Hyeopjae Sea", "Dev · ヒョプジェの海"),
    ("카페 테이블", "Cafe table", "カフェのテーブル"),
    ("Dev · 카페", "Dev · Cafe", "Dev · カフェ"),
    ("노을 산책", "Sunset walk", "夕焼け散歩"),
    ("Dev · 노을", "Dev · Sunset", "Dev · 夕焼け"),
    ("숲의 빛", "Forest light", "森の光"),
    ("Dev · 숲길", "Dev · Forest path", "Dev · 森の道"),

    # --- Info.plist permission strings (also referenced via InfoPlist.strings, included for completeness) ---
]

# 영어 복수형: key -> (one, other). ja/ko 는 단수형(ENTRIES 의 ja, 키).
PLURALS = {
    "%lld편": ("%lld film", "%lld films"),
}


def build():
    strings = collections.OrderedDict()
    for key, en, ja in ENTRIES:
        locs = {}
        if key in PLURALS:
            one, other = PLURALS[key]
            locs["en"] = {
                "variations": {
                    "plural": {
                        "one": {"stringUnit": {"state": "translated", "value": one}},
                        "other": {"stringUnit": {"state": "translated", "value": other}},
                    }
                }
            }
        elif en is not None:
            locs["en"] = {"stringUnit": {"state": "translated", "value": en}}
        if ja is not None:
            locs["ja"] = {"stringUnit": {"state": "translated", "value": ja}}
        entry = {}
        if locs:
            entry["localizations"] = locs
        # 중복 키: 동일 키가 다시 나오면 마지막이 우선(동일해야 함)
        strings[key] = entry

    catalog = {
        "sourceLanguage": "ko",
        "strings": strings,
        "version": "1.0",
    }
    out = "/Users/ihchoi/Documents/Code/ChalNa/ChalNa/Resources/Localizable.xcstrings"
    with open(out, "w", encoding="utf-8") as f:
        json.dump(catalog, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"wrote {len(strings)} unique keys to {out}")
    # 중복 키 진단
    seen = collections.Counter(k for k, _, _ in ENTRIES)
    dups = {k: c for k, c in seen.items() if c > 1}
    if dups:
        print("dup keys merged:", dups)


if __name__ == "__main__":
    build()
