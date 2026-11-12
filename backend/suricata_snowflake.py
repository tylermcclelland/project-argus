import json
from pathlib import Path

from snowflake_database import get_snowflake_connection
from suricata_parser import parse_suricata_alert


def read_suricata_alerts(file_name, limit=5):
    """
    Read a small number of Suricata alert events from an EVE JSON file.

    This helper is useful for testing the parser without processing
    the entire EVE file.
    """
    alerts = []

    with open(file_name, "r", encoding="utf-8") as file:
        for line in file:
            if not line.strip():
                continue

            try:
                data = json.loads(line)
            except json.JSONDecodeError:
                continue

            # Only Suricata alert events are needed for this pipeline.
            if data.get("event_type") != "alert":
                continue

            alerts.append(parse_suricata_alert(data))

            if len(alerts) >= limit:
                break

    return alerts


def insert_suricata_alerts_into_snowflake(cursor, alerts):
    """
    Insert one batch of normalized Suricata alerts into Snowflake.

    Alerts are first loaded into a temporary staging table. A MERGE
    then inserts only records that do not already exist in the
    permanent SURICATA_ALERTS table.
    """
    if not alerts:
        return

    # This temporary table exists only for the current Snowflake session.
    cursor.execute(
        """
        CREATE TEMPORARY TABLE IF NOT EXISTS SURICATA_ALERTS_STAGE (
            timestamp STRING,
            source_ip STRING,
            destination_ip STRING,
            protocol STRING,
            alert_type STRING,
            category STRING,
            severity INTEGER,
            source_tool STRING
        )
        """
    )

    # Reuse the same staging table for every batch.
    cursor.execute("TRUNCATE TABLE SURICATA_ALERTS_STAGE")

    rows = [
        (
            alert["timestamp"],
            alert["source_ip"],
            alert["destination_ip"],
            alert["protocol"],
            alert["alert_type"],
            alert["category"],
            alert["severity"],
            alert["source_tool"],
        )
        for alert in alerts
    ]

    # Send the entire batch to Snowflake instead of inserting alerts
    # one database operation at a time.
    cursor.executemany(
        """
        INSERT INTO SURICATA_ALERTS_STAGE (
            timestamp,
            source_ip,
            destination_ip,
            protocol,
            alert_type,
            category,
            severity,
            source_tool
        )
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """,
        rows,
    )

    # Merge the staging batch into the permanent table.
    # SELECT DISTINCT removes duplicate rows inside the current batch.
    # The MERGE prevents matching records already stored in Snowflake
    # from being inserted again.
    cursor.execute(
        """
        MERGE INTO SURICATA_ALERTS AS target

        USING (
            SELECT DISTINCT
                timestamp,
                source_ip,
                destination_ip,
                protocol,
                alert_type,
                category,
                severity,
                source_tool
            FROM SURICATA_ALERTS_STAGE
        ) AS source

        ON target.timestamp = source.timestamp
           AND target.source_ip = source.source_ip
           AND target.destination_ip = source.destination_ip
           AND target.protocol = source.protocol
           AND target.alert_type = source.alert_type
           AND target.category = source.category
           AND target.severity = source.severity
           AND target.source_tool = source.source_tool

        WHEN NOT MATCHED THEN
            INSERT (
                timestamp,
                source_ip,
                destination_ip,
                protocol,
                alert_type,
                category,
                severity,
                source_tool
            )
            VALUES (
                source.timestamp,
                source.source_ip,
                source.destination_ip,
                source.protocol,
                source.alert_type,
                source.category,
                source.severity,
                source.source_tool
            )
        """
    )

    print(f"Processed batch of {len(alerts)} Suricata alerts.")


def process_eve_in_batches(file_name, batch_size=5000, max_alerts=None):
    """
    Process a Suricata EVE JSON file and store alert events in Snowflake.

    The file is read one line at a time and alerts are sent to Snowflake
    in batches so large EVE files do not need to be loaded entirely
    into memory.

    max_alerts can be set during testing to stop after a specific number
    of alerts. Leave it as None to process the entire file.
    """
    conn = None
    cursor = None

    batch = []
    processed_count = 0
    invalid_count = 0

    try:
        conn = get_snowflake_connection()
        cursor = conn.cursor()

        with open(file_name, "r", encoding="utf-8") as file:
            for line in file:
                if not line.strip():
                    continue

                try:
                    data = json.loads(line)
                except json.JSONDecodeError:
                    invalid_count += 1
                    continue

                # Ignore non-alert Suricata events such as flow, DNS,
                # and HTTP events.
                if data.get("event_type") != "alert":
                    continue

                batch.append(parse_suricata_alert(data))
                processed_count += 1

                # Send a full batch to Snowflake.
                if len(batch) >= batch_size:
                    insert_suricata_alerts_into_snowflake(cursor, batch)

                    print(
                        f"Total Suricata alerts processed: {processed_count}"
                    )

                    # Release the processed batch so the list can be reused.
                    batch.clear()

                # Optional limit for small test runs.
                if (
                    max_alerts is not None
                    and processed_count >= max_alerts
                ):
                    break

        # Process any remaining alerts that did not fill a complete batch.
        if batch:
            insert_suricata_alerts_into_snowflake(cursor, batch)

        conn.commit()

        print("\n================================")
        print("Suricata Snowflake Import Complete")
        print("================================")
        print(f"Alerts processed:     {processed_count}")
        print(f"Invalid JSON lines:   {invalid_count}")

    finally:
        if cursor:
            cursor.close()

        if conn:
            conn.close()


if __name__ == "__main__":
    # Locate eve.json relative to this Python file instead of depending
    # on which folder the terminal was opened from.
    eve_file = Path(__file__).with_name("eve.json")

    process_eve_in_batches(
        eve_file,
        batch_size=5000,
        max_alerts=None,
    )