# Request/response mẫu – Smart Heritage API (bàn giao P3–P5)

Tài liệu sinh từ **lần chạy thật** của API (giá trị `id`, thời gian là minh họa, sẽ khác khi bạn chạy).
Base URL: `http://localhost:8000/api/v1` · Swagger: `http://localhost:8000/docs`

## 0. Quy ước chung

| Mã | Ý nghĩa |
|---|---|
| 200 / 201 | Thành công (201 = tạo mới) |
| 401 | Thiếu hoặc sai token |
| 403 | Đúng token nhưng không đủ quyền (cần admin) |
| 404 | Không tìm thấy, hoặc đang bị ẩn |
| 409 | Xung đột (trùng mã, Site đang ẩn, hiện vật đang gắn beacon...) |
| 422 | Dữ liệu gửi lên sai định dạng |

- Lỗi luôn dạng `{"detail": "..."}`. Lỗi 422 có `detail` là danh sách lỗi từng trường.
- Header đăng nhập: `Authorization: Bearer <access_token>`.
- Ngôn ngữ: `?lang=vi|en`. Bỏ trống -> ngôn ngữ ưa thích của người dùng -> ngôn ngữ mặc định (`vi`).
- Xóa Site/Artifact/Beacon/Language = **xóa mềm** (`is_active = false`).

**Ai dùng nhóm API nào:** app di động (visitor) dùng mục 1, 3, 5, 6, 7, 8;
web quản trị (admin) dùng mục 2, 3, 4 và các endpoint quản lý.


## 1. Đăng nhập và ngôn ngữ

#### Đăng nhập (lấy token)

- **Ai gọi:** Public (không cần token)
- **Ghi chú:** Body dạng form (`application/x-www-form-urlencoded`), `username` là email.

```bash
curl -X POST "http://localhost:8000/api/v1/login/access-token" \
  -d 'username=khach@example.com&password=khachpass1'
```

Response **200**:
```json
{
  "access_token": "<JWT_TOKEN>",
  "token_type": "bearer"
}
```

#### Danh sách ngôn ngữ

- **Ai gọi:** Public (không cần token)

```bash
curl -X GET "http://localhost:8000/api/v1/languages/"
```

Response **200**:
```json
{
  "data": [
    {
      "code": "en",
      "name": "English",
      "is_active": true,
      "is_default": false,
      "id": "e0c96044-4e4c-4a8e-ae28-d2a51765fbef"
    },
    {
      "code": "vi",
      "name": "Tiếng Việt",
      "is_active": true,
      "is_default": true,
      "id": "d0902d6a-255b-4710-bb56-c9f537ddb3a1"
    }
  ],
  "count": 2
}
```

## 2. Quản trị dữ liệu (admin)

#### Tạo di tích

- **Ai gọi:** Admin (web quản trị)

```bash
curl -X POST "http://localhost:8000/api/v1/sites/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "Hoàng thành Thăng Long", "address": "19C Hoàng Diệu, Ba Đình, Hà Nội", "latitude": 21.0348, "longitude": 105.8403}'
```

Request body:
```json
{
  "name": "Hoàng thành Thăng Long",
  "address": "19C Hoàng Diệu, Ba Đình, Hà Nội",
  "latitude": 21.0348,
  "longitude": 105.8403
}
```

Response **200**:
```json
{
  "name": "Hoàng thành Thăng Long",
  "description": null,
  "address": "19C Hoàng Diệu, Ba Đình, Hà Nội",
  "latitude": 21.0348,
  "longitude": 105.8403,
  "cover_image_url": null,
  "is_active": true,
  "id": "851093ad-de77-4807-a647-5e038a0ac6e9",
  "created_at": "2026-10-29T01:05:49.725812Z",
  "updated_at": null
}
```

#### Tạo hiện vật

- **Ai gọi:** Admin (web quản trị)
- **Ghi chú:** `code` không được trùng trong cùng Site (409).

