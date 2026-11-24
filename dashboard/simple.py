# Install dependencies before running:
# python3 -m pip install nicegui 

from snowflake_database import get_snowflake_connection
import calendar
from datetime import datetime
from functools import lru_cache
from nicegui import ui
import design

# Count total alerts and alerts by severity for the simple mode Home page 
@lru_cache(maxsize = 1)
def alert_severity():
    conn = get_snowflake_connection()
    cursor = conn.cursor()
    rows = cursor.execute('''
        SELECT 
            COUNT(*) AS total_alerts,
            COUNT(CASE WHEN severity = 1 THEN 1 END) AS high_alerts,
            COUNT(CASE WHEN severity = 2 THEN 1 END) AS medium_alerts,
            COUNT(CASE WHEN severity = 3 THEN 1 END) AS low_alerts
        FROM ARGUS.PUBLIC.SURICATA_ALERTS
        ''').fetchone()
    cursor.close()
    conn.close()
    return rows

# Count alerts by minute for the activity graph 
@lru_cache(maxsize = 1)
def alert_activity():
    conn = get_snowflake_connection()
    cursor = conn.cursor()
    rows = cursor.execute('''
        SELECT
            SUBSTR(timestamp, 1, 16) AS minute,
            COUNT(*) AS total_alerts
        FROM ARGUS.PUBLIC.SURICATA_ALERTS
        WHERE timestamp IS NOT NULL
        GROUP BY minute
        ORDER BY minute
    ''').fetchall()
    cursor.close()
    conn.close()
    return [
        (datetime.strptime(row[0], '%Y-%m-%dT%H:%M').isoformat(), row[1])
        for row in rows
    ]

# Home page 
def simple_home(severity_selected):
    total_alerts, high_alerts, medium_alerts, low_alerts = alert_severity()
    rows = alert_activity()

    with ui.column().classes('w-full gap-4'):
        with ui.element('div').classes('grid w-full'):
            with ui.card().classes('card w-full h-64 p-4 items-center justify-center'):
                ui.label('Total Alerts').classes('text-lg font-semibold text-center')
                ui.label(f'{total_alerts:,}').classes('text-2xl font-bold').style('color: #7764A6')
            design.severity_card('High Severity', high_alerts, total_alerts, '#D988AA', 1, severity_selected)
            design.severity_card('Medium Severity', medium_alerts, total_alerts, '#E2B26C', 2, severity_selected)
            design.severity_card('Low Severity', low_alerts, total_alerts, '#88B8A5', 3, severity_selected)

        with ui.card().classes('card w-full p-5'):
            ui.label('Alert Activity').classes('w-full text-center text-xl font-semibold')
            ui.echart(design.graph(rows, '#AD8BD9')).classes('w-full').style('height: 320px')

