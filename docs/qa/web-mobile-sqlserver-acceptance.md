# Web Admin -> Backend -> Flutter -> SQL Server — 08/11/2026

> Cập nhật theo chỉ dẫn người dùng: áp dụng tạm quy tắc300 giây, chỉ ghi khi người dùng mở nội dung Artifact. **Vẫn chờ P2 xác nhận chính thức.** Source/test mới ở commit `436be108d7cb31825ef25db4021a29c152cd88c0`; xem [bản cập nhật quy tắc tạm thời](visit-rule-provisional-update.md). Kết quả SHA cũ bên dưới là bằng chứng lịch sử.

Nhánh `fix/visitlog-flutter-ci-e2e-acceptance`; commit kiểm thử `672b8796966674156d1874e8361cc75b0fc23c63` áp dụng cho mọi test trong báo cáo. **PASS ở browser + client HTTP Flutter + DB thực; nghiệm thu ứng dụng trên thiết bị thật BLOCKED.**

## Môi trường và tính an toàn

SQL Server 2022 container QA riêng, port15441 bind127.0.0.1; DB `test_acceptance_7c7c86e0` mới, marker/token riêng được verifier kiểm tra trước SELECT/test. Dùng script provision sẵn có và Alembic upgrade head, không sửa migration đã áp dụng, không reset DB. Credentials QA sinh ngẫu nhiên, nằm trong Windows Temp ngoài Git. API QA localhost8011; Web QA localhost5174; media localhost8091 phục vụ JPEG asset thật của dự án. Các server QA và container đã dừng sau nghiệm thu; database QA được giữ lại. Các container/dữ liệu ứng dụng có sẵn không bị thay đổi.

Live API dùng một Uvicorn worker vì Windows shared socket hai worker lỗi WinError10022. Test nhiều process riêng với SQL Server đã PASS (VL-07), không đồng nhất hai bằng chứng này. Không có Android/iOS device/emulator; Flutter devices chỉ thấy Windows, Chrome, Edge. Thông tin môi trường: [environment.json](evidence/environment.json).

## Kiến trúc thực tế và giới hạn tích hợp

| Thành phần | API thật / UI / dữ liệu mock |
|---|---|
| Site | React services/sites.ts export sites.api, dùng SDK và API /sites; Flutter Home/Map dùng HttpVisitorApi; Site translation API có code/test. |
| Artifact | Admin /items -> ArtifactManagement -> artifactsService -> API; Flutter list/detail dùng HttpVisitorApi; backend có content translation fallback. |
| ArtifactTranslation | Admin TranslationDialog PUT /artifacts/{id}/translations/{language}; vi/en thực ở SQL. |
| Media | Admin MediaForm tạo liên kết HTTP(S), không upload binary; list hiển thị link. Backend trả metadata theo ngôn ngữ; Flutter có image/just_audio/video_player. |
| Beacon | Admin CRUD thật, chọn Site/Artifact; Flutter BeaconContentService gọi /beacons/resolve; scanner/callback hiển thị có code và widget/unit tests. BLE thật chưa chạy trong phiên này. |
| User/auth | JWT login/signup API; Backend derives user from token, Admin/Visitor role dependencies. Web login admin thật; Flutter AuthService dùng IoAuthHttpClient thật trong acceptance. |
| Favorite | POST /favorites/, GET /favorites/me, DELETE /favorites/{artifact}; DB unique(user,artifact); Flutter detail/Favorites dùng API thật. |
| VisitLog/History | POST /visits/, GET /visits/me; database lock và cửa sổ hiện có; Flutter History API thật. Baseline chưa ghi lượt khi mở thủ công; cập nhật mới đã sửa trigger này theo quy tắc tạm thời (VISIT-OPEN-02). |
| Mock còn tồn tại | sites.mock.ts/beacons.mock.ts, HeritageRepository/mockLocations/sampleArtifacts, legacy ApiService và local simulation còn code. Không dùng chúng trong acceptance; sự tồn tại file mock không chứng minh route production đang dùng mock. |
| Ngoài phạm vi | Mobile AuthService.requestPasswordRecovery chỉ delay, chưa gọi backend; ghi BUG-OUT-01. Các màn analytics/visitors/preview ngoài luồng này không được chứng nhận. |

## Preconditions chung / cách đọc matrix

P-Web: Chrome157 headless thật, Web/API QA riêng; admin QA và graph mới mỗi lần chạy. P-Client: cùng graph qua QA_HANDOFF_FILE ngoài Git, Flutter3.47.7, HTTP thật, không MockClient; Python verifier có TEST_DATABASE_URL/TOKEN hợp lệ. P-Device: cần Android/iOS chạy app và kết nối được API/media riêng.

“Client PASS” chứng nhận request/parsing/decode, không chứng nhận render/interaction trên thiết bị. Mỗi dòng ghi mục tiêu, precondition, steps, expected, actual/status, evidence và bug. SHA chung ở đầu báo cáo.

