# Kiểm chứng Docker, migration và CI — 28/10/2026

## Phạm vi và nguồn bằng chứng

Kiểm tra trên working tree từ commit `42cd3e9`, bao gồm API Media đang được
phát triển. Không push, deploy hoặc thay đổi database đang chạy của project
`doan`. SQL Server kiểm chứng dùng project/network/volume riêng
`media-ci-audit`, image `mcr.microsoft.com/mssql/server:2022-latest`.

Đã đọc trạng thái job, bước lỗi và annotations qua GitHub REST API:

| Workflow | Run | Kết quả trước sửa |
| --- | --- | --- |
| Test Docker Compose | [40241301392](https://github.com/Hoangisme-ut/Hequantri_CSDL/actions/runs/40241301392) | Thành công |
| Test Backend | [40241301285](https://github.com/Hoangisme-ut/Hequantri_CSDL/actions/runs/40241301285) | Bước Coverage report, exit 2 |
| Playwright Tests | [40241301296](https://github.com/Hoangisme-ut/Hequantri_CSDL/actions/runs/40241301296) | Test thất bại; shard 4 vượt timeout 20 phút |
| pre-commit | [40238390503](https://github.com/Hoangisme-ut/Hequantri_CSDL/actions/runs/40238390503) | Bước Run prek, exit 1 |

Endpoint tải raw log GitHub trả HTTP 403 khi không có token. Vì vậy các nguyên
nhân chi tiết bên dưới được xác nhận bằng log chạy lại tại máy, không suy diễn
từ thông báo exit code của GitHub.

## Lỗi đã tái hiện và xử lý

1. **Coverage thấp:** test backend đạt nhưng tổng coverage chỉ 87%, thấp hơn
   gate 90%. Bổ sung kiểm thử HTTP vòng đời Artifact/bản dịch, lọc nội dung,
   ngôn ngữ mặc định, xung đột mã và soft delete. Sau bổ sung: 99 test đạt,
   coverage 95% (1494 statements, 77 missed). Giữ nguyên gate 90%.
2. **Test email phụ thuộc môi trường:** `test_emails_enabled` thất bại trong
   Docker vì `_env_file=None` không loại bỏ biến SMTP của process. Test giờ
   truyền rõ `SMTP_HOST=None` và `EMAILS_FROM_EMAIL=None` cho trường hợp tắt email.
3. **Type-check:** mypy/ty báo `NO ACTION` không thuộc kiểu `ondelete` của
   SQLModel; bỏ tham số để sử dụng hành vi mặc định không cascade. Không đổi
   migration hay dữ liệu. Khai báo kiểu cho dictionary cập nhật User và danh
   sách điều kiện SQL để sửa lỗi suy luận kiểu trong CRUD/Site/Artifact.
4. **Ruff và ORM:** giữ `Optional["Role"]`, `Optional["Language"]`,
   `Optional["Beacon"]` bằng noqa có chú thích. Chuyển tự động thành union
   forward reference trên runtime Python 3.14 gây lỗi mapper
   `expression 'Role | None' failed to locate a name`. Smoke login phát hiện
   lỗi này dù health-check vẫn trả 200. Bản cuối giữ kiểu tương thích và đăng
   nhập/API đã hoạt động trở lại.
5. **Playwright lệch giao diện:** cập nhật tiêu đề Users/Items, thông báo empty
   state, chuyển test hồ sơ từ `/settings` sang `/account`, thay thao tác tab
   cũ bằng các section và nút Light/Dark hiện tại. Dùng locator chính xác cho
   Email và Save để tránh trùng Email notifications/Save preferences; giới
   hạn assertion tên người dùng trong đúng row để chạy lại không bị trùng tên.
6. **Lỗi form hồ sơ:** `defaultValues` được lấy khi API chưa tải xong; Cancel
   có thể khôi phục dữ liệu rỗng. Đồng bộ form với user tải về khi không chỉnh
   sửa, giữ nguyên nội dung đang gõ trong edit mode. Test Cancel dùng tên khác
   tên gốc để kiểm chứng thực sự việc khôi phục.
7. **Khả năng chẩn đoán CI:** ba workflow Backend/Compose/Playwright lưu log
   Compose và luôn cleanup kể cả khi test lỗi. Compose chạy prestart hai lần,
   sau đó smoke đăng nhập Admin và ghi/đọc Media qua resolve beacon. SDK được
   sinh lại từ OpenAPI hiện tại để hook generate-client không tạo diff còn thiếu.

## Chuỗi DB mới → migration → seed → đăng nhập → API

- Volume SQL Server mới được tạo, `db-init` kết thúc exit 0.
- `prestart.sh` chạy đủ chuỗi revision:
  `475b2d4c150f → 2af237ad3b09 → c3a91f5e7d20 → 7d6e9a4b2c1f → a1b2c3d4e5f6`.
- `alembic current` và `alembic heads` cùng trả `a1b2c3d4e5f6 (head)`.
- Seed tạo role/ngôn ngữ/Admin. Gọi seed thêm hai lần không tăng số bản ghi
  Role/Language/User.
- HTTP thực: health 200 → token Admin 200 → users/me 200 → tạo Site 200 →
  Artifact 200 → Media 201 → Beacon 201 → resolve 200, trả đúng Media ID vừa lưu.
- Đã build frontend và Docker backend thành công. Build đầu tải base image
  qua mạng chậm (riêng Python layer mất khoảng 13 phút); build lại dùng cache.

`scripts/smoke_api.py` chạy trên database thử nghiệm và có tạo bản ghi mẫu.
Không dùng script này như health-check định kỳ trên production.

## Lệnh tái hiện

Kết quả kiểm tra bổ sung:

| Kiểm tra | Kết quả |
| --- | --- |
| Backend trên image cuối, Python 3.14.10 + SQL Server 2022 | 99/99 đạt trong 16,69 giây; coverage 95%; gate 90% exit 0 |
| Playwright Chromium, 1 worker, retries=0 | 63/63 đạt trong 1,4 phút; gồm đăng ký, đăng nhập, reset password qua Mailpit, CRUD và account |
| mypy | Đạt, 32 source files |
| ty | Đạt |
| Ruff check/format trên Python thay đổi | Đạt |
| Biome trên frontend thay đổi | Đạt |
| YAML workflow | Parse thành công |
| Zizmor trên 3 workflow thay đổi | Không có finding mới (offline; 12 suppression hiện hữu) |
| Docker image cuối | Build đạt; manifest `b7d1294c49c737e774a6e50dff7ecc4e9b6977f545279364bc18bc947b67c1e7` |

Playwright chạy bằng browser image có sẵn, mount bộ test hiện tại, truy cập
API/SQL Server riêng và frontend vừa build. Chưa tái chạy mô hình 4 shard trên
GitHub runner. Smoke HTTP cũng được chạy lại trên image cuối không mount mã
ứng dụng từ host.

Chạy từ repository root với project name mới để không dùng dữ liệu hiện hữu:

```sh
docker compose -p ci-audit -f compose.yml --env-file .env.example build backend
docker compose -p ci-audit -f compose.yml --env-file .env.example up -d --wait db
docker compose -p ci-audit -f compose.yml --env-file .env.example run --rm db-init
docker compose -p ci-audit -f compose.yml --env-file .env.example run --rm -e FASTAPI_ENV=development backend bash scripts/prestart.sh
docker compose -p ci-audit -f compose.yml --env-file .env.example run --rm -e FASTAPI_ENV=development backend bash scripts/prestart.sh
docker compose -p ci-audit -f compose.yml --env-file .env.example run --rm -d --name ci-audit-api -e FASTAPI_ENV=development backend
docker exec ci-audit-api curl --fail --retry 10 --retry-delay 3 --retry-connrefused http://localhost:8000/api/v1/utils/health-check/
docker exec ci-audit-api python scripts/smoke_api.py
docker stop ci-audit-api
docker compose -p ci-audit -f compose.yml --env-file .env.example down -v --remove-orphans
```

Chỉ `compose.yml` không tự nạp `compose.override.yml`, vì vậy các lệnh trên
truyền rõ `FASTAPI_ENV=development`. Dùng `.env.example` ở chế độ production
bị chặn với `SECRET_KEY is "changethis"`; đây là kiểm tra cấu hình có chủ đích.

## Giới hạn và việc còn lại

- Các workflow sửa chưa chạy lại trên GitHub vì thay đổi chưa được push.
  Không đồng nhất kết quả cục bộ với trạng thái CI remote.
- Chưa kiểm chứng deploy thật, TLS/Traefik hoặc FastAPI Cloud; không tác động
  hạ tầng production trong đợt kiểm tra này.
- Dockerfile còn dùng base tag thay đổi theo thời gian và `bun install` có
  thể ghi lại lockfile trong image. Build hiện tại đạt, nhưng chưa bảo đảm
  tái lập byte-for-byte giữa các lần build.
- Còn warning từ khóa mẫu `.env.example`, độ dài JWT key mẫu và deprecation
  `httpx` của Starlette TestClient. Không làm thất bại kiểm thử.

Sau kiểm chứng đã dọn container, network và volume `media-ci-audit` tạo trong
phiên này. Container của project `doan` vẫn chạy. Không có lỗi test còn lại
trong các bộ đã chạy cục bộ; các giới hạn kiểm chứng ở trên vẫn áp dụng.