# Search alerts with filters
@lru_cache(maxsize = 128)
def search_alerts(filter_by, search, start_time, end_time, page = 0):
        conditions = []
        params = []
        search = (search or '').strip()
        limit = 50

        if filter_by == 'time':
            if not start_time or not end_time:
                return [], False
            times = design.format_time(start_time, end_time)
            if times is None:
                return [], False
            start_time, end_time = times

        # Filter alerts based on the selected search option
        if filter_by == 'time':
            conditions.append('substr(timestamp, 12, 5) BETWEEN %s AND %s')
            params.extend([start_time, end_time])    
        elif search:
            if filter_by == 'all':
                conditions.append('''(
                    timestamp LIKE %s
                    OR CAST(severity AS VARCHAR) LIKE %s
                    OR category LIKE %s
                    OR alert_type LIKE %s
                    OR source_ip LIKE %s
                    OR destination_ip LIKE %s
                )''')
                params.extend([f'%{search}%'] * 6)
            elif filter_by == 'date':
                conditions.append("substr(timestamp, 1, 10) = %s")
                params.append(search)
            elif filter_by == 'year':
                conditions.append("substr(timestamp, 1, 4) = %s")
                params.append(search)
            elif filter_by == 'month':
                month = next((
                    i for i in range(1, 13)
                    if search.lower() in (
                        calendar.month_name[i].lower(),
                        calendar.month_abbr[i].lower(),
                        str(i),
                        f'{i:02d}'
                    )
                ), None)
                if month is None:
                    return [], False
                conditions.append("substr(timestamp, 6, 2) = %s")
                params.append(f'{month:02d}')
            elif filter_by == 'severity':
                if not search.isdigit():
                    return [], False
                conditions.append("severity = %s")
                params.append(int(search))
            else:
                fields = {
                    'category': 'category',
                    'rule': 'alert_type',
                    'source_ip': 'source_ip',
                    'destination_ip': 'destination_ip'
                }
                column = fields[filter_by]
                conditions.append(f"{column} LIKE %s")
                params.append(f'%{search}%')

        where = f"WHERE {' AND '.join(conditions)}" if conditions else ''
        query = f'''
            SELECT
                timestamp,
                severity,
                category,
                alert_type,
                source_ip,
                destination_ip
            FROM ARGUS.PUBLIC.SURICATA_ALERTS
            {where}
            ORDER BY timestamp DESC, severity, category, alert_type, source_ip, destination_ip
            LIMIT %s 
            OFFSET %s
        '''

        # Retrieve up to 50 alerts per page and check for more results
        params.extend([limit + 1, page * limit])
        conn = get_snowflake_connection()
        cursor = conn.cursor()
        try:
            results = cursor.execute(query, tuple(params)).fetchall()
        finally:
            cursor.close()
            conn.close()
        columns = [
            'timestamp', 'severity', 'category',
            'alert_type', 'source_ip', 'destination_ip'
        ]
        # Convert Snowflake results into dictionaries and assign temporary row IDs
        alerts = []
        for index, row in enumerate(results[:limit]):
            alert = dict(zip(columns, row))
            alert['id'] = page * limit + index
            alerts.append(alert)
        next_page = len(results) > limit
        return alerts, next_page

# Simple dashboard layout
def simple_dashboard(severity = None):
    with ui.column().classes('w-full gap-4'):
        ui.label('Security Alerts').classes('text-xl font-bold').style('color: #7764A6')
        with ui.card().classes('card w-full p-5'):

            # Create search controls with specific filters
            options = {
                'all': 'All',
                'time': 'Time',
                'date': 'Date',
                'year': 'Year',
                'month': 'Month',
                'severity': 'Severity',
                'category': 'Category',
                'rule': 'Rule',
                'source_ip': 'Source IP',
                'destination_ip': 'Destination IP'
            }
            search, filter_by, search_button, filter_time, start_time, end_time = design.search_controls(
                options,
                selected = 'severity' if severity is not None else 'all',
                value = str(severity) if severity is not None else ''
            )
            
            # Update the search inputs when a different filter is selected
            filter_by.on_value_change(
                lambda _: design.change_filter(search, filter_by, filter_time, options)
            )

            columns = [
                {'name': 'timestamp', 'label': 'Timestamp', 'field': 'timestamp'},
                {'name': 'severity', 'label': 'Severity', 'field': 'severity'},
                {'name': 'category', 'label': 'Category', 'field': 'category'},
                {'name': 'rule', 'label': 'Rule', 'field': 'alert_type'},
                {'name': 'source_ip', 'label': 'Source IP', 'field': 'source_ip'},
                {'name': 'destination_ip', 'label': 'Destination IP', 'field': 'destination_ip'}
            ]
            table = design.table(columns)

            # Get the current search filters and input values
            def get_filters():
                return (
                    filter_by.value,
                    search.value,
                    start_time.value,
                    end_time.value
                )
            load_alerts, apply_search = design.page_layout(table, search_alerts, get_filters)

            # Apply the search when the button or Enter key is pressed
            search_button.on_click(apply_search)
            search.on('keydown.enter', lambda _: apply_search())
            start_time.on('keydown.enter', lambda _: apply_search())
            end_time.on('keydown.enter', lambda _: apply_search())
            search.on_value_change(lambda e: apply_search() if not e.value else None)

            load_alerts()