import json
import sqlite3

from database import (
    initialize_database,
    insert_alert_with_cursor,
    get_alert_count,
)


def parse_suricata_alert(data):
    """
    Convert one Suricata EVE alert event into the normalized
    format used by the Project Argus backend.

    This function only transforms the data. It does not read files
    or store anything in a database.
    """
    alert_data = data.get("alert", {})

    return {
        "timestamp": data.get("timestamp"),
        "source_ip": data.get("src_ip"),
        "destination_ip": data.get("dest_ip"),
        "protocol": data.get("proto"),
        "alert_type": alert_data.get("signature"),
        "category": alert_data.get("category"),
        "severity": alert_data.get("severity"),
        "source_tool": "Suricata",
    }


def process_eve_file(file_name):
    """
    Read a Suricata EVE JSON file line by line and store alert events
    in the local SQLite database.

    This is the original/local SQLite ingestion path. The Snowflake
    ingestion path reuses parse_suricata_alert() from this file.
    """
    processed_count = 0
    stored_count = 0
    duplicate_count = 0
    invalid_count = 0

    # Open one SQLite connection for the entire import.
    conn = sqlite3.connect("argus.db")
    cursor = conn.cursor()

    try:
        # EVE JSON stores one JSON event per line, so the file can be
        # processed without loading the entire file into memory.
        with open(file_name, "r", encoding="utf-8") as file:
            for line in file:
                if not line.strip():
                    continue

                # Skip malformed JSON lines while tracking how many occurred.
                try:
                    data = json.loads(line)
                except json.JSONDecodeError:
                    invalid_count += 1
                    continue

                # Only Suricata alert events are needed for this pipeline.
                # Other event types such as flow, DNS, and HTTP are ignored.
                if data.get("event_type") != "alert":
                    continue

                processed_count += 1

                alert = parse_suricata_alert(data)

                inserted = insert_alert_with_cursor(
                    cursor,
                    alert["timestamp"],
                    alert["source_ip"],
                    alert["destination_ip"],
                    alert["protocol"],
                    alert["alert_type"],
                    alert["category"],
                    alert["severity"],
                    alert["source_tool"],
                )

                if inserted:
                    stored_count += 1
                else:
                    duplicate_count += 1

                # Print occasional progress instead of printing every alert.
                if processed_count % 1000 == 0:
                    print(f"Processed {processed_count} alerts...")

        conn.commit()

    finally:
        conn.close()

    return processed_count, stored_count, duplicate_count, invalid_count


if __name__ == "__main__":
    initialize_database()

    print("\nProcessing Suricata EVE JSON file into SQLite...")

    processed_count, stored_count, duplicate_count, invalid_count = (
        process_eve_file("eve.json")
    )

    total_alerts = get_alert_count()

    print("\n==============================")
    print("Suricata Processing Complete")
    print("==============================")
    print(f"Alerts processed:          {processed_count}")
    print(f"New alerts stored:         {stored_count}")
    print(f"Duplicate alerts skipped:  {duplicate_count}")
    print(f"Invalid JSON lines:        {invalid_count}")
    print(f"Total alerts in database:  {total_alerts}")