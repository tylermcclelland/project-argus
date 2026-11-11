from pathlib import Path

from snowflake_database import get_snowflake_connection


def clean_zeek_value(value):
    """
    Convert Zeek's missing-value marker "-" into None.
    """
    if value in (None, "-", "(empty)"):
        return None

    return value


def parse_optional_int(value):
    """
    Convert a Zeek value to an integer when possible.
    Return None when the field is missing.
    """
    value = clean_zeek_value(value)

    if value is None:
        return None

    return int(value)


def parse_optional_float(value):
    """
    Convert a Zeek value to a float when possible.
    Return None when the field is missing.
    """
    value = clean_zeek_value(value)

    if value is None:
        return None

    return float(value)


def read_zeek_notices(file_name, limit=None):
    """
    Read Zeek notice.log and convert each notice into the normalized
    format used by the Project Argus backend.

    Zeek describes its columns in the #fields header. The header names
    are matched with each data row so the parser does not rely on
    hardcoded column positions.
    """
    fields = None
    notices = []

    with open(file_name, "r", encoding="utf-8") as file:
        for line in file:
            # Read the column names defined by Zeek.
            if line.startswith("#fields"):
                fields = line.strip().split("\t")[1:]
                continue

            # Ignore other Zeek metadata/header lines.
            if line.startswith("#"):
                continue

            if not line.strip() or fields is None:
                continue

            values = line.rstrip("\n").split("\t")

            # Match each Zeek field name with its value.
            data = dict(zip(fields, values))

            notice = {
                "timestamp": parse_optional_float(data.get("ts")),
                "uid": clean_zeek_value(data.get("uid")),
                "source_ip": clean_zeek_value(data.get("id.orig_h")),
                "source_port": parse_optional_int(data.get("id.orig_p")),
                "destination_ip": clean_zeek_value(data.get("id.resp_h")),
                "destination_port": parse_optional_int(
                    data.get("id.resp_p")
                ),
                "protocol": clean_zeek_value(data.get("proto")),
                "notice_type": clean_zeek_value(data.get("note")),
                "message": clean_zeek_value(data.get("msg")),
                "source_tool": "Zeek",
            }

            notices.append(notice)

            if limit is not None and len(notices) >= limit:
                break

    return notices


def insert_notices_into_snowflake(notices):
    """
    Store normalized Zeek notices in Snowflake.

    MERGE is used so a notice that already exists in ZEEK_NOTICES
    is not inserted again.
    """
    if not notices:
        print("No Zeek notices to process.")
        return

    conn = None
    cursor = None

    try:
        conn = get_snowflake_connection()
        cursor = conn.cursor()

        for notice in notices:
            cursor.execute(
                """
                MERGE INTO ZEEK_NOTICES AS target

                USING (
                    SELECT
                        %s AS timestamp,
                        %s AS uid,
                        %s AS source_ip,
                        %s AS source_port,
                        %s AS destination_ip,
                        %s AS destination_port,
                        %s AS protocol,
                        %s AS notice_type,
                        %s AS message,
                        %s AS source_tool
                ) AS source

                ON target.timestamp = source.timestamp
                   AND COALESCE(target.uid, '') =
                       COALESCE(source.uid, '')
                   AND COALESCE(target.notice_type, '') =
                       COALESCE(source.notice_type, '')

                WHEN NOT MATCHED THEN
                    INSERT (
                        timestamp,
                        uid,
                        source_ip,
                        source_port,
                        destination_ip,
                        destination_port,
                        protocol,
                        notice_type,
                        message,
                        source_tool
                    )
                    VALUES (
                        source.timestamp,
                        source.uid,
                        source.source_ip,
                        source.source_port,
                        source.destination_ip,
                        source.destination_port,
                        source.protocol,
                        source.notice_type,
                        source.message,
                        source.source_tool
                    )
                """,
                (
                    notice["timestamp"],
                    notice["uid"],
                    notice["source_ip"],
                    notice["source_port"],
                    notice["destination_ip"],
                    notice["destination_port"],
                    notice["protocol"],
                    notice["notice_type"],
                    notice["message"],
                    notice["source_tool"],
                ),
            )

        conn.commit()

        print(
            f"\nProcessed {len(notices)} Zeek notices into Snowflake."
        )

    finally:
        if cursor:
            cursor.close()

        if conn:
            conn.close()


if __name__ == "__main__":
    # Locate the Zeek log relative to this Python file.
    notice_file = (
        Path(__file__).parent
        / "zeek_logs"
        / "bigFlows"
        / "notice.log"
    )

    notices = read_zeek_notices(
        notice_file,
        limit=None,
    )

    print(f"Read {len(notices)} Zeek notices.")

    insert_notices_into_snowflake(notices)