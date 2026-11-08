# VisitLog concurrency — 08/11/2026

> Cập nhật theo chỉ dẫn người dùng: áp dụng tạm quy tắc300 giây, chỉ ghi khi người dùng mở nội dung Artifact. **Vẫn chờ P2 xác nhận chính thức.** Source/test mới ở commit `436be108d7cb31825ef25db4021a29c152cd88c0`; xem [bản cập nhật quy tắc tạm thời](visit-rule-provisional-update.md). Kết quả SHA cũ bên dưới là bằng chứng lịch sử.

- Nhánh: `fix/visitlog-flutter-ci-e2e-acceptance`.
- Baseline: `00efd84ba58f5e5597e79090dc9ef437665b3ac9`.
- Commit kiểm thử sau bổ sung: `672b8796966674156d1874e8361cc75b0fc23c63`. SHA này áp dụng cho mọi test sau thay đổi trong báo cáo.
- Kết quả kỹ thuật: **PASS** trên SQL Server thật. Nghiệm thu nghiệp vụ: **BLOCKED — PENDING BUSINESS DECISION (BUS-01)**.

## Khảo sát source thực tế

| Thành phần | Kết quả |
|---|---|
| Model/schema | `backend/app/models.py`: VisitLog có user_id, artifact_id, beacon_id, language_id, visited_at, rssi, duration_seconds; user lấy từ JWT, không nhận từ payload. |
| Migration/index | `2af237ad3b09_add_smart_heritage_tables.py`: PK UUID, FK; index artifact_id và visited_at; không unique(user, artifact), nên cho phép quay lại hợp lệ. |
| Ghi lượt | `POST /api/v1/visits/` trong `api/routes/visits.py`; xác thực Visitor/Admin, kiểm tra Artifact/Site hiển thị, Beacon đúng site/artifact và Language hoạt động. |
| Chống trùng | `crud.find_recent_visit`: cùng user + artifact, visited_at >= now - 300 giây; 200 trả lượt cũ, 201 tạo lượt mới. |
| Transaction | Route đã gọi `acquire_transaction_lock(session, visit:user:artifact)` trước check/insert; helper dùng connection của transaction đang hoạt động và SQL Server sp_getapplock Exclusive/Transaction. Commit/rollback/đóng session giải phóng khóa; timeout lỗi 409. |
| Resolve | `GET /beacons/resolve` trả nội dung/mapping, cập nhật thông tin beacon; không tự ghi VisitLog. |
| History | `GET /visits/me` lọc user JWT; join Artifact/Site hoạt động; phân trang và dịch theo ngôn ngữ. |
| Mobile | `BeaconContentController.recordDisplayedContent` và panel callback sau hiển thị; VisitDeduplicator chặn pending/lặp theo artifact, reset khi đổi phiên, dùng visited_at server; không ghi trên mọi packet BLE. |
| Mở Artifact thủ công | `ArtifactDetailPage` tải nội dung và quản lý Favorite, ở baseline chưa ghi VisitLog; cập nhật này đã ghi sau khi người dùng mở và render nội dung thành công, theo chỉ dẫn tạm thời. P2 vẫn cần phê duyệt chính thức (BUS-01). |

Khóa SQL đã tồn tại ở baseline (lịch sử gồm commit c44874c). Không tái hiện được ghi trùng trên implementation hiện tại. Không thêm bản vá production trùng lặp, không đổi 300 giây và không thêm migration/constraint. Race check-then-insert vẫn tái hiện được nếu bỏ khóa **chỉ trong negative control của test**: hai connection cùng đọc không có lượt rồi cùng INSERT; SQL lưu hai UUID khác nhau.

## Quyết định nghiệp vụ

Code/comment BR-05 ghi “thống nhất với app - P4”; tài liệu `docs/api_samples.md` mục 6 mô tả 300 giây. Không tìm thấy phê duyệt chính thức P2 trong tài liệu được khảo sát; người dùng đã thống nhất tạm thời300 giây và chỉ ghi khi mở nội dung Artifact, nhưng chưa công nhận là quyết định chính thức P2.

Đề xuất P2 xác nhận nguyên trạng: bắt đầu khi nội dung beacon được hiển thị; cùng user/artifact trong cửa sổ tính một lượt; đổi ngôn ngữ/phiên hoặc rời rồi quay lại trong cửa sổ vẫn trả lượt cũ; sau cửa sổ tạo lượt mới. P2 cần chốt thêm lượt mở Artifact thủ công có được tính không và có cần session/điều kiện rời vùng thay thời gian không. Đề xuất này **chưa phải quyết định**.

## Test matrix