```bash
curl -X POST "http://localhost:8000/api/v1/artifacts/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"site_id": "851093ad-de77-4807-a647-5e038a0ac6e9", "code": "HT-001", "era": "Thế kỷ 11"}'
```

Request body:
```json
{
  "site_id": "851093ad-de77-4807-a647-5e038a0ac6e9",
  "code": "HT-001",
  "era": "Thế kỷ 11"
}
```

Response **200**:
```json
{
  "code": "HT-001",
  "era": "Thế kỷ 11",
  "latitude": null,
  "longitude": null,
  "cover_image_url": null,
  "is_active": true,
  "id": "2402d8a4-6a2d-4652-9bfe-257d37a9d14f",
  "site_id": "851093ad-de77-4807-a647-5e038a0ac6e9",
  "created_at": "2026-10-29T01:05:49.743150Z",
  "updated_at": null
}
```

#### Thêm/sửa nội dung tiếng Việt (upsert)

- **Ai gọi:** Admin (web quản trị)

```bash
curl -X PUT "http://localhost:8000/api/v1/artifacts/2402d8a4-6a2d-4652-9bfe-257d37a9d14f/translations/d0902d6a-255b-4710-bb56-c9f537ddb3a1" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title": "Trống đồng Đông Sơn", "description": "Hiện vật tiêu biểu của văn hóa Đông Sơn.", "history_content": "Trống đồng ra đời cách đây hơn 2.000 năm."}'
```

Request body:
```json
{
  "title": "Trống đồng Đông Sơn",
  "description": "Hiện vật tiêu biểu của văn hóa Đông Sơn.",
  "history_content": "Trống đồng ra đời cách đây hơn 2.000 năm."
}
```

Response **200**:
```json
{
  "title": "Trống đồng Đông Sơn",
  "description": "Hiện vật tiêu biểu của văn hóa Đông Sơn.",
  "history_content": "Trống đồng ra đời cách đây hơn 2.000 năm.",
  "id": "6a355bf8-4d70-456b-b504-9f8637c6f42e",
  "artifact_id": "2402d8a4-6a2d-4652-9bfe-257d37a9d14f",
  "language_id": "d0902d6a-255b-4710-bb56-c9f537ddb3a1"
}
```

#### Đăng ký beacon và gán hiện vật

- **Ai gọi:** Admin (web quản trị)
- **Ghi chú:** `proximity_uuid` được lưu chữ HOA. Beacon và hiện vật phải cùng Site.

```bash
curl -X POST "http://localhost:8000/api/v1/beacons/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"proximity_uuid": "e2c56db5-dffb-48d2-b060-d0f5a71096e0", "major": 1, "minor": 1, "site_id": "851093ad-de77-4807-a647-5e038a0ac6e9", "artifact_id": "2402d8a4-6a2d-4652-9bfe-257d37a9d14f"}'
```

Request body:
```json
{
  "proximity_uuid": "e2c56db5-dffb-48d2-b060-d0f5a71096e0",
  "major": 1,
  "minor": 1,
  "site_id": "851093ad-de77-4807-a647-5e038a0ac6e9",
  "artifact_id": "2402d8a4-6a2d-4652-9bfe-257d37a9d14f"
}
```

Response **201**:
```json
{
  "proximity_uuid": "E2C56DB5-DFFB-48D2-B060-D0F5A71096E0",
  "major": 1,
  "minor": 1,
  "tx_power": -59,
  "rssi_threshold": -80,
  "is_active": true,
  "id": "e482fc34-b80d-4ecd-93c6-62511408df47",
  "site_id": "851093ad-de77-4807-a647-5e038a0ac6e9",
  "artifact_id": "2402d8a4-6a2d-4652-9bfe-257d37a9d14f",
  "battery_level": null,
  "last_seen_at": null,
  "created_at": "2026-10-29T01:05:49.775321Z",
  "updated_at": null
}
```

## 3. Đọc nội dung hiện vật (public)

#### Chi tiết hiện vật (tiếng Việt)

