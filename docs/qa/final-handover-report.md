# Smart Heritage — bàn giao 08/11/2026

> Cập nhật theo chỉ dẫn người dùng: áp dụng tạm quy tắc300 giây, chỉ ghi khi người dùng mở nội dung Artifact. **Vẫn chờ P2 xác nhận chính thức.** Source/test mới ở commit `436be108d7cb31825ef25db4021a29c152cd88c0`; xem [bản cập nhật quy tắc tạm thời](visit-rule-provisional-update.md). Kết quả SHA cũ bên dưới là bằng chứng lịch sử.

## Git

- Nhánh làm việc: `fix/visitlog-flutter-ci-e2e-acceptance`.
- Integration xác minh từ remote HEAD sau fetch: `origin/main`.
- Commit trước: `00efd84ba58f5e5597e79090dc9ef437665b3ac9`.
- Commit implementation + evidence đã kiểm thử: `672b8796966674156d1874e8361cc75b0fc23c63`.
- Commit đóng gói báo cáo: chính commit chứa bản báo cáo này; lấy SHA tuyệt đối bằng `git log -1 --format=%H -- docs/qa/final-handover-report.md`. Full SHA bàn giao cũng được trả trong tin nhắn cuối. Không thể nhúng hash của một commit vào chính nội dung của nó.
- Tệp có sẵn chưa commit `docs/backend-audit-plan-2026-11-06.md` được giữ nguyên và không đưa vào commit tác vụ. Không reset/clean/stash, push, tạo PR hoặc merge.

## Kết quả cập nhật theo chỉ dẫn tạm thời

Flutter hiện có **184 test PASS**, analyze sạch; thêm1 live test dùng widget/HTTP thật chứng minh201 lần mở đầu,200 lần mở lại và một row SQL. Đã sửa trigger preview/manual detail; không đổi schema hoặc cửa sổ300 giây. Chưa có stable view_session_id, chưa triển khai ngoại lệ reentry trong300 giây. P2 và các gate còn BLOCKED/FAIL vẫn giữ nguyên. Chi tiết và file mới ở bản cập nhật được liên kết phía trên.

## Kết quả trước cập nhật

| Hạng mục | Kết quả / bằng chứng |
|---|---|
| VisitLog concurrency | **PASS kỹ thuật**, VL-01..07 + negative control trên SQL Server; **BLOCKED nghiệm thu nghiệp vụ** BUS-01 |
| Valid subsequent visits | **PASS theo hợp đồng code hiện có**, biên299/300/301; **BLOCKED phê duyệt P2** |
| Flutter pub get | **PASS** lần cuối exit0; log lần đầu lỗi symlink được giữ |
| Flutter analyze | **PASS**, No issues found, gồm live harness mới |
| Flutter test | **PASS 172 unit/widget**, thêm **1 test live HTTP/SQL** với9 checkpoint |
| GitHub Actions triggers | **PASS static**: YAML16/16, actionlint và zizmor exit0; **BLOCKED run đúng SHA trên GitHub** vì chưa push |
| Web -> SQL Server | **PASS**, Chrome8 kiểm tra thật và SELECT đối chiếu database QA |
| SQL Server -> Mobile | **PASS HTTP client/parsing/decode**, **BLOCKED UI thiết bị Android/iOS thật** |
| Real media playback | JPEG tải/decode **PASS**; audio/video playback thật **BLOCKED** |
| Favorite per user | **PASS API/client/SQL**: A thêm, login lại còn, B rỗng, A xóa, SQL1->0; UI device chưa nghiệm thu |
| History per user | **PASS API/client/SQL**: A login lại còn1, B rỗng, request lặp cùng UUID, timestamp khớp; BUS-01 chờ nghiệp vụ |
| Repository pre-commit | **FAIL có sẵn**: mypy14 errors và ty8 diagnostics; baseline archive cùng venv tái hiện, không tắt hooks (LINT-01) |
| Backend regression | **353 passed**, không lỗi; warning Starlette/httpx có sẵn |
| Frontend typecheck / Python lint-format | **PASS**, xem static-checks.log |

Chi tiết test ID, preconditions, steps, expected/actual, status, evidence, commit và Bug ID nằm trong [concurrency](visitlog-concurrency-report.md), [Flutter CI](flutter-ci-report.md), [integration](web-mobile-sqlserver-acceptance.md), [bug list](bug-list.md).

## Đã làm / lỗi đã xử lý

Bổ sung Flutter workflow đúng mobile_app/SDK3.47.7/cache, chạy3 lệnh chuẩn. Sửa stale branch filters master sang integration main, giữ nguyên Backend/Frontend CI và chuẩn coverage/lint. Bổ sung kiểm thử thực cho burst, user/artifact độc lập, biên thời gian, rollback, hai process; thêm harness opt-in Web/Flutter/SQL cùng graph và ảnh thật. Viết báo cáo cùng log/JSON/screenshot.

Không thêm “bản vá race” production: code hiện tại đã có khóa SQL Server và baseline đã PASS. Negative control xác nhận bỏ khóa sẽ ghi trùng. Không dùng in-memory lock thay SQL, không đổi thời gian300giây, không thêm unique constraint chặn lượt sau.

**Database schema: không thay đổi.** Chỉ áp dụng migrations hiện có trên DB QA mới, không chỉnh migration đã áp dụng, không xóa/reset dữ liệu ứng dụng. DB/container QA đã dừng và được giữ lại; các server QA đã dừng.

## File thay đổi

Source/config/test:

