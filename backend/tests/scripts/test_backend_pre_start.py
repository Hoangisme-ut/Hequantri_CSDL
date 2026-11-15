import traceback
from unittest.mock import MagicMock, call, patch

import pytest

from app.backend_pre_start import init, main

PASSWORD = "StartupOnlySecret123!"
DATABASE_URL = (
    f"mssql+pymssql://startup_user:{PASSWORD}@db.invalid:1433/target_database"
)


def test_init_successful() -> None:
    engine_mock = MagicMock()
    with (
        patch("app.backend_pre_start.settings.DATABASE_URL", DATABASE_URL),
        patch(
            "app.backend_pre_start.create_engine", return_value=engine_mock
        ) as mock_create_engine,
        patch("time.sleep") as mock_sleep,
    ):
        init()
    mock_create_engine.assert_called_once_with(DATABASE_URL)
    engine_mock.connect.assert_called_once_with()
    connection = engine_mock.connect.return_value.__enter__.return_value
    connection.execute.assert_called_once()
    assert str(connection.execute.call_args.args[0]) == "SELECT 1"
    engine_mock.dispose.assert_called_once_with()
    mock_sleep.assert_not_called()


def test_init_retries_connections_and_stops_after_first_success() -> None:
    engine_mock = MagicMock()
    connection_context = MagicMock()
    engine_mock.connect.side_effect = [
        RuntimeError("Server is starting"),
        RuntimeError("Server is starting"),
        connection_context,
    ]
    with (
        patch("app.backend_pre_start.settings.DATABASE_URL", DATABASE_URL),
        patch(
            "app.backend_pre_start.create_engine", return_value=engine_mock
        ) as mock_create_engine,
        patch("time.sleep") as mock_sleep,
    ):
        init()
    mock_create_engine.assert_called()
    assert all(item == call(DATABASE_URL) for item in mock_create_engine.call_args_list)
    assert engine_mock.connect.call_count == 3
    engine_mock.dispose.assert_called()
    assert mock_sleep.call_args_list == [call(3)] * 2
    connection = connection_context.__enter__.return_value
    connection.execute.assert_called_once()
    assert str(connection.execute.call_args.args[0]) == "SELECT 1"


def test_init_retries_a_failed_probe() -> None:
    engine_mock = MagicMock()
    connection = engine_mock.connect.return_value.__enter__.return_value
    connection.execute.side_effect = [RuntimeError("Probe failed"), None]
    with (
        patch("app.backend_pre_start.settings.DATABASE_URL", DATABASE_URL),
        patch("app.backend_pre_start.create_engine", return_value=engine_mock),
        patch("time.sleep") as mock_sleep,
    ):
        init()
    assert engine_mock.connect.call_count == 2
    engine_mock.dispose.assert_called()
    mock_sleep.assert_called_once_with(3)
    assert [str(item.args[0]) for item in connection.execute.call_args_list] == [
        "SELECT 1",
        "SELECT 1",
    ]


def test_init_refuses_master_and_unspecified_databases() -> None:
    for database in ("master", "MaStEr", ""):
        target_url = f"{DATABASE_URL.rsplit('/', 1)[0]}/{database}"
        with (
            patch("app.backend_pre_start.settings.DATABASE_URL", target_url),
            patch("app.backend_pre_start.create_engine") as mock_create_engine,
            patch("app.backend_pre_start.logger"),
            patch("time.sleep"),
        ):
            with pytest.raises(RuntimeError, match="database must already exist"):
                init()
        mock_create_engine.assert_not_called()


def test_init_failure() -> None:
    engine_mock = MagicMock()
    engine_mock.connect.side_effect = RuntimeError("Database is unavailable")
    with (
        patch("app.backend_pre_start.settings.DATABASE_URL", DATABASE_URL),
        patch(
            "app.backend_pre_start.create_engine", return_value=engine_mock
        ) as mock_create_engine,
        patch("time.sleep") as mock_sleep,
    ):
        with pytest.raises(RuntimeError, match="database must already exist") as error:
            init()
    message = str(error.value)
    assert "10 attempts" in message
    assert "db-init" in message
    assert "Azure portal" in message
    mock_create_engine.assert_called()
    assert all(item == call(DATABASE_URL) for item in mock_create_engine.call_args_list)
    assert engine_mock.connect.call_count == 10
    engine_mock.dispose.assert_called()
    assert mock_sleep.call_args_list == [call(3)] * 9


def test_init_failure_never_exposes_credentials() -> None:
    for failure_stage in ("engine", "connect", "probe"):
        engine_mock = MagicMock()
        failure = RuntimeError(f"Connection failed: {DATABASE_URL}")
        if failure_stage == "connect":
            engine_mock.connect.side_effect = failure
        elif failure_stage == "probe":
            engine_mock.connect.return_value.__enter__.return_value.execute.side_effect = failure
        with (
            patch("app.backend_pre_start.settings.DATABASE_URL", DATABASE_URL),
            patch(
                "app.backend_pre_start.create_engine", return_value=engine_mock
            ) as mock_create_engine,
            patch("app.backend_pre_start.logger") as mock_logger,
            patch("time.sleep") as mock_sleep,
        ):
            if failure_stage == "engine":
                mock_create_engine.side_effect = failure
            with pytest.raises(RuntimeError) as error:
                init()
        assert PASSWORD not in str(mock_logger.method_calls)
        assert DATABASE_URL not in str(mock_logger.method_calls)
        assert PASSWORD not in "".join(traceback.format_exception(error.value))
        assert "database must already exist" in str(error.value)
        mock_logger.error.assert_called_once_with(str(error.value))
        assert mock_sleep.call_count == 9


def test_main() -> None:
    with patch("app.backend_pre_start.init") as mock_init:
        main()
        mock_init.assert_called_once()