Preconditions chung: SQL Server 2022 mới, DB `test_acceptance_7c7c86e0` provision bằng token riêng và Alembic upgrade head; fixture xác minh DB identity trước mọi test. Site/Artifact/user kiểm thử riêng. Không mock database hoặc override get_db. Mỗi request có session/connection thực. Bug ID “—” nghĩa là không có lỗi sản phẩm tái hiện trên code hiện tại.

| Test ID / mục tiêu | Steps | Expected | Actual / status | Evidence / Bug |
|---|---|---|---|---|
| VL-01 / hai request cùng user/artifact | Barrier bắt đầu 2 HTTP requests; làm chậm read để mở race; SELECT sau requests | 1 lượt, 201 + 200, cùng UUID | Đúng / **PASS** | visitlog-concurrency.log; — |
| VL-02 / burst | Như VL-01 với 12 thread/request | 1 lượt, một 201 và 11 lần 200 | Đúng / **PASS** | cùng log; — |
| VL-03 / hai user | Hai user cùng Artifact; barrier tại read chứng minh chồng lấp | Hai 201, hai row có user_id khác nhau | Đúng / **PASS** | test_visit_acceptance.py [VL-03]; — |
| VL-04 / hai Artifact | Một user, hai Artifact; barrier tại read | Hai row riêng, cùng user; không khóa toàn cục | Đúng / **PASS** | [VL-04]; — |
| VL-05 / lượt kế tiếp | Đặt timestamp row QA cách now 299/300/301 giây; cố định clock cutoff; gửi hai request đồng thời | 299/300: dùng cũ; 301: thêm đúng một row | Đúng ở cả ba biên / **PASS kỹ thuật** | [VL-05-before/boundary/after]; nghiệp vụ BUS-01 |
| VL-06 / rollback | Flush INSERT thật, gây lỗi trước commit; SELECT=0; retry hai request | HTTP500 không lưu row; retry tạo đúng một row, khóa được thả | Đúng / **PASS** | test_flushed_insert_rolls_back_and_retry_releases_lock; — |
| VL-07 / nhiều process | spawn hai interpreter với app/engine độc lập; barrier; HTTP; kiểm tra PID khác nhau và DB | Một 201, một 200, một UUID/row | Đúng / **PASS** | test_separate_application_processes_share_database_lock; — |
| VL-NC / độ nhạy harness | Tạm bỏ lock trong test, barrier sau read rồi INSERT | Hai 201/hai UUID/hai row, chứng minh race khi không bảo vệ | Đúng / **PASS negative control** | test_unprotected_negative_control_reproduces_read_insert_race; không phải lỗi code bàn giao |
| VL-REG / liên kết không hợp lệ | Beacon inactive/sai site, Language inactive | 400/404, không VisitLog | Ba trường hợp đúng / **PASS** | visitlog-concurrency.log; — |
| VL-LIVE-WORKERS / Uvicorn 2 workers trên Windows | Chạy server thật workers=2 | Cả worker phục vụ HTTP | WinError10022 khi share socket / **BLOCKED môi trường** | environment.json; ENV-02; không thay cho kết quả VL-07 |

## Lệnh và kết quả

Tại `backend/`, với TEST_DATABASE_URL/TOKEN của DB riêng và DATABASE_URL khác DB test:

~~~text
python -m pytest -p no:cacheprovider tests/api/routes/test_visit_consistency.py tests/api/routes/test_visits.py tests/api/routes/test_backend_sqlserver_flow.py tests/api/routes/test_favorites.py -v
python -m pytest -p no:cacheprovider tests/api/routes/test_visit_acceptance.py tests/api/routes/test_visit_consistency.py -v
python -m pytest -p no:cacheprovider -v
~~~

- Baseline: **19 passed** — [backend-baseline.log](evidence/backend-baseline.log).
- Concurrency mở rộng: **13 passed** — [visitlog-concurrency.log](evidence/visitlog-concurrency.log).
- Regression đầy đủ: **353 passed**, một deprecation warning Starlette/httpx có sẵn — [backend-regression.log](evidence/backend-regression.log).
- Mock chỉ dùng ở negative control/fault injection, còn INSERT/SELECT/rollback/lock đều thực trên SQL Server. Negative control không thay code chạy thật.
- Lượt hợp lệ tiếp theo đã kiểm tra theo hợp đồng hiện hành; không thể kết luận PASS nghiệp vụ cho đến khi P2 phê duyệt.

Rủi ro còn lại: thao tác INSERT ngoài API không tự tuân thủ application lock; mọi writer cạnh tranh cần dùng cùng resource/transaction. Không thêm unique vĩnh viễn vì sẽ chặn lượt quay lại.

Log được chuẩn hóa đường dẫn máy thành <WORKSPACE> và whitespace cuối dòng theo hook repository; kết quả/exit code giữ nguyên.