- **Ai gọi:** Public (không cần token)

```bash
curl -X GET "http://localhost:8000/api/v1/artifacts/2402d8a4-6a2d-4652-9bfe-257d37a9d14f?lang=vi"
```

Response **200**:
```json
{
  "code": "HT-001",
  "era": "Thế kỷ 11",
  "latitude": null,
  "longitude": null,
  "cover_image_url": null,
  "is_active": true,
  "id": "2402d8a4-6a2d-4652-9bfe-257d37a9d14f",
  "site_id": "851093ad-de77-4807-a647-5e038a0ac6e9",
  "created_at": "2026-10-29T01:05:49.743150Z",
  "updated_at": null,
  "title": "Trống đồng Đông Sơn",
  "description": "Hiện vật tiêu biểu của văn hóa Đông Sơn.",
  "history_content": "Trống đồng ra đời cách đây hơn 2.000 năm.",
  "language_code": "vi",
  "is_fallback": false,
  "media": []
}
```

#### Chi tiết hiện vật khi chưa có bản dịch tiếng Anh (dự phòng)

- **Ai gọi:** Public (không cần token)
- **Ghi chú:** `is_fallback = true`: nội dung là tiếng Việt vì chưa có bản dịch `en`.

```bash
curl -X GET "http://localhost:8000/api/v1/artifacts/2402d8a4-6a2d-4652-9bfe-257d37a9d14f?lang=en"
```

Response **200**:
```json
{
  "code": "HT-001",
  "era": "Thế kỷ 11",
  "latitude": null,
  "longitude": null,
  "cover_image_url": null,
  "is_active": true,
  "id": "2402d8a4-6a2d-4652-9bfe-257d37a9d14f",
  "site_id": "851093ad-de77-4807-a647-5e038a0ac6e9",
  "created_at": "2026-10-29T01:05:49.743150Z",
  "updated_at": null,
  "title": "Trống đồng Đông Sơn",
  "description": "Hiện vật tiêu biểu của văn hóa Đông Sơn.",
  "history_content": "Trống đồng ra đời cách đây hơn 2.000 năm.",
  "language_code": "vi",
  "is_fallback": true,
  "media": []
}
```

#### Danh sách hiện vật của một di tích

- **Ai gọi:** Public (không cần token)

```bash
curl -X GET "http://localhost:8000/api/v1/artifacts/?site_id=851093ad-de77-4807-a647-5e038a0ac6e9&lang=vi"
```

Response **200**:
```json
{
  "data": [
    {
      "id": "2402d8a4-6a2d-4652-9bfe-257d37a9d14f",
      "site_id": "851093ad-de77-4807-a647-5e038a0ac6e9",
      "code": "HT-001",
      "era": "Thế kỷ 11",
      "latitude": null,
      "longitude": null,
      "cover_image_url": null,
      "is_active": true,
      "title": "Trống đồng Đông Sơn",
      "language_code": "vi",
      "is_fallback": false
    }
  ],
  "count": 1
}
```

## 4. Quét beacon (app du khách)

#### Quét beacon -> nhận nội dung hiện vật

- **Ai gọi:** Visitor (app du khách)
- **Ghi chú:** Gọi khi app nhận được tín hiệu beacon mới. Trả hiện vật + nội dung đúng ngôn ngữ + media.

```bash
curl -X GET "http://localhost:8000/api/v1/beacons/resolve?proximity_uuid=E2C56DB5-DFFB-48D2-B060-D0F5A71096E0&major=1&minor=1&lang=vi" \
  -H "Authorization: Bearer $TOKEN"
```

