# Quy tắc VisitLog tạm thời — cập nhật 08/11/2026

- Nhánh: `fix/visitlog-flutter-ci-e2e-acceptance`.
- Commit trước cập nhật: `ba890fa8664d1d5b1e6dccbf68d82840b6549245`.
- Commit implementation được kiểm thử: `436be108d7cb31825ef25db4021a29c152cd88c0`. SHA này áp dụng cho test mới dưới đây; bằng chứng backend trước đó gắn với `672b8796966674156d1874e8361cc75b0fc23c63`.
- **Được người dùng thống nhất tạm thời để triển khai/kiểm thử; chưa phải phê duyệt chính thức P2. PENDING BUSINESS DECISION vẫn giữ nguyên.**

## Quy tắc áp dụng hiện tại

1. Chỉ ghi khi người dùng thực sự mở trang nội dung Artifact, dữ liệu backend tải thành công và được render trên route hiện hành. Phát hiện Beacon, GET resolve, bản xem trước tự hiện, đổi tab hoặc nhận thêm BLE packet không tạo VisitLog.
2. Backend/SQL Server quyết định chống trùng theo **user + artifact trong300 giây**. Request đồng thời dùng transaction lock hiện có; không đưa in-memory lock lên làm cơ chế bảo vệ duy nhất.
3. Mở lại trang gửi request mới tới backend. Trong cửa sổ:200 và cùng VisitLog ID; hết cửa sổ:201 cho lượt mới theo quy tắc tạm thời. Mobile không giữ cache thành công suốt ứng dụng để chặn một lượt mở hợp lệ về sau.
4. Rebuild, đổi ngôn ngữ hoặc request còn đang chạy trong cùng lần mở không tự gửi thêm request. Lỗi ghi lượt giữ nội dung và yêu cầu thao tác Retry rõ ràng. Không ghi cho anonymous/demo, nội dung tải lỗi, nội dung stale hoặc route bị che.
5. Mở thủ công có beacon_id/rssi null; mở từ nút chi tiết ở màn quét giữ Beacon ID và RSSI đã đo. Quy tắc300 giây không đổi theo nguồn mở.
6. Đây là quy tắc tạm thời theo chỉ dẫn người dùng. Không đánh dấu nghiệm thu nghiệp vụ chính thức PASS khi P2 chưa xác nhận.

## Lỗi đã tái hiện và xử lý

| Bug | Baseline thực tế | Sửa |
|---|---|---|
| VISIT-OPEN-01 | Scanner tự POST sau khi preview render, dù chưa bấm mở chi tiết | Bỏ auto-record ở BeaconTestPage/BeaconContentPanel; chỉ preview/resolve không ghi |
| VISIT-OPEN-02 | ArtifactDetailPage mở thủ công không POST VisitLog | Ghi sau frame hiển thị nội dung backend thành công; ràng buộc artifact/token/current route |

Dùng VisitorApi.recordVisit đã tồn tại, không tạo API mới hay đổi kiến trúc. Local state chỉ chống request lặp trong cùng lần mở; token và revision tách lỗi/kết quả của lần mở cũ. Một route được dùng lại A -> B -> A vẫn gửi request cho từng lần mở mới, để backend quyết định hợp lệ. Khóa SQL, cửa sổ300 giây, schema và migrations giữ nguyên.

Các assertion cũ mong scanner tự ghi lượt đã được chuyển sang mong **không ghi preview** theo yêu cầu mới. Các kiểm tra RSSI, ngưỡng yếu, hysteresis3 tín hiệu, loại bỏ resolve cũ và chuyển Beacon vẫn giữ. Bổ sung12 test dương/âm cho trang chi tiết, không bỏ test hoặc hạ lint để tạo PASS.

## Mobile có phiên xem riêng biệt chưa?

**Chưa có mã phiên xem bền vững được backend/SQL nhận và lưu.** AuthSession là phiên đăng nhập; VisitReservation.sequence, content revision và local page revision chỉ là trạng thái trong bộ nhớ. Chúng không đủ để phân biệt một lượt quay lại hợp lệ trong300 giây trên nhiều thiết bị/retry/worker.

