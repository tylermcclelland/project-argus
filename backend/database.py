import sqlite3
from pathlib import Path


"""
Local SQLite database helpers for Project Argus.

This module supports the original SQLite backend used during development
and by the early dashboard prototype.

The newer Snowflake ingestion pipeline is handled separately by:
- snowflake_database.py
- suricata_snowflake.py
- zeek_parser.py
"""


# Keep the SQLite database in the same directory as this Python file.
DB_PATH = Path(__file__).with_name("argus.db")


def initialize_database():
    """
    Create the local Argus SQLite database, alerts table, and indexes
    if they do not already exist.
    """
    with sqlite3.connect(DB_PATH) as conn:
        cursor = conn.cursor()

        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS alerts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT,
                source_ip TEXT,
                destination_ip TEXT,
                protocol TEXT,
                alert_type TEXT,
                category TEXT,
                severity INTEGER,
                source_tool TEXT,

                UNIQUE (
                    timestamp,
                    source_ip,
                    destination_ip,
                    protocol,
                    alert_type,
                    category,
                    severity,
                    source_tool
                )
            )
            """
        )

        # Indexes improve common dashboard queries when the database
        # contains a large number of alerts.
        cursor.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_alerts_timestamp
            ON alerts(timestamp)
            """
        )

        cursor.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_alerts_source_ip
            ON alerts(source_ip)
            """
        )

        cursor.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_alerts_severity
            ON alerts(severity)
            """
        )


def insert_alert(
    timestamp,
    source_ip,
    destination_ip,
    protocol,
    alert_type,
    category,
    severity,
    source_tool,
):
    """
    Insert one alert into the local SQLite database.

    INSERT OR IGNORE prevents duplicate alerts from being added because
    the alerts table has a UNIQUE constraint across the stored fields.
    """
    with sqlite3.connect(DB_PATH) as conn:
        cursor = conn.cursor()

        cursor.execute(
            """
            INSERT OR IGNORE INTO alerts (
                timestamp,
                source_ip,
                destination_ip,
                protocol,
                alert_type,
                category,
                severity,
                source_tool
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                timestamp,
                source_ip,
                destination_ip,
                protocol,
                alert_type,
                category,
                severity,
                source_tool,
            ),
        )

        return cursor.rowcount > 0


def insert_alert_with_cursor(
    cursor,
    timestamp,
    source_ip,
    destination_ip,
    protocol,
    alert_type,
    category,
    severity,
    source_tool,
):
    """
    Insert one alert using an already-open SQLite cursor.

    This is used by suricata_parser.py during large imports so a new
    database connection does not need to be created for every alert.
    """
    cursor.execute(
        """
        INSERT OR IGNORE INTO alerts (
            timestamp,
            source_ip,
            destination_ip,
            protocol,
            alert_type,
            category,
            severity,
            source_tool
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            timestamp,
            source_ip,
            destination_ip,
            protocol,
            alert_type,
            category,
            severity,
            source_tool,
        ),
    )

    return cursor.rowcount > 0


def get_alerts():
    """
    Retrieve every alert stored in the local SQLite database.

    Avoid using this with very large databases because it loads every
    matching row into memory.
    """
    with sqlite3.connect(DB_PATH) as conn:
        cursor = conn.cursor()

        cursor.execute("SELECT * FROM alerts")
        return cursor.fetchall()


def get_latest_alerts(limit=20):
    """
    Retrieve the newest alerts from the local SQLite database.

    Results are returned as dictionaries so callers can access fields
    by name, such as alert["timestamp"].
    """
    with sqlite3.connect(DB_PATH) as conn:
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()

        cursor.execute(
            """
            SELECT *
            FROM alerts
            ORDER BY timestamp DESC
            LIMIT ?
            """,
            (limit,),
        )

        return [dict(row) for row in cursor.fetchall()]


def get_alerts_by_severity(severity, limit=20):
    """
    Retrieve the newest alerts matching a specific severity level.
    """
    with sqlite3.connect(DB_PATH) as conn:
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()

        cursor.execute(
            """
            SELECT *
            FROM alerts
            WHERE severity = ?
            ORDER BY timestamp DESC
            LIMIT ?
            """,
            (severity, limit),
        )

        return [dict(row) for row in cursor.fetchall()]


def get_alert_count():
    """
    Return the total number of alerts stored in the local SQLite database.
    """
    with sqlite3.connect(DB_PATH) as conn:
        cursor = conn.cursor()

        cursor.execute("SELECT COUNT(*) FROM alerts")
        return cursor.fetchone()[0]


if __name__ == "__main__":
    initialize_database()

    print("Argus SQLite database initialized successfully.")

    latest_alerts = get_alerts_by_severity(3, 20)

    print("\nLATEST 20 SEVERITY 3 ALERTS:")

    for alert in latest_alerts:
        print("\n------------------------------")
        print(f"Alert ID:       {alert['id']}")
        print(f"Timestamp:      {alert['timestamp']}")
        print(f"Source IP:      {alert['source_ip']}")
        print(f"Destination IP: {alert['destination_ip']}")
        print(f"Protocol:       {alert['protocol']}")
        print(f"Alert Type:     {alert['alert_type']}")
        print(f"Category:       {alert['category']}")
        print(f"Severity:       {alert['severity']}")
        print(f"Source Tool:    {alert['source_tool']}")