Response **200**:
```json
{
  "beacon": {
    "proximity_uuid": "E2C56DB5-DFFB-48D2-B060-D0F5A71096E0",
    "major": 1,
    "minor": 1,
    "tx_power": -59,
    "rssi_threshold": -80,
    "is_active": true,
    "id": "e482fc34-b80d-4ecd-93c6-62511408df47",
    "site_id": "851093ad-de77-4807-a647-5e038a0ac6e9",
    "artifact_id": "2402d8a4-6a2d-4652-9bfe-257d37a9d14f",
    "battery_level": null,
    "last_seen_at": "2026-10-29T01:05:49.807629Z",
    "created_at": "2026-10-29T01:05:49.775321Z",
    "updated_at": null
  },
  "artifact": {
    "code": "HT-001",
    "era": "Thế kỷ 11",
    "latitude": null,
    "longitude": null,
    "cover_image_url": null,
    "is_active": true,
    "id": "2402d8a4-6a2d-4652-9bfe-257d37a9d14f",
    "site_id": "851093ad-de77-4807-a647-5e038a0ac6e9",
    "created_at": "2026-10-29T01:05:49.743150Z",
    "updated_at": null,
    "title": "Trống đồng Đông Sơn",
    "description": "Hiện vật tiêu biểu của văn hóa Đông Sơn.",
    "history_content": "Trống đồng ra đời cách đây hơn 2.000 năm.",
    "language_code": "vi",
    "is_fallback": false,
    "media": []
  }
}
```

## 5. Yêu thích (visitor)

#### Thêm yêu thích (lần đầu)

- **Ai gọi:** Visitor (app du khách)
- **Ghi chú:** Tạo mới -> **201**.

```bash
curl -X POST "http://localhost:8000/api/v1/favorites/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"artifact_id": "2402d8a4-6a2d-4652-9bfe-257d37a9d14f"}'
```

Request body:
```json
{
  "artifact_id": "2402d8a4-6a2d-4652-9bfe-257d37a9d14f"
}
```

Response **201**:
```json
{
  "id": "c6c9e41f-30e3-4a21-bf28-4c3f16c4f213",
  "user_id": "becacc64-189c-4160-ba92-c89ad582b82d",
  "artifact_id": "2402d8a4-6a2d-4652-9bfe-257d37a9d14f",
  "created_at": "2026-10-29T01:05:49.825932Z"
}
```

#### Thêm yêu thích (đã có)

- **Ai gọi:** Visitor (app du khách)
- **Ghi chú:** Đã yêu thích rồi -> **200**, trả bản ghi cũ, không tạo trùng.

```bash
curl -X POST "http://localhost:8000/api/v1/favorites/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"artifact_id": "2402d8a4-6a2d-4652-9bfe-257d37a9d14f"}'
```

Request body:
```json
{
  "artifact_id": "2402d8a4-6a2d-4652-9bfe-257d37a9d14f"
}
```

Response **200**:
```json
{
  "id": "c6c9e41f-30e3-4a21-bf28-4c3f16c4f213",
  "user_id": "becacc64-189c-4160-ba92-c89ad582b82d",
  "artifact_id": "2402d8a4-6a2d-4652-9bfe-257d37a9d14f",
  "created_at": "2026-10-29T01:05:49.825932Z"
}
```

#### Danh sách yêu thích của tôi

- **Ai gọi:** Visitor (app du khách)

```bash
curl -X GET "http://localhost:8000/api/v1/favorites/me?lang=vi&skip=0&limit=20" \
  -H "Authorization: Bearer $TOKEN"
```

Response **200**:
```json
{
  "data": [
    {
      "id": "c6c9e41f-30e3-4a21-bf28-4c3f16c4f213",
      "user_id": "becacc64-189c-4160-ba92-c89ad582b82d",
      "artifact_id": "2402d8a4-6a2d-4652-9bfe-257d37a9d14f",
      "created_at": "2026-10-29T01:05:49.825932Z",
      "artifact": {
        "id": "2402d8a4-6a2d-4652-9bfe-257d37a9d14f",
        "site_id": "851093ad-de77-4807-a647-5e038a0ac6e9",
        "code": "HT-001",
        "era": "Thế kỷ 11",
        "latitude": null,
        "longitude": null,
        "cover_image_url": null,
        "is_active": true,
        "title": "Trống đồng Đông Sơn",
        "language_code": "vi",
        "is_fallback": false
      }
    }
  ],
  "count": 1
}
```

