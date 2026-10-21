from unittest.mock import MagicMock, patch

from app.initial_data import init, main


def test_init_successful() -> None:
    with (
        patch("app.initial_data.Session") as mock_session,
        patch("app.initial_data.init_db") as mock_init_db,
    ):
        session_instance = MagicMock()
        mock_session.return_value.__enter__.return_value = session_instance
        init()
        mock_init_db.assert_called_once_with(session_instance)


def test_main() -> None:
    with patch("app.initial_data.init") as mock_init:
        main()
        mock_init.assert_called_once()