Vì vậy **không triển khai ngoại lệ quay lại trong300 giây**. Mở lại vẫn gửi request và nhận lượt cũ200. Để P2 cân nhắc sau: nếu nghiệp vụ muốn phân biệt mỗi lần mở/rời/quay lại, có thể tạo view_session_id cho một lần mở và tái sử dụng ID đó cho retry; server lưu và chống trùng theo user/artifact/session. Cần P2 định nghĩa điểm kết thúc phiên và điều kiện reentry, sau đó thiết kế migration/unique key theo session và kiểm thử nhiều worker. Đây chỉ là đề xuất; chưa thêm field, migration, endpoint hoặc logic bypass cửa sổ hiện tại.

## Test cases và bằng chứng

Preconditions unit/widget: Flutter3.47.7/Dart3.13.5, fake service chỉ để quan sát trigger UI; không dùng unit mocks để kết luận SQL PASS. Preconditions live: SQL Server QA `test_acceptance_7c7c86e0` với token identity, Web localhost5174, API localhost8011, graph Web mới và credentials ngẫu nhiên ngoài Git. Backend đang dùng đúng schema/code đã kiểm thử trước; không truy cập DB ứng dụng. Commit và Bug ID áp dụng như bảng.

| Test ID / mục tiêu | Steps | Expected | Actual / status | Evidence / Bug |
|---|---|---|---|---|
| OPEN-BEFORE / tái hiện | Chạy10 test trigger mới trước sửa product | Mở nội dung có POST; preview không POST | **3 PASS / 7 FAIL**, tái hiện thiếu POST ở chi tiết và POST ở preview | artifact-open-before.log; VISIT-OPEN-01/02 |
| OPEN-01 / mở chi tiết | Giữ Future nội dung pending; hoàn tất; render | Pending0POST; sau render1POST đúng user/artifact | **PASS** | artifact-open-regression.log; VISIT-OPEN-02 fixed |
| OPEN-02 / tải lỗi | Trả404 khi loadArtifact | Không VisitLog | **PASS** | cùng log; — |
| OPEN-03 / rebuild-ngôn ngữ | Mở, rebuild và vi/en; thêm trường hợp POST còn pending | Không tự POST thêm | **PASS** | hai test mới trong cùng log; — |
| OPEN-04 / route bị che | Resolve chi tiết dưới route khác rồi pop | Chỉ ghi khi trang chi tiết thực sự hiện | **PASS** | cùng log; — |
| OPEN-05 / đổi account | A load pending; đổi B; hoàn tất A rồi B | Không gán nội dung A cho lượt B; chỉ ghi nội dung hiện hành của B | **PASS** | cùng log; — |
| OPEN-06 / retry | POST fail503, rebuild, bấm retry | Không tự lặp vô hạn; retry1 lần, nội dung giữ nguyên | **PASS** | cùng log; — |
| OPEN-07 / mở lại | Pop/push chi tiết; tái sử dụng state A/B/A | Mỗi lần mở mới được gửi tới backend, không bị local cache chặn | **PASS** | hai test mới; — |
| OPEN-08 / không xác thực | Anonymous và demo mở chi tiết | Không authenticated POST | **PASS** | hai test; — |
| OPEN-09 / Beacon | Resolve +5 packet +preview; bấm nút mở chi tiết | Trước bấm0POST; sau bấm1POST có Beacon/RSSI tại lúc mở (không bị packet đến sau ghi đè) | **PASS** | artifact_visit_trigger_test.dart và regression log; VISIT-OPEN-01 fixed |
| OPEN-LIVE-01 | Home có nút mở, trước khi bấm query History và số POST | Không VisitLog trước mở | **PASS HTTP/widget thật** | artifact-open-live/mobile-results.json; — |
| OPEN-LIVE-02 | Bấm mở trang chi tiết, load nội dung Web thật | Title Web render, POST201 | **PASS** | flutter-widget.log + mobile-results.json; — |
| OPEN-LIVE-03 | Pop rồi mở lại ngay | POST200, History cùng UUID, một row | **PASS** | HTTP statuses [201,200]; — |
| OPEN-LIVE-04 | Python verifier xác minh token rồi SELECT | SQL khớp user/artifact/timestamp, visit_count1, manual Beacon/RSSI null | **PASS SQL thật** | artifact-open-live/sql-artifact-opened.json; — |
| OPEN-AFTER-WINDOW | Tái sử dụng VL-05, SQL real biên299/300/301 |301 thêm1 lượt;299/300 reuse | **PASS kỹ thuật theo quy tắc tạm thời** | visitlog-concurrency.log; chưa phải phê duyệt P2 |
| OPEN-REGRESSION | pub get, analyze, flutter test toàn bộ | Exit0, không lỗi mới | **PASS184 test**, analyze sạch | artifact-open-pub-get.log, artifact-open-analyze.log, artifact-open-regression.log; — |
| OPEN-PRECOMMIT | Hooks chuẩn repo trên file cập nhật | Không lỗi mới | Xem provisional-pre-commit.log: mypy14/ty8 có sẵn vẫn FAIL; các gate khác không bị tắt | LINT-01 có sẵn |

