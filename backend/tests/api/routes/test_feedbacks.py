"""Kiểm thử HTTP cho API Feedback (/feedbacks): trạng thái theo ERD, phân quyền,
quyền sở hữu dữ liệu, validation và việc nội dung chưa duyệt không hiện công khai."""

import uuid
from collections.abc import Generator
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session

from app.models import Feedback
from tests.utils.heritage import API, create_artifact, create_site, purge_sites
from tests.utils.user import authentication_token_from_email

Headers = dict[str, str]


@pytest.fixture
def site_ids(db: Session) -> Generator[list[str]]:
    ids: list[str] = []
    yield ids
    purge_sites(db, ids)


@pytest.fixture
def other_user_headers(client: TestClient, db: Session) -> Headers:
    return authentication_token_from_email(
        client=client, email="feedback-other@example.com", db=db
    )


def _artifact(
    client: TestClient, admin: Headers, site_ids: list[str]
) -> dict[str, Any]:
    site = create_site(client, admin)
    site_ids.append(site["id"])
    artifact = create_artifact(client, admin, site["id"])
    artifact["site_id"] = site["id"]
    return artifact


def _send(client: TestClient, headers: Headers, artifact_id: str, **extra: Any) -> Any:
    payload = {"artifact_id": artifact_id, "rating": 5, **extra}
    return client.post(f"{API}/feedbacks/", headers=headers, json=payload)


def _moderate(
    client: TestClient, admin: Headers, feedback_id: str, new_status: str
) -> Any:
    return client.patch(
        f"{API}/feedbacks/{feedback_id}/status",
        headers=admin,
        json={"status": new_status},
    )


def _public(client: TestClient, artifact_id: str) -> list[dict[str, Any]]:
    response = client.get(f"{API}/feedbacks/artifact/{artifact_id}")
    assert response.status_code == 200, response.text
    return response.json()["data"]  # type: ignore[no-any-return]


# --------------------------- Trạng thái khi gửi (theo ERD) ----------------------
def test_create_feedback_status_follows_comment_rule(
    client: TestClient,
    superuser_token_headers: Headers,
    normal_user_token_headers: Headers,
    site_ids: list[str],
) -> None:
    with_comment = _artifact(client, superuser_token_headers, site_ids)
    created = _send(
        client, normal_user_token_headers, with_comment["id"], comment="Rất đẹp"
    )
    assert created.status_code == 201
    body = created.json()
    assert body["status"] == "pending"
    assert body["comment"] == "Rất đẹp"
    assert body["rating"] == 5

    no_comment = _artifact(client, superuser_token_headers, site_ids)
    only_rating = _send(client, normal_user_token_headers, no_comment["id"], rating=4)
    assert only_rating.status_code == 201
    assert only_rating.json()["status"] == "approved"
    assert only_rating.json()["comment"] is None

    blank = _artifact(client, superuser_token_headers, site_ids)
    blank_comment = _send(client, normal_user_token_headers, blank["id"], comment="   ")
    assert blank_comment.status_code == 201
    assert blank_comment.json()["status"] == "approved"
    assert blank_comment.json()["comment"] is None


def test_client_cannot_choose_status(
    client: TestClient,
    superuser_token_headers: Headers,
    normal_user_token_headers: Headers,
    site_ids: list[str],
) -> None:
    artifact = _artifact(client, superuser_token_headers, site_ids)
    created = _send(
        client,
        normal_user_token_headers,
        artifact["id"],
        comment="Tự duyệt",
        status="approved",
    )
    assert created.status_code == 201
    assert created.json()["status"] == "pending"
    assert _public(client, artifact["id"]) == []


def test_one_feedback_per_user_per_artifact(
    client: TestClient,
    superuser_token_headers: Headers,
    normal_user_token_headers: Headers,
    other_user_headers: Headers,
    site_ids: list[str],
) -> None:
    artifact = _artifact(client, superuser_token_headers, site_ids)
    assert _send(client, normal_user_token_headers, artifact["id"]).status_code == 201
    again = _send(client, normal_user_token_headers, artifact["id"], rating=1)
    assert again.status_code == 409

    # người khác vẫn đánh giá được cùng hiện vật
    assert _send(client, other_user_headers, artifact["id"]).status_code == 201
    listed = client.get(
        f"{API}/feedbacks/",
        headers=superuser_token_headers,
        params={"artifact_id": artifact["id"]},
    ).json()
    assert listed["count"] == 2