## Web Admin và SQL

| ID / mục tiêu | Precondition / steps | Expected | Actual / status | Evidence / Bug |
|---|---|---|---|---|
| WEB-00 / auth | P-Web; điền form login, submit | Login200, vào dashboard admin | Đúng / **PASS** | web-admin.log/results.json; — |
| WEB-01 / Site | P-Web; Add site, nhập tên/mô tả tiếng Việt, submit | Site ID được cấp và SQL lưu | Đúng / **PASS** | web-admin-results.json + sql-favorite-added.json: Artifact.site_id + FK Site; — |
| WEB-02 / Artifact | Add artifact, chọn Site, code, cover URL thật | Artifact đúng Site ID/code | Đúng / **PASS** | web-admin-results.json + SQL verifier; — |
| WEB-03 / tiếng Việt | Dialog translations, nhập title/description/history, Save | Translation vi lưu Unicode | Đúng / **PASS** | JSON + sql-favorite-added.json; — |
| WEB-04 / tiếng Anh | Chọn English, nhập/save | Translation en riêng, không ghi đè vi | Đúng / **PASS** | cùng evidence; — |
| WEB-05 / Media thật | Add Media image với JPEG URL localhost; mở link và kiểm tra naturalWidth | Metadata lưu; Chrome tải/decode bytes | Đúng / **PASS** | web-real-image.jpg + SQL media_urls; — |
| WEB-06 / Beacon | Form UUID/major101/minor202, chọn Site và Artifact, submit | Beacon đúng mapping | Đúng / **PASS** | web-beacon.png + SQL verifier; — |
| WEB-07 / sửa nội dung | Mở translation vi, sửa title, Save; Flutter tải lại | SQL/API/client có title mới | Đúng / **PASS** | web-artifact.png, mobile-client-results.json, SQL JSON; — |
| WEB-08 / đối chiếu DB | P-Client; SELECT Artifact/Translation/Media/Beacon/User-owned state bằng verifier read-only | ID, Unicode, URL, mapping, timestamp trùng | Đúng / **PASS** | sql-favorite-added.json, sql-favorite-removed.json; — |

Graph cuối: Site `7a7dce5e-3530-4a47-972b-7c10d7852f59`; Artifact `dc628799-63ff-463b-a216-b0a7b7634afd`; Beacon `90f8d7a0-13c6-4ea5-ab32-a3139051aa57`. Title vi sau sửa: “Trống đồng đã cập nhật từ Web”; title en: “Acceptance bronze drum”. ID được đối chiếu xuyên ba lớp trong JSON; token/password không nằm trong báo cáo.

## Mobile matrix

| ID / mục tiêu | Preconditions / steps | Expected | Actual / status | Evidence / Bug |
|---|---|---|---|---|
| MB-01 / Site backend | P-Client; HttpVisitorApi.loadSites | Có Site ID do Web tạo | **PASS client**; device display **BLOCKED** | mobile-client-results.json; ENV-03 |
| MB-02 / Artifact backend | P-Client; loadArtifacts | Có Artifact ID do Web tạo | **PASS client**; device **BLOCKED** | cùng JSON; ENV-03 |
| MB-03 / nội dung Web | P-Client; loadArtifact | Đúng code, Site ID, title | **PASS client**; hiển thị thật **BLOCKED** | live log/JSON; ENV-03 |
| MB-04 / cập nhật Web | Web lưu title vi mới rồi client tải | Title mới khớp SQL | **PASS client**; refresh trên device **BLOCKED** | web results + SQL + Flutter; ENV-03 |
| MB-05 / vi-en | Load cùng ID với vi và en | Đúng hai title/code, không fallback | **PASS client**; thao tác locale UI thật **BLOCKED** | Flutter live + unit/widget172; ENV-03 |
| MB-06 / ảnh thật | Tải URL media bằng HTTP, Flutter instantiateImageCodec | HTTP200, frame width/height>0 | **PASS tải/decode**; hiển thị device **BLOCKED** | flutter-live-backend.log, web-real-image.jpg; ENV-03 |
| MB-07 / audio-video | P-Device, media audio/video hợp lệ, play/seek | Âm thanh/hình động thực | Không có device/emulator, chưa phát thật / **BLOCKED** | ENV-03/04; không dùng URL làm bằng chứng play |
| MB-08 / resolve | P-Client; BeaconContentService với UUID/major/minor Web tạo | Đúng Artifact/Site/title; không incidental visit | **PASS API/client**; BLE packet thật **BLOCKED** | Flutter live + history rỗng trước record; ENV-03 |
| MB-09 / lỗi API | Load UUID không tồn tại qua API thật | VisitorApiException status404 | **PASS client**; UI thật **BLOCKED** | Flutter live; error widgets có unit tests; ENV-03 |

