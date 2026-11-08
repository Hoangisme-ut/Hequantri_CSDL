# Flutter CI & GitHub Actions — 08/11/2026

Nhánh `fix/visitlog-flutter-ci-e2e-acceptance`; commit kiểm thử `672b8796966674156d1874e8361cc75b0fc23c63` áp dụng cho các test dưới đây. Baseline `00efd84ba58f5e5597e79090dc9ef437665b3ac9`.

**Flutter local/config PASS; pre-commit tổng thể FAIL có sẵn (LINT-01); GitHub Actions tại commit bàn giao BLOCKED (CI-03).** Nhánh chưa push theo yêu cầu, do đó không có run trên GitHub cho commit này; không suy diễn kết quả Actions từ local.

## Audit tất cả 16 workflows

Remote HEAD được xác minh là main sau fetch; không mặc định từ tên thông thường.

| File | Trigger/job/dependency audit | Thay đổi |
|---|---|---|
| test-flutter.yml | Mới; push main/feature/**/fix/**/integration/**; PR target main; dispatch; ubuntu-latest; timeout15; contents:read | Thêm Flutter CI |
| test-backend.yml | Push main + PR; provision DB test riêng trước migrate/test, coverage>=90; cần Docker/Python/uv | Giữ nguyên |
| test-docker-compose.yml | Push main + PR; build/migrate/smoke, cleanup riêng runner CI | Giữ nguyên |
| playwright.yml | Push trước có main và master; PR/dispatch; paths-filter -> shards -> reports -> alls-green; backend/frontend paths | Bỏ master không tồn tại; giữ main/PR |
| zizmor.yml | Push trước chỉ master, nên bỏ lỡ integration main; PR/dispatch; quyền job SARIF/contents/actions | Đổi master -> main (CI-02) |
| deploy.yml | Push trước master + dispatch; Bun frontend, DB prestart, FastAPI Cloud; dùng secrets/vars | Đổi master -> main; chưa deploy/kiểm chứng secrets |
| deploy-docker-compose.yml | Dispatch, self-hosted, concurrency không cancel; deployment secrets qua env | Giữ nguyên |
| pre-commit.yml | PR, checkout full depth, Python/uv/Bun, chạy theo GITHUB_BASE_REF; alls-green | Giữ nguyên |
| smokeshow.yml | workflow_run Test Backend completed; tải coverage của đúng run ID; cần SMOKESHOW_AUTH_KEY | Giữ nguyên |
| detect-conflicts.yml | Push + pull_request_target synchronize; metadata/label, không chạy code PR | Giữ nguyên |
| guard-dependencies.yml | pull_request_target; kiểm tra file dependency/author bằng GitHub API; điều kiện template | Giữ nguyên |
| add-to-project.yml | pull_request_target/issues; job chỉ owner fastapi; PROJECTS_TOKEN | Template job hiện không chạy ở owner này; giữ nguyên |
| bump-pre-commit-hooks.yml | Schedule/dispatch; job chỉ owner fastapi, token/worktree workflow | Giữ nguyên |
| issue-manager.yml | Schedule/comments/issues/PR target/dispatch; job chỉ owner fastapi | Giữ nguyên |
| prepare-release.yml | Dispatch; uv release metadata + PR submit token; không tự chạy khi push fix branch | Giữ nguyên |
| create-draft-release.yml | PR closed, merged + release label; tạo draft release, contents:write tại job | Giữ nguyên |

Không đổi Backend/Frontend CI hoặc giảm coverage/lint/test standards. Không thêm continue-on-error, skip test hay APK build. Không gọi workflow deployment/release.

## Flutter mới

- Working directory cho mọi lệnh: `mobile_app`.
- Flutter **3.47.7**, Dart **3.13.5**, trùng SDK đang cài và revision của .metadata; phù hợp pubspec sdk ^3.13.5 và lock Flutter >=3.47.0.
- checkout và flutter-action pin SHA; flutter-action `1a449444c387b1966244ae4d4f8c696479add0b2` được xác minh từ refs/tags/v2. Không dùng SDK trôi theo latest.
- SDK/pub cache bật theo [action manifest chính thức tại SHA đã pin](https://github.com/subosito/flutter-action/blob/1a449444c387b1966244ae4d4f8c696479add0b2/action.yaml); pub cache key gắn pubspec.lock. Không dùng secret trong job.
- Bước fail ngay khi lệnh lỗi: flutter pub get -> flutter analyze -> flutter test.
- Không có paths filter khiến required job bị treo ở PR tài liệu; concurrency hủy run cũ cùng workflow/ref.

## Test cases

Preconditions: Flutter SDK đã cài; dependencies lock của repo; actionlint1.7.7 tải release chính thức và đối chiếu SHA256; zizmor1.30.1 đã cài. Commit mọi dòng: SHA ở đầu báo cáo.

| ID / mục tiêu | Steps | Expected | Actual / status | Evidence / Bug |
|---|---|---|---|---|
| CI-LOCAL-01 / dependencies | Chạy flutter pub get tại mobile_app | Exit0 | Lần đầu exit1 do symlink Windows; retry sau các lệnh Flutter thành công exit0 / **PASS cuối** | flutter-pub-get-initial.log, flutter-pub-get.log; ENV-01 đã hết trở ngại |
| CI-LOCAL-02 / analyze | flutter analyze | Không issue | Exit0, No issues found; chạy lại sau thêm live harness cũng sạch / **PASS** | flutter-analyze.log, flutter-live-backend.log; — |
| CI-LOCAL-03 / unit-widget | flutter test --reporter expanded | Toàn bộ test pass | **172 passed**, exit0 / **PASS** | flutter-test.log; — |
| CI-YAML / cú pháp | Parse toàn bộ16 YAML bằng BaseLoader, actionlint toàn bộ workflows | Không lỗi YAML/Actions | Exit0 / **PASS** | workflow-validation.log, actionlint.log; — |
| CI-TRIGGER / cấu hình | Assert push main/fix/feature/integration, PR main, dispatch, working dir/lệnh/SDK/cache | Run đúng các nhánh, docs push không match; PR main không paths filter | Đúng / **PASS static** | workflow-validation.log; CI-01/02 đã sửa |
| CI-SECURITY / security lint | zizmor --offline .github/workflows | Không finding mới | Exit0, No findings; 5 ignore/57 suppression có sẵn theo cấu hình / **PASS theo cấu hình repo** | zizmor.log; không thêm suppression |
| CI-REG / frontend | tsc -p frontend/tsconfig.build.json --noEmit | Không type error | Exit0 / **PASS** | static-checks.log; — |
| CI-PRECOMMIT / required gates | prek run --files trên các file tác vụ | Mọi hook pass | **FAIL có sẵn**: mypy14 và ty8; baseline archive cùng venv tái hiện đúng14/8 | pre-commit.log, baseline-mypy.log, baseline-ty.log; LINT-01 |
| CI-REMOTE / Actions commit bàn giao | Tìm run đúng SHA sau khi nhánh được push/PR | Flutter CI, backend, frontend, lint hoàn thành | Commit chỉ local, không push được phép / **BLOCKED** | CI-03 |

**Configuration Error đã xử lý:** CI-01 thiếu Flutter workflow; CI-02 filters master sai nhánh thực. **Product Error:** không phát hiện Flutter analyze/test/dependency incompatibility; backend type-check gates có sẵn FAIL (LINT-01). Symlink lần đầu là môi trường Windows, đã lưu log, không sửa pubspec hoặc tắt plugin để tạo PASS.

## Điều kiện kiểm chứng tiếp

Sau khi người dùng chủ động push/tạo PR vào main: kiểm tra run đúng full SHA bàn giao, không dùng run main cũ; chờ tất cả required checks và xem log ba lệnh Flutter trên Linux. Nếu fail, phân biệt setup/permissions/version với lỗi analyze/test. Chưa thể cấp PASS remote.

Deploy hiện sẽ kích hoạt khi push/merge main theo filter đã sửa. Trước merge cần xác minh secrets DATABASE_URL, SECRET_KEY, FIRST_SUPERUSER_PASSWORD, FASTAPI_CLOUD_TOKEN/APP_ID và vars đúng môi trường; quyền repo/secret chưa được kiểm chứng (OPS-01). Không có thao tác deploy trong phiên này.

Log được chuẩn hóa đường dẫn máy thành <WORKSPACE> và whitespace cuối dòng theo hook repository; kết quả/exit code giữ nguyên.
