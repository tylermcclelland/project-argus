import os

import snowflake.connector
from dotenv import load_dotenv


# Load Snowflake settings from a local .env file.
# The .env file should never be pushed to GitHub.
load_dotenv()


def get_snowflake_connection():
    """
    Create and return a connection to the Project Argus Snowflake database.

    Connection settings are loaded from environment variables instead of
    being hardcoded in this file.
    """
    return snowflake.connector.connect(
        user=os.getenv("SNOWFLAKE_USER"),
        account=os.getenv("SNOWFLAKE_ACCOUNT"),
        authenticator="OAUTH_AUTHORIZATION_CODE",
        role=os.getenv("SNOWFLAKE_ROLE"),
        warehouse=os.getenv("SNOWFLAKE_WAREHOUSE"),
        database=os.getenv("SNOWFLAKE_DATABASE"),
        schema=os.getenv("SNOWFLAKE_SCHEMA"),
        oauth_redirect_uri="http://127.0.0.1:8765",
        authentication_timeout=300,
        client_store_temporary_credential=True,
    )


def test_snowflake_connection():
    """
    Test the Snowflake connection and print the current Snowflake version.
    """
    conn = None
    cursor = None

    try:
        conn = get_snowflake_connection()
        cursor = conn.cursor()

        print("Connected to Snowflake successfully!")

        cursor.execute("SELECT CURRENT_VERSION()")
        version = cursor.fetchone()[0]

        print(f"Snowflake version: {version}")

    finally:
        if cursor:
            cursor.close()

        if conn:
            conn.close()


if __name__ == "__main__":
    test_snowflake_connection()