# --------------------------------- Validation -----------------------------------
@pytest.mark.parametrize(
    "bad",
    [
        {"rating": 0},
        {"rating": 6},
        {"rating": -1},
        {"rating": "năm sao"},
        {"rating": None},
        {"comment": "x" * 2001},
        {"artifact_id": "not-a-uuid"},
    ],
)
def test_create_feedback_validation(
    client: TestClient,
    superuser_token_headers: Headers,
    normal_user_token_headers: Headers,
    site_ids: list[str],
    bad: dict[str, Any],
) -> None:
    artifact = _artifact(client, superuser_token_headers, site_ids)
    payload = {"artifact_id": artifact["id"], "rating": 3, **bad}
    response = client.post(
        f"{API}/feedbacks/", headers=normal_user_token_headers, json=payload
    )
    assert response.status_code == 422


def test_create_feedback_requires_rating(
    client: TestClient,
    superuser_token_headers: Headers,
    normal_user_token_headers: Headers,
    site_ids: list[str],
) -> None:
    artifact = _artifact(client, superuser_token_headers, site_ids)
    response = client.post(
        f"{API}/feedbacks/",
        headers=normal_user_token_headers,
        json={"artifact_id": artifact["id"]},
    )
    assert response.status_code == 422


def test_cannot_send_feedback_for_unknown_or_hidden_target(
    client: TestClient,
    superuser_token_headers: Headers,
    normal_user_token_headers: Headers,
    site_ids: list[str],
) -> None:
    unknown = _send(client, normal_user_token_headers, str(uuid.uuid4()))
    assert unknown.status_code == 404

    hidden_artifact = _artifact(client, superuser_token_headers, site_ids)
    client.delete(
        f"{API}/artifacts/{hidden_artifact['id']}", headers=superuser_token_headers
    )
    assert (
        _send(client, normal_user_token_headers, hidden_artifact["id"]).status_code
        == 404
    )

    under_hidden_site = _artifact(client, superuser_token_headers, site_ids)
    client.delete(
        f"{API}/sites/{under_hidden_site['site_id']}", headers=superuser_token_headers
    )
    assert (
        _send(client, normal_user_token_headers, under_hidden_site["id"]).status_code
        == 404
    )


# ------------------------------------ Phân quyền --------------------------------
def test_feedback_endpoints_require_token(client: TestClient) -> None:
    some_id = str(uuid.uuid4())
    assert (
        client.post(
            f"{API}/feedbacks/", json={"artifact_id": some_id, "rating": 5}
        ).status_code
        == 401
    )
    assert client.get(f"{API}/feedbacks/me").status_code == 401
    assert (
        client.put(f"{API}/feedbacks/{some_id}", json={"rating": 4}).status_code == 401
    )
    assert client.get(f"{API}/feedbacks/").status_code == 401
    assert (
        client.patch(
            f"{API}/feedbacks/{some_id}/status", json={"status": "approved"}
        ).status_code
        == 401
    )


def test_visitor_cannot_use_admin_endpoints(
    client: TestClient,
    superuser_token_headers: Headers,
    normal_user_token_headers: Headers,
    site_ids: list[str],
) -> None:
    artifact = _artifact(client, superuser_token_headers, site_ids)
    feedback = _send(
        client, normal_user_token_headers, artifact["id"], comment="Chờ duyệt"
    ).json()

    assert (
        client.get(f"{API}/feedbacks/", headers=normal_user_token_headers).status_code
        == 403
    )
    # visitor không tự duyệt được bình luận của chính mình
    response = _moderate(client, normal_user_token_headers, feedback["id"], "approved")
    assert response.status_code == 403
    assert _public(client, artifact["id"]) == []


# ---------------------------------- Đọc theo quyền ------------------------------
def test_my_feedbacks_only_returns_own_data(
    client: TestClient,
    superuser_token_headers: Headers,
    normal_user_token_headers: Headers,
    other_user_headers: Headers,
    site_ids: list[str],
) -> None:
    artifact = _artifact(client, superuser_token_headers, site_ids)
    mine = _send(
        client, normal_user_token_headers, artifact["id"], comment="Của tôi"
    ).json()
    theirs = _send(
        client, other_user_headers, artifact["id"], rating=2, comment="Của người khác"
    ).json()

    my_list = client.get(
        f"{API}/feedbacks/me", headers=normal_user_token_headers
    ).json()
    my_ids = {item["id"] for item in my_list["data"]}
    assert mine["id"] in my_ids
    assert theirs["id"] not in my_ids
    me = client.get(f"{API}/users/me", headers=normal_user_token_headers).json()
    assert all(item["user_id"] == me["id"] for item in my_list["data"])
    # chủ sở hữu thấy được trạng thái của mình
    assert {item["status"] for item in my_list["data"]} <= {
        "pending",
        "approved",
        "hidden",
    }

    other_list = client.get(f"{API}/feedbacks/me", headers=other_user_headers).json()
    other_ids = {item["id"] for item in other_list["data"]}
    assert theirs["id"] in other_ids
    assert mine["id"] not in other_ids


