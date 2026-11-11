# Project Argus

Project Argus is a network monitoring project that uses Suricata and Zeek to detect and collect network security events. The backend processes the log data, stores it in Snowflake, and the data will be displayed through a NiceGUI dashboard.

## Current Data Flow

```text
Suricata eve.json / Zeek notice.log
              ↓
        Python Backend
              ↓
           Snowflake
              ↓
       NiceGUI Dashboard
```

For the current sprint, we are focusing on a basic file-based integration first. Suricata and Zeek logs can be generated and passed to the backend, processed into Snowflake, and then retrieved by the dashboard.

## Backend Files

- `database.py` - Original SQLite backend used during earlier development and testing.
- `snowflake_database.py` - Handles the connection between Python and Snowflake.
- `suricata_parser.py` - Parses and normalizes Suricata alert data.
- `suricata_snowflake.py` - Processes Suricata EVE JSON files and stores alerts in Snowflake.
- `zeek_parser.py` - Parses Zeek `notice.log` files and stores notices in Snowflake.

## Setup

Install the required Python packages:

```bash
pip install -r requirements.txt
```

Create a `.env` file inside the `backend` folder:

```text
SNOWFLAKE_USER=your_username
SNOWFLAKE_ACCOUNT=your_account
SNOWFLAKE_ROLE=your_role
SNOWFLAKE_WAREHOUSE=your_warehouse
SNOWFLAKE_DATABASE=ARGUS
SNOWFLAKE_SCHEMA=PUBLIC
```

The `.env` file should not be pushed to GitHub.

## Snowflake Tables

The backend currently stores data in:

```text
ARGUS.PUBLIC.SURICATA_ALERTS
ARGUS.PUBLIC.ZEEK_NOTICES
```

## Running the Backend

To test the Snowflake connection:

```bash
cd backend
python snowflake_database.py
```

To process Suricata data:

```bash
python suricata_snowflake.py
```

To process Zeek notice data:

```bash
python zeek_parser.py
```

## Current Status

- Suricata alerts can be processed and stored in Snowflake.
- Suricata supports batching and duplicate handling.
- Zeek `notice.log` data can be processed and stored in Snowflake.
- SQLite is still kept for earlier/local testing.
- Snowflake-to-dashboard integration is still being worked on.
- Raspberry Pi-to-backend automation will be worked on later.