Trong lần live đầu, harness dùng chung pooled HTTP connection giữa fake async zone của widget và runAsync bị timeout sau response200 của backend. Đã tách control client chạy real async và giữ nguyên client sản phẩm; chạy lại graph mới PASS. Log ban đầu được giữ ở artifact-open-live/flutter-widget-initial.log; đây là lỗi harness đã xử lý, không che bằng mock hoặc đổi timeout sản phẩm.

## Lệnh tái chạy

~~~text
# Tại mobile_app
flutter pub get
flutter analyze
flutter test --reporter expanded
flutter test test/artifact_visit_trigger_test.dart --reporter expanded
flutter test acceptance/artifact_open_live_test.dart --reporter expanded
~~~

Live test cần các QA env đã mô tả trong web-mobile-sqlserver-acceptance.md. Set QA_EVIDENCE_DIR sang thư mục riêng, QA_MOBILE_RESULTS_FILE và QA_HANDOFF_FILE ngoài luồng unit; Web script tạo graph mới trước mỗi lần chạy. Harness thật dùng HTTP loopback; HttpOverrides chỉ trong test opt-in để cho phép real socket, không thay implementation app và không trả response giả.

Backend353 và concurrency13 trước đó vẫn là bằng chứng lịch sử trên source backend không đổi; không nói đã chạy lại toàn bộ backend ở lượt này. UI184 và live widget là kết quả mới. Chưa có Android/iOS, BLE vật lý hoặc audio/video playback thật; các mục đó, CI remote, OPS-01 và P2 vẫn BLOCKED. Server/container QA đã dừng, dữ liệu QA giữ lại. Không push/PR/merge.

## File source/config/test trong cập nhật

- `mobile_app/lib/features/artifacts/artifact_detail_page.dart`
- `mobile_app/lib/features/beacon/beacon_content_panel.dart`
- `mobile_app/lib/features/beacon/beacon_tools_page.dart`
- `mobile_app/lib/features/visits/visit_log_service.dart`
- `mobile_app/test/artifact_visit_trigger_test.dart`
- `mobile_app/test/beacon_rssi_test.dart`
- `mobile_app/test/beacon_scan_content_test.dart`
- `mobile_app/test/beacon_visit_log_test.dart`
- `mobile_app/acceptance/artifact_open_live_test.dart`
- `scripts/qa/verify_sqlserver.py`
- `scripts/qa/web_admin_acceptance.cjs`
- `mobile_app/_typos.toml`

Minh chứng mới: `docs/qa/evidence/artifact-open-*.log`, `docs/qa/evidence/artifact-open-live/` và `docs/qa/evidence/provisional-pre-commit.log`. Log đã chuẩn hóa đường dẫn máy/whitespace, giữ nguyên kết quả và exit code. `mobile_app/_typos.toml` chỉ nhận diện từ tiếng Việt hợp lệ trong copy hiện có, không tắt spell checker.
