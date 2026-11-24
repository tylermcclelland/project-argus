import sqlite3

# Project Argus database helper functions.
# This file manages the SQLite database used by the backend and dashboard.
#
# Main functions:
# - initialize_database(): creates the database/table/indexes
# - insert_alert(): inserts one alert
# - insert_alert_with_cursor(): used for large Suricata imports
# - get_latest_alerts(): returns a limited number of newest alerts
# - get_alerts_by_severity(): filters alerts by severity
# - get_alert_count(): returns total number of stored alerts


def initialize_database():
    """Create the Argus database, alerts table, and indexes if needed."""

    conn = sqlite3.connect("argus.db")
    cursor = conn.cursor()

    # Store processed Suricata alert information.
    cursor.execute("""
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
    """)

    # Indexes make common dashboard searches faster,
    # especially now that the database contains millions of alerts.
    cursor.execute("""
    CREATE INDEX IF NOT EXISTS idx_alerts_timestamp
    ON alerts(timestamp)
    """)

    cursor.execute("""
    CREATE INDEX IF NOT EXISTS idx_alerts_source_ip
    ON alerts(source_ip)
    """)

    cursor.execute("""
    CREATE INDEX IF NOT EXISTS idx_alerts_severity
    ON alerts(severity)
    """)

    conn.commit()
    conn.close()


def insert_alert(timestamp, source_ip, destination_ip, protocol,
                 alert_type, category, severity, source_tool):
    """Insert one processed alert into the Argus database."""

    conn = sqlite3.connect("argus.db")
    cursor = conn.cursor()

    # INSERT OR IGNORE skips the record if the same alert
    # already exists because of the UNIQUE rule above.
    cursor.execute("""
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
    """, (
        timestamp,
        source_ip,
        destination_ip,
        protocol,
        alert_type,
        category,
        severity,
        source_tool
    ))

    inserted = cursor.rowcount > 0

    conn.commit()
    conn.close()

    return inserted


def insert_alert_with_cursor(cursor, timestamp, source_ip, destination_ip,
                             protocol, alert_type, category,
                             severity, source_tool):
    """
    Insert one alert using an already-open database connection.

    This is used by suricata_parser.py when importing a large number
    of alerts so the database does not need to open and close for
    every single record.
    """

    cursor.execute("""
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
    """, (
        timestamp,
        source_ip,
        destination_ip,
        protocol,
        alert_type,
        category,
        severity,
        source_tool
    ))

    return cursor.rowcount > 0


def get_alerts():
    """Retrieve all alerts currently stored in SQLite."""

    conn = sqlite3.connect("argus.db")
    cursor = conn.cursor()

    # Be careful using this with the full database because it
    # currently contains millions of alert records.
    cursor.execute("SELECT * FROM alerts")
    alerts = cursor.fetchall()

    conn.close()

    return alerts


def get_latest_alerts(limit=20):
    """
    Retrieve the newest alerts.

    This is useful for the dashboard because it avoids loading
    millions of rows at once.
    """

    conn = sqlite3.connect("argus.db")
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    cursor.execute("""
    SELECT *
    FROM alerts
    ORDER BY timestamp DESC
    LIMIT ?
    """, (limit,))

    rows = cursor.fetchall()

    # Convert each SQLite row into a dictionary so fields can be
    # accessed by name, such as alert["timestamp"].
    alerts = [dict(row) for row in rows]

    conn.close()

    return alerts


def get_alerts_by_severity(severity, limit=20):
    """Retrieve the newest alerts matching a specific severity."""

    conn = sqlite3.connect("argus.db")
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    cursor.execute("""
    SELECT *
    FROM alerts
    WHERE severity = ?
    ORDER BY timestamp DESC
    LIMIT ?
    """, (severity, limit))

    rows = cursor.fetchall()
    alerts = [dict(row) for row in rows]

    conn.close()

    return alerts


def get_alert_count():
    """Return the total number of alerts currently stored in SQLite."""

    conn = sqlite3.connect("argus.db")
    cursor = conn.cursor()

    cursor.execute("SELECT COUNT(*) FROM alerts")
    count = cursor.fetchone()[0]

    conn.close()

    return count


# This section only runs when database.py is executed directly.
# It does not run when another file imports these functions.
if __name__ == "__main__":
    initialize_database()
    print("Argus database initialized successfully.")

    latest_alerts = get_latest_alerts(20)

    print("\nLATEST 20 ALERTS:")

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