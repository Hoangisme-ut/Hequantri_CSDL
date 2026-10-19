from unittest.mock import MagicMock, patch

import pytest

from app.backend_pre_start import init, main


def test_init_successful() -> None:
    engine_mock = MagicMock()
    with (
        patch("app.backend_pre_start.create_engine", return_value=engine_mock),
        patch.object(engine_mock, "connect") as mock_connect,
    ):
        conn_mock = MagicMock()
        mock_connect.return_value.__enter__.return_value = conn_mock
        init()
        conn_mock.execute.assert_called_once()


def test_init_failure() -> None:
    engine_mock = MagicMock()
    with (
        patch("app.backend_pre_start.create_engine", return_value=engine_mock),
        patch.object(
            engine_mock, "connect", side_effect=Exception("DB Connection Error")
        ),
    ):
        with pytest.raises(Exception, match="DB Connection Error"):
            init()


def test_main() -> None:
    with patch("app.backend_pre_start.init") as mock_init:
        main()
        mock_init.assert_called_once()