def test_my_feedbacks_pagination(
    client: TestClient,
    superuser_token_headers: Headers,
    other_user_headers: Headers,
    site_ids: list[str],
) -> None:
    for _ in range(3):
        artifact = _artifact(client, superuser_token_headers, site_ids)
        assert _send(client, other_user_headers, artifact["id"]).status_code == 201
    page = client.get(
        f"{API}/feedbacks/me",
        headers=other_user_headers,
        params={"skip": 0, "limit": 2},
    ).json()
    assert len(page["data"]) == 2
    assert page["count"] >= 3
    rest = client.get(
        f"{API}/feedbacks/me",
        headers=other_user_headers,
        params={"skip": 2, "limit": 2},
    ).json()
    assert {i["id"] for i in page["data"]}.isdisjoint({i["id"] for i in rest["data"]})
    bad = client.get(
        f"{API}/feedbacks/me", headers=other_user_headers, params={"limit": 0}
    )
    assert bad.status_code == 422


# ------------------------- Nội dung chưa duyệt không công khai ------------------
def test_only_approved_comments_are_public(
    client: TestClient,
    superuser_token_headers: Headers,
    normal_user_token_headers: Headers,
    other_user_headers: Headers,
    site_ids: list[str],
) -> None:
    artifact = _artifact(client, superuser_token_headers, site_ids)
    pending = _send(
        client, normal_user_token_headers, artifact["id"], comment="Chưa duyệt"
    ).json()
    only_rating = _send(client, other_user_headers, artifact["id"], rating=3).json()
    assert only_rating["status"] == "approved"

    # chưa duyệt: không hiện (khách không cần token); đánh giá chỉ có sao không phải bình luận
    assert _public(client, artifact["id"]) == []

    approved = _moderate(client, superuser_token_headers, pending["id"], "approved")
    assert approved.status_code == 200
    assert approved.json()["status"] == "approved"
    shown = _public(client, artifact["id"])
    assert [item["id"] for item in shown] == [pending["id"]]
    assert shown[0]["comment"] == "Chưa duyệt"
    # không lộ danh tính / trạng thái
    assert "user_id" not in shown[0]
    assert "status" not in shown[0]

    hidden = _moderate(client, superuser_token_headers, pending["id"], "hidden")
    assert hidden.status_code == 200
    assert _public(client, artifact["id"]) == []


def test_public_reviews_of_hidden_artifact_return_404(
    client: TestClient,
    superuser_token_headers: Headers,
    site_ids: list[str],
) -> None:
    artifact = _artifact(client, superuser_token_headers, site_ids)
    assert client.get(f"{API}/feedbacks/artifact/{artifact['id']}").status_code == 200
    client.delete(f"{API}/artifacts/{artifact['id']}", headers=superuser_token_headers)
    assert client.get(f"{API}/feedbacks/artifact/{artifact['id']}").status_code == 404
    assert client.get(f"{API}/feedbacks/artifact/{uuid.uuid4()}").status_code == 404
    assert client.get(f"{API}/feedbacks/artifact/not-a-uuid").status_code == 422


# --------------------------------- Sửa của chính mình ---------------------------
def test_edit_own_feedback_status_transitions(
    client: TestClient,
    superuser_token_headers: Headers,
    normal_user_token_headers: Headers,
    site_ids: list[str],
) -> None:
    artifact = _artifact(client, superuser_token_headers, site_ids)
    feedback = _send(
        client, normal_user_token_headers, artifact["id"], comment="Bản đầu"
    ).json()
    fid = feedback["id"]
    assert feedback["updated_at"] is None
    assert (
        _moderate(client, superuser_token_headers, fid, "approved").status_code == 200
    )

    # chỉ đổi rating: giữ approved
    edit_rating = client.put(
        f"{API}/feedbacks/{fid}", headers=normal_user_token_headers, json={"rating": 2}
    )
    assert edit_rating.status_code == 200
    assert edit_rating.json()["rating"] == 2
    assert edit_rating.json()["status"] == "approved"
    assert edit_rating.json()["updated_at"] is not None

    # sửa comment: approved -> pending và biến mất khỏi danh sách công khai
    edit_comment = client.put(
        f"{API}/feedbacks/{fid}",
        headers=normal_user_token_headers,
        json={"comment": "  Bản sửa  "},
    )
    assert edit_comment.status_code == 200
    assert edit_comment.json()["comment"] == "Bản sửa"
    assert edit_comment.json()["status"] == "pending"
    assert _public(client, artifact["id"]) == []

    # gửi lại đúng comment cũ (không đổi) khi đang pending: vẫn pending
    same = client.put(
        f"{API}/feedbacks/{fid}",
        headers=normal_user_token_headers,
        json={"comment": "Bản sửa", "rating": 4},
    )
    assert same.json()["status"] == "pending"

    # xóa comment: không còn gì để duyệt -> approved
    cleared = client.put(
        f"{API}/feedbacks/{fid}",
        headers=normal_user_token_headers,
        json={"comment": None},
    )
    assert cleared.status_code == 200
    assert cleared.json()["comment"] is None
    assert cleared.json()["status"] == "approved"
    assert cleared.json()["rating"] == 4