## Favorite / History / ownership

| ID / mục tiêu | Preconditions / steps | Expected | Actual / status | Evidence / Bug |
|---|---|---|---|---|
| FAV-01 / thêm và SQL | P-Client; đăng ký/login A; addFavorite; SQL SELECT | Một row đúng A/artifact | **PASS** | sql-favorite-added.json favorite_count1; — |
| FAV-02 / tồn tại sau login lại | Bỏ token cũ, gọi login A lại, GET favorites | Artifact vẫn có | **PASS service/API/DB**; mobile logout UI chưa chạy | mobile-client-results.json; ENV-03 chỉ cho UI |
| FAV-03 / riêng tư | Login B mới; GET favorites bằng B | Không thấy Favorite A | **PASS** | live test asserts B empty; — |
| FAV-04 / xóa | A DELETE rồi GET; SQL SELECT lần2 | Không còn row | **PASS** | sql-favorite-removed.json favorite_count0; — |
| HIST-01 / record | A gọi recordVisit sau resolve |201 + user/beacon/timestamp đúng | **PASS contract hiện hành** | SQL JSON và Flutter; BUS-01 cho trigger UI/nghiệp vụ |
| HIST-02 / bền vững | Login A lại, loadVisits | Đúng một visit/artifact, timestamp UTC | **PASS** | mobile-client-results.json, SQL timestamp so bằng datetime; — |
| HIST-03 / riêng tư | B loadVisits | Không thấy history A | **PASS** | live test B empty; — |
| HIST-04 / chống lặp | A record lần2 ngay; SELECT SQL | 200 cùng UUID; một row | **PASS kỹ thuật** | SQL visit_count1; BUS-01 cho quy tắc |
| HIST-05 / lượt sau hợp lệ | Reuse VL-05 biên301 giây trên graph test khác | Thêm một lượt hợp lệ theo code hiện có | **PASS kỹ thuật; BLOCKED nghiệp vụ** | concurrency log; BUS-01 |

## Chạy lại

Harness là opt-in, không tự chạy test integration cần SQL/network trong flutter test unit mặc định. Mọi lần nghiệm thu cần graph Web mới, tránh dùng lại graph đã có VisitLog của lần trước.

1. Tạo SQL Server riêng, DB test_* mới qua `backend/scripts/provision_test_database.py`, TEST_DATABASE_TOKEN ngẫu nhiên >=32 ký tự; migrate đúng TEST_DATABASE_URL và seed init_db. Giữ DATABASE_URL của runner khác tên DB test; không đưa secret vào source/log.
2. Chạy uvicorn app.main:app trên cổng QA, DATABASE_URL của **server** trỏ DB test; FRONTEND_HOST trùng origin Web. Chạy Vite với VITE_API_URL trỏ API QA. Phục vụ ảnh thật ở origin QA_MEDIA_URL.
3. Set QA_API_URL, QA_WEB_URL, QA_MEDIA_URL, QA_ADMIN_EMAIL/PASSWORD và QA_HANDOFF_FILE (file tạm ngoài Git). Từ repo: `node scripts/qa/web_admin_acceptance.cjs`. Script giới hạn origin loopback, ghi graph tạm và public evidence.
4. Set QA_PYTHON (python venv tuyệt đối), QA_SQL_ASSERT_SCRIPT (scripts/qa/verify_sqlserver.py tuyệt đối), QA_MOBILE_RESULTS_FILE và QA_EVIDENCE_DIR (docs/qa/evidence tuyệt đối). Giữ TEST_DATABASE_URL/TOKEN và DATABASE_URL khác DB test trong runner.
5. Tại mobile_app: `flutter test acceptance/live_backend_test.dart --reporter expanded`. Test dùng client thật, gọi Python SELECT verifier ở checkpoint Favorite đã thêm và đã xóa; cần Python deps của backend. Kết quả phiên này: **1 live test PASS**, 9 checkpoint PASS.
6. Để mở BLOCKED device: kết nối Android/iOS, cấu hình URL QA reachable từ máy (loopback điện thoại không phải máy dev), đăng nhập hai user mới, thực hiện MB-01..09/FAV/HIST bằng UI; quay video/screenshot có ID. Phát audio/video thật, kiểm tra play/seek/error; thử BLE beacon đúng mapping. Việc này là nghiệm thu riêng, không sửa giới hạn loopback của harness để trỏ production.

Unit/widget mocks được giữ cho regression nhanh; chúng không thay thế chứng nhận SQL/network thực hoặc phát media trên device. Không lỗi sản phẩm mới nào được tái hiện trong phần integration đã chạy; lỗi harness selector khi xây dựng đã được sửa, sau đó chạy lại graph mới và PASS.

Log được chuẩn hóa đường dẫn máy thành <WORKSPACE> và whitespace cuối dòng theo hook repository; kết quả/exit code giữ nguyên.
