# Bugs, blockers & business decisions — 08/11/2026

Nhánh `fix/visitlog-flutter-ci-e2e-acceptance`; commit kiểm chứng `672b8796966674156d1874e8361cc75b0fc23c63`. Các mục môi trường/quyết định được phân biệt với lỗi sản phẩm. Không tạo GitHub Issues do yêu cầu chỉ commit local, không push/PR.

| ID | Loại / mức ảnh hưởng | Tái hiện & bằng chứng | Trạng thái / cách xử lý |
|---|---|---|---|
| CI-01 | Configuration / Medium | Không có workflow Flutter ở baseline | **FIXED**: thêm test-flutter.yml; pub get/analyze/test, SDK/cache/working directory; actionlint/zizmor/YAML PASS |
| CI-02 | Configuration / Medium | Remote HEAD main; zizmor và deploy push master; playwright còn filter master | **FIXED**: filters main; Flutter PR vào main, push main/feature/fix/integration; static matrix PASS |
| CI-03 | Verification blocker / High | Commit bàn giao chưa có trên remote, không có GitHub Actions run cùng SHA | **BLOCKED**: người dùng push/tạo PR khi sẵn sàng, xem required checks đúng SHA. Không tuyên bố remote PASS |
| LINT-01 | Existing type-check errors / High | mypy14 lỗi/3file, ty8 diagnostics trong sites.py/dashboard.py/seed_sample_data.py; archive baseline cùng code và cùng venv tái hiện đúng14/8 | **OPEN / FAIL gate**: có sẵn trước tác vụ; không sửa dashboard/seed ngoài phạm vi, không tắt hook. Logs baseline-mypy.log, baseline-ty.log, pre-commit.log |
| BUS-01 | Business / High | BR-05/comment P4 và API samples có 300 giây; không có xác nhận P2; manual ArtifactDetailPage không record visit như beacon | **PENDING BUSINESS DECISION**: chốt thời điểm bắt đầu, simultaneous requests, cửa sổ/điều kiện lượt mới, reentry và user/artifact/session; giữ nguyên hành vi, không tự áp thời gian mới |
| ENV-01 | Local setup / Low | flutter pub get đầu tiên exit1 vì symlink Windows; initial log | **RESOLVED trong phiên**: retry sau Flutter commands exit0, không đổi Windows Developer Mode, pubspec hoặc lint/test; lưu cả hai log |
| ENV-02 | Runtime verification / Medium | Uvicorn workers2 trên Windows share socket WinError10022 | **BLOCKED riêng runtime launcher**: live E2E dùng workers1; VL-07 hai process/app engine độc lập PASS. Xác minh uvicorn workers>=2 trên Linux/runner riêng, không suy diễn runtime Windows đã PASS |
| ENV-03 | Device verification / High | flutter devices chỉ Windows/Chrome/Edge, không Android/iOS | **BLOCKED**: nghiệm thu UI mobile/BLE/session/locale thật khi có thiết bị; HTTP client thực và unit/widget đã PASS |
| ENV-04 | Media verification / High | Chưa phát audio/video thật trong app; URL/metadata không đủ bằng chứng | **BLOCKED**: dùng media stream hợp lệ trên Android/iOS, play/seek/end/error và lưu video. JPEG HTTP/decode đã PASS, không đánh đồng playback |
| OPS-01 | Deployment readiness / High | Deploy trigger đã sửa main, secrets/vars/cloud account chưa kiểm chứng | **BLOCKED kiểm chứng**: xác minh DATABASE_URL/Cloud credentials/environment trước merge main vì push main sẽ kích hoạt deploy sẵn có; không deploy trong phiên |
| BUG-OUT-01 | Product ngoài phạm vi / Medium | mobile_app/lib/features/auth/auth_service.dart: requestPasswordRecovery chỉ delayed300ms, không HTTP | **OPEN**, có sẵn: UI quên mật khẩu không chứng minh email được gửi. Đề xuất task riêng nối endpoint và regression; chưa tự sửa ngoài3 nhiệm vụ |

## VisitLog

Không mở bug sản phẩm ghi trùng cho implementation hiện tại: baseline19 và concurrency mở rộng13 PASS trên SQL Server; full353 PASS. Negative control bỏ SQL lock trong test lưu2 row, chứng minh race gốc check-then-insert nếu không có khóa. Không phải kết quả FAIL của code bàn giao. Khóa đã tồn tại trước tác vụ, vì vậy không ghi nhận “đã sửa race” như thay đổi mới.

## Mục chưa chứng nhận

Mở Artifact thủ công ghi lượt hay chỉ Beacon là một phần BUS-01, không tự quyết định đó là bug. Các màn mock/preview/analytics ngoài luồng không được cấp PASS bởi test này. GitHub secrets, production media/CORS/network và thiết bị Mobile thật cần kiểm chứng ở môi trường tương ứng.

Runtime regression PASS, nhưng pre-commit tổng thể **FAIL** vì LINT-01 có sẵn. Một deprecation warning Starlette/httpx tồn tại ở baseline và full suite; không tắt hoặc đổi dependency ngoài phạm vi để che warning.

Log được chuẩn hóa đường dẫn máy thành <WORKSPACE> và whitespace cuối dòng theo hook repository; kết quả/exit code giữ nguyên.