- `_typos.toml` (bổ sung từ tiếng Việt hợp lệ và tên job kỹ thuật hiện có; không tắt spell checker)
- `.github/workflows/test-flutter.yml`
- `.github/workflows/zizmor.yml`
- `.github/workflows/playwright.yml`
- `.github/workflows/deploy.yml`
- `backend/tests/api/routes/test_visit_consistency.py`
- `backend/tests/api/routes/test_visit_acceptance.py`
- `backend/tests/utils/visit_worker.py`
- `mobile_app/acceptance/live_backend_test.dart`
- `scripts/qa/web_admin_acceptance.cjs`
- `scripts/qa/verify_sqlserver.py`

Báo cáo:

- `docs/qa/visitlog-concurrency-report.md`
- `docs/qa/flutter-ci-report.md`
- `docs/qa/web-mobile-sqlserver-acceptance.md`
- `docs/qa/bug-list.md`
- `docs/qa/final-handover-report.md`

Minh chứng được commit:

- `docs/qa/evidence/acceptance-seed.log`
- `docs/qa/evidence/actionlint.log`
- `docs/qa/evidence/backend-baseline.log`
- `docs/qa/evidence/backend-regression.log`
- `docs/qa/evidence/environment.json`
- `docs/qa/evidence/flutter-analyze.log`
- `docs/qa/evidence/flutter-live-backend.log`
- `docs/qa/evidence/flutter-pub-get-initial.log`
- `docs/qa/evidence/flutter-pub-get.log`
- `docs/qa/evidence/flutter-test.log`
- `docs/qa/evidence/git-preparation.log`
- `docs/qa/evidence/mobile-client-results.json`
- `docs/qa/evidence/sql-favorite-added.json`
- `docs/qa/evidence/sql-favorite-removed.json`
- `docs/qa/evidence/sqlserver-migrate.log`
- `docs/qa/evidence/sqlserver-provision.log`
- `docs/qa/evidence/sqlserver-start.log`
- `docs/qa/evidence/sqlserver-stop.log`
- `docs/qa/evidence/static-checks.log`
- `docs/qa/evidence/visitlog-concurrency.log`
- `docs/qa/evidence/web-admin-results.json`
- `docs/qa/evidence/web-admin.log`
- `docs/qa/evidence/web-artifact.png`
- `docs/qa/evidence/web-beacon.png`
- `docs/qa/evidence/web-real-image.jpg`
- `docs/qa/evidence/workflow-validation.log`
- `docs/qa/evidence/zizmor.log`

- `docs/qa/evidence/baseline-mypy.log`
- `docs/qa/evidence/baseline-ty.log`
- `docs/qa/evidence/baseline-source-comparison.log`
- `docs/qa/evidence/pre-commit.log`

## Lệnh kiểm chứng đã chạy

Tại backend, với identity test DB hợp lệ: `python -m pytest -p no:cacheprovider -v` (353 pass); baseline19 và concurrency subset13 có log riêng. Tại mobile_app: `flutter pub get`, `flutter analyze`, `flutter test --reporter expanded`, và `flutter test acceptance/live_backend_test.dart --reporter expanded` với QA env riêng. Web: `node scripts/qa/web_admin_acceptance.cjs` với Chrome có sẵn và QA env. SQL checkpoints do `scripts/qa/verify_sqlserver.py` chạy SELECT trên DB đã xác minh marker/token.

Đã chạy actionlint1.7.7 (release SHA256 verified), YAML/trigger assertions, zizmor --offline, ruff check/format --check, node --check, tsc --noEmit. Workflow remote/real Mobile playback không có kết quả chạy, được giữ BLOCKED. Xem evidence log cho stdout/exit code thực, không dựa tài liệu cũ để cấp PASS.

## Còn lại / rủi ro / khả năng merge

1. P2 xác nhận BR-05: thời điểm bắt đầu lượt, cửa sổ/điều kiện lượt mới, reentry, user/artifact/session; mở Artifact thủ công có tính không. **PENDING BUSINESS DECISION**; không tự quyết định (BUS-01).
2. Người dùng chủ động push/tạo PR khi sẵn sàng, kiểm tra required GitHub Actions đúng full SHA; local PASS chưa chứng nhận remote CI (CI-03).
3. Cần Android/iOS để nghiệm thu UI/locale/session/BLE, ảnh hiển thị và audio/video play/seek/error (ENV-03/04). Test live hiện là client Flutter, không phải ứng dụng trên điện thoại.
4. Runtime uvicorn nhiều worker cần xác minh Linux/CI vì Windows shared socket lỗi10022; hai interpreter cạnh tranh SQL lock đã PASS (ENV-02).
5. Deploy filter nay là main: push/merge main kích hoạt deploy sẵn có, cần kiểm tra cloud/database secrets/vars đúng môi trường trước merge (OPS-01); không chạy deploy trong phiên.
6. **LINT-01: pre-commit FAIL** vì14 lỗi mypy và8 diagnostics ty trong3file app có sẵn; baseline archive tái hiện đúng. Cần task sửa type riêng trước merge; không tắt lint hoặc hạ chuẩn.
7. Có sẵn ngoài phạm vi: Mobile password recovery chỉ delay, chưa nối endpoint (BUG-OUT-01); cần task riêng.

**Có thể tạo draft PR để review thay đổi; chưa đủ điều kiện chấp thuận merge/nghiệm thu đầy đủ** trước khi các gate type-check, CI remote, P2, thiết bị/media và deployment readiness được xử lý. Runtime tests PASS; gate type-check FAIL có sẵn vẫn OPEN và chặn merge.

Log được chuẩn hóa đường dẫn máy thành <WORKSPACE> và whitespace cuối dòng theo hook repository; kết quả/exit code giữ nguyên.