#### Bỏ yêu thích

- **Ai gọi:** Visitor (app du khách)

```bash
curl -X DELETE "http://localhost:8000/api/v1/favorites/2402d8a4-6a2d-4652-9bfe-257d37a9d14f" \
  -H "Authorization: Bearer $TOKEN"
```

Response **200**:
```json
{
  "message": "Favorite removed successfully"
}
```

## 6. Ghi lượt xem và lịch sử (visitor)

#### Ghi lượt xem (mới)

- **Ai gọi:** Visitor (app du khách)
- **Ghi chú:** Chỉ gọi khi app **hiện nội dung** hiện vật (không gọi mỗi lần nhận tín hiệu BLE). Lượt mới -> **201**.

```bash
curl -X POST "http://localhost:8000/api/v1/visits/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"artifact_id": "2402d8a4-6a2d-4652-9bfe-257d37a9d14f", "beacon_id": "e482fc34-b80d-4ecd-93c6-62511408df47", "rssi": -62}'
```

Request body:
```json
{
  "artifact_id": "2402d8a4-6a2d-4652-9bfe-257d37a9d14f",
  "beacon_id": "e482fc34-b80d-4ecd-93c6-62511408df47",
  "rssi": -62
}
```

Response **201**:
```json
{
  "id": "22e81ce4-a855-4c17-bf5f-da3263674330",
  "user_id": "becacc64-189c-4160-ba92-c89ad582b82d",
  "artifact_id": "2402d8a4-6a2d-4652-9bfe-257d37a9d14f",
  "beacon_id": "e482fc34-b80d-4ecd-93c6-62511408df47",
  "language_id": "d0902d6a-255b-4710-bb56-c9f537ddb3a1",
  "visited_at": "2026-10-29T01:05:49.865833Z",
  "duration_seconds": null,
  "rssi": -62
}
```

#### Ghi lượt xem (trùng trong 300 giây)

- **Ai gọi:** Visitor (app du khách)
- **Ghi chú:** Cùng người + cùng hiện vật trong 300 giây -> **200**, trả lượt cũ, không tạo mới.

```bash
curl -X POST "http://localhost:8000/api/v1/visits/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"artifact_id": "2402d8a4-6a2d-4652-9bfe-257d37a9d14f", "beacon_id": "e482fc34-b80d-4ecd-93c6-62511408df47", "rssi": -60}'
```

Request body:
```json
{
  "artifact_id": "2402d8a4-6a2d-4652-9bfe-257d37a9d14f",
  "beacon_id": "e482fc34-b80d-4ecd-93c6-62511408df47",
  "rssi": -60
}
```

Response **200**:
```json
{
  "id": "22e81ce4-a855-4c17-bf5f-da3263674330",
  "user_id": "becacc64-189c-4160-ba92-c89ad582b82d",
  "artifact_id": "2402d8a4-6a2d-4652-9bfe-257d37a9d14f",
  "beacon_id": "e482fc34-b80d-4ecd-93c6-62511408df47",
  "language_id": "d0902d6a-255b-4710-bb56-c9f537ddb3a1",
  "visited_at": "2026-10-29T01:05:49.865833Z",
  "duration_seconds": null,
  "rssi": -62
}
```

#### Lịch sử tham quan của tôi

- **Ai gọi:** Visitor (app du khách)
- **Ghi chú:** Mới nhất trước, có phân trang (`skip`, `limit` tối đa 100).

```bash
curl -X GET "http://localhost:8000/api/v1/visits/me?lang=vi&skip=0&limit=20" \
  -H "Authorization: Bearer $TOKEN"
```