def test_hidden_feedback_stays_hidden_after_edit(
    client: TestClient,
    superuser_token_headers: Headers,
    normal_user_token_headers: Headers,
    site_ids: list[str],
) -> None:
    artifact = _artifact(client, superuser_token_headers, site_ids)
    fid = _send(
        client, normal_user_token_headers, artifact["id"], comment="Vi phạm"
    ).json()["id"]
    assert _moderate(client, superuser_token_headers, fid, "hidden").status_code == 200

    for body in ({"comment": "Đã sửa lại"}, {"comment": None}, {"rating": 1}):
        edited = client.put(
            f"{API}/feedbacks/{fid}", headers=normal_user_token_headers, json=body
        )
        assert edited.status_code == 200
        assert edited.json()["status"] == "hidden"
    assert _public(client, artifact["id"]) == []


def test_cannot_edit_other_users_feedback(
    client: TestClient,
    superuser_token_headers: Headers,
    normal_user_token_headers: Headers,
    other_user_headers: Headers,
    site_ids: list[str],
) -> None:
    artifact = _artifact(client, superuser_token_headers, site_ids)
    fid = _send(
        client, normal_user_token_headers, artifact["id"], comment="Gốc"
    ).json()["id"]

    for headers in (other_user_headers, superuser_token_headers):
        response = client.put(
            f"{API}/feedbacks/{fid}",
            headers=headers,
            json={"rating": 1, "comment": "Hack"},
        )
        assert response.status_code == 404

    mine = client.get(f"{API}/feedbacks/me", headers=normal_user_token_headers).json()
    original = next(item for item in mine["data"] if item["id"] == fid)
    assert original["rating"] == 5
    assert original["comment"] == "Gốc"
    assert original["status"] == "pending"


@pytest.mark.parametrize(
    "body",
    [{}, {"rating": None}, {"rating": 0}, {"rating": 9}, {"comment": "x" * 2001}],
)
def test_edit_feedback_validation(
    client: TestClient,
    superuser_token_headers: Headers,
    normal_user_token_headers: Headers,
    site_ids: list[str],
    body: dict[str, Any],
) -> None:
    artifact = _artifact(client, superuser_token_headers, site_ids)
    fid = _send(client, normal_user_token_headers, artifact["id"]).json()["id"]
    response = client.put(
        f"{API}/feedbacks/{fid}", headers=normal_user_token_headers, json=body
    )
    assert response.status_code == 422


def test_edit_unknown_feedback_returns_404_or_422(
    client: TestClient, normal_user_token_headers: Headers
) -> None:
    assert (
        client.put(
            f"{API}/feedbacks/{uuid.uuid4()}",
            headers=normal_user_token_headers,
            json={"rating": 3},
        ).status_code
        == 404
    )
    assert (
        client.put(
            f"{API}/feedbacks/not-a-uuid",
            headers=normal_user_token_headers,
            json={"rating": 3},
        ).status_code
        == 422
    )


def test_hidden_artifact_feedback_is_not_listed_or_editable(
    client: TestClient,
    superuser_token_headers: Headers,
    normal_user_token_headers: Headers,
    site_ids: list[str],
) -> None:
    artifact = _artifact(client, superuser_token_headers, site_ids)
    fid = _send(
        client, normal_user_token_headers, artifact["id"], comment="Trước khi ẩn"
    ).json()["id"]
    client.delete(f"{API}/artifacts/{artifact['id']}", headers=superuser_token_headers)

    mine = client.get(f"{API}/feedbacks/me", headers=normal_user_token_headers).json()
    assert fid not in {item["id"] for item in mine["data"]}
    edit = client.put(
        f"{API}/feedbacks/{fid}", headers=normal_user_token_headers, json={"rating": 1}
    )
    assert edit.status_code == 404
    # admin vẫn thấy để kiểm duyệt
    admin_list = client.get(
        f"{API}/feedbacks/",
        headers=superuser_token_headers,
        params={"artifact_id": artifact["id"]},
    ).json()
    assert [item["id"] for item in admin_list["data"]] == [fid]