Response **200**:
```json
{
  "data": [
    {
      "id": "22e81ce4-a855-4c17-bf5f-da3263674330",
      "user_id": "becacc64-189c-4160-ba92-c89ad582b82d",
      "artifact_id": "2402d8a4-6a2d-4652-9bfe-257d37a9d14f",
      "beacon_id": "e482fc34-b80d-4ecd-93c6-62511408df47",
      "language_id": "d0902d6a-255b-4710-bb56-c9f537ddb3a1",
      "visited_at": "2026-10-29T01:05:49.865833Z",
      "duration_seconds": null,
      "rssi": -62,
      "artifact": {
        "id": "2402d8a4-6a2d-4652-9bfe-257d37a9d14f",
        "site_id": "851093ad-de77-4807-a647-5e038a0ac6e9",
        "code": "HT-001",
        "era": "Thế kỷ 11",
        "latitude": null,
        "longitude": null,
        "cover_image_url": null,
        "is_active": true,
        "title": "Trống đồng Đông Sơn",
        "language_code": "vi",
        "is_fallback": false
      }
    }
  ],
  "count": 1
}
```

## 7. Ví dụ lỗi thường gặp

#### Thiếu token -> 401

- **Ai gọi:** Public (không cần token)

```bash
curl -X GET "http://localhost:8000/api/v1/favorites/me"
```

Response **401**:
```json
{
  "detail": "Not authenticated"
}
```

#### Sai quyền (visitor gọi API admin) -> 403

- **Ai gọi:** Visitor (app du khách)

```bash
curl -X POST "http://localhost:8000/api/v1/sites/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "Không được tạo"}'
```

Request body:
```json
{
  "name": "Không được tạo"
}
```

Response **403**:
```json
{
  "detail": "The user doesn't have enough privileges"
}
```

#### Không tìm thấy -> 404

- **Ai gọi:** Visitor (app du khách)

```bash
curl -X POST "http://localhost:8000/api/v1/favorites/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"artifact_id": "9af98568-a54d-4d8d-8276-2f874792ecb2"}'
```

Request body:
```json
{
  "artifact_id": "9af98568-a54d-4d8d-8276-2f874792ecb2"
}
```

Response **404**:
```json
{
  "detail": "Artifact not found"
}
```

#### Trùng mã hiện vật -> 409

- **Ai gọi:** Admin (web quản trị)

```bash
curl -X POST "http://localhost:8000/api/v1/artifacts/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"site_id": "851093ad-de77-4807-a647-5e038a0ac6e9", "code": "HT-001"}'
```

Request body:
```json
{
  "site_id": "851093ad-de77-4807-a647-5e038a0ac6e9",
  "code": "HT-001"
}
```

Response **409**:
```json
{
  "detail": "Artifact code already exists in this site"
}
```

#### Đổi Site của hiện vật đang gắn beacon -> 409

- **Ai gọi:** Admin (web quản trị)
- **Ghi chú:** Phải gỡ beacon trước (`PUT /beacons/{id}` với `artifact_id: null`).

```bash
curl -X PUT "http://localhost:8000/api/v1/artifacts/2402d8a4-6a2d-4652-9bfe-257d37a9d14f" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"site_id": "42386285-d583-43ff-82e5-dd93b9c72537"}'
```

Request body:
```json
{
  "site_id": "42386285-d583-43ff-82e5-dd93b9c72537"
}
```

Response **409**:
```json
{
  "detail": "Hiện vật đang gắn Beacon, hãy gỡ Beacon trước khi đổi Site"
}
```

#### Dữ liệu sai định dạng -> 422

- **Ai gọi:** Visitor (app du khách)

```bash
curl -X POST "http://localhost:8000/api/v1/favorites/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"artifact_id": "khong-phai-uuid"}'
```

Request body:
```json
{
  "artifact_id": "khong-phai-uuid"
}
```

Response **422**:
```json
{
  "detail": [
    {
      "type": "uuid_parsing",
      "loc": [
        "body",
        "artifact_id"
      ],
      "msg": "Input should be a valid UUID, invalid character: found `k` at 1",
      "input": "khong-phai-uuid",
      "ctx": {
        "error": "invalid character: found `k` at 1"
      }
    }
  ]
}
```