# ------------------------------------ Admin duyệt -------------------------------


def test_admin_lists_and_moderates_feedback(
    client: TestClient,
    db: Session,
    superuser_token_headers: Headers,
    normal_user_token_headers: Headers,
    other_user_headers: Headers,
    site_ids: list[str],
) -> None:
    artifact = _artifact(client, superuser_token_headers, site_ids)
    pending = _send(
        client, normal_user_token_headers, artifact["id"], comment="Cần duyệt"
    ).json()
    auto_ok = _send(client, other_user_headers, artifact["id"], rating=3).json()

    def listing(**params: Any) -> dict[str, Any]:
        response = client.get(
            f"{API}/feedbacks/",
            headers=superuser_token_headers,
            params={"artifact_id": artifact["id"], **params},
        )
        assert response.status_code == 200, response.text
        return response.json()  # type: ignore[no-any-return]

    assert listing()["count"] == 2

    # Lọc pending và approved
    waiting = listing(status="pending")
    assert [item["id"] for item in waiting["data"]] == [pending["id"]]
    assert [item["id"] for item in listing(status="approved")["data"]] == [
        auto_ok["id"]
    ]
    assert listing(status="hidden")["count"] == 0
    assert listing(status="rejected")["count"] == 0

    # Admin chuyển pending -> hidden
    hidden = _moderate(client, superuser_token_headers, pending["id"], "hidden")
    assert hidden.status_code == 200
    assert hidden.json()["status"] == "hidden"
    assert [item["id"] for item in listing(status="hidden")["data"]] == [pending["id"]]

    # rejected là alias của hidden khi lọc
    rejected = listing(status="rejected")
    assert [item["id"] for item in rejected["data"]] == [pending["id"]]
    assert rejected["data"][0]["status"] == "hidden"

    # Admin có thể chuyển hidden -> pending
    reset = _moderate(client, superuser_token_headers, pending["id"], "pending")
    assert reset.status_code == 200
    assert reset.json()["status"] == "pending"
    assert [item["id"] for item in listing(status="pending")["data"]] == [pending["id"]]

    # Admin gửi rejected: API và database đều phải lưu hidden
    rejected_update = _moderate(
        client, superuser_token_headers, pending["id"], "rejected"
    )
    assert rejected_update.status_code == 200
    assert rejected_update.json()["status"] == "hidden"

    stored_feedback = db.get(Feedback, uuid.UUID(pending["id"]))
    assert stored_feedback is not None
    db.refresh(stored_feedback)
    assert stored_feedback.status == "hidden"

    # Cả hai bộ lọc hidden và rejected đều tìm thấy bản ghi
    assert [item["id"] for item in listing(status="hidden")["data"]] == [pending["id"]]
    assert [item["id"] for item in listing(status="rejected")["data"]] == [
        pending["id"]
    ]

    # Admin vẫn có thể duyệt lại hidden -> approved
    approved = _moderate(client, superuser_token_headers, pending["id"], "approved")
    assert approved.status_code == 200
    assert approved.json()["status"] == "approved"
    assert listing(status="pending")["count"] == 0
    assert listing(status="hidden")["count"] == 0
    assert listing(status="rejected")["count"] == 0


@pytest.mark.parametrize("bad_status", ["xyz", "", "APPROVED"])
def test_moderation_rejects_invalid_status(
    client: TestClient,
    superuser_token_headers: Headers,
    normal_user_token_headers: Headers,
    site_ids: list[str],
    bad_status: str,
) -> None:
    artifact = _artifact(client, superuser_token_headers, site_ids)
    fid = _send(
        client, normal_user_token_headers, artifact["id"], comment="Chờ"
    ).json()["id"]
    response = _moderate(client, superuser_token_headers, fid, bad_status)
    assert response.status_code == 422
    mine = client.get(f"{API}/feedbacks/me", headers=normal_user_token_headers).json()
    assert next(i for i in mine["data"] if i["id"] == fid)["status"] == "pending"


def test_moderation_unknown_feedback(
    client: TestClient, superuser_token_headers: Headers
) -> None:
    assert (
        _moderate(
            client, superuser_token_headers, str(uuid.uuid4()), "approved"
        ).status_code
        == 404
    )
    assert (
        _moderate(client, superuser_token_headers, "not-a-uuid", "approved").status_code
        == 422
    )
