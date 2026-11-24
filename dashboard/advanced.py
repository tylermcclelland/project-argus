# Install dependencies before running:
# python3 -m pip install nicegui 

from snowflake_database import get_snowflake_connection
import calendar
from datetime import datetime
from functools import lru_cache
from nicegui import app, ui
import design

# Get the current user's local timezone
def get_local_timezone():
    return app.storage.client['timezone']

# Count notices using selected filters and retrieve the first and last event times
def notice_activity(year = 'all', month = 'all', day = 'all', start_time = '', end_time = ''):
    timezone = get_local_timezone()
    conditions = []
    params = []

    # Apply date and time filters using the user's local timezone
    if year != 'all':
        conditions.append("TO_CHAR(local_time, 'YYYY') = %s")
        params.append(year)
    if month != 'all':
        conditions.append("TO_CHAR(local_time, 'MM') = %s")
        params.append(month)
    if day != 'all':
        conditions.append("TO_CHAR(local_time, 'DD') = %s")
        params.append(day)
    if start_time and end_time:
        conditions.append("TO_CHAR(local_time, 'HH24:MI') BETWEEN %s AND %s")
        params.extend([start_time, end_time])

    # Group notices by minute, day, month, or year based on the selected filters for the graph
    if day != 'all' or (start_time and end_time):
        period = 'YYYY-MM-DD HH24:MI'
        interval = 'Minute'
    elif month != 'all':
        period = 'YYYY-MM-DD'
        interval = 'Day'
    elif year != 'all':
        period = 'YYYY-MM'
        interval = 'Month'
    else:
        period = 'YYYY'
        interval = 'Year'

    # Count notices and retrieve the earliest and latest event timestamps
    where = f"WHERE {' AND '.join(conditions)}" if conditions else ''
    query = f'''
        WITH notices AS (
            SELECT
                CONVERT_TIMEZONE('UTC', %s, TO_TIMESTAMP_NTZ(timestamp::NUMBER(20,6))) AS local_time
            FROM ARGUS.PUBLIC.ZEEK_NOTICES
            WHERE timestamp IS NOT NULL
        )
        SELECT
            TO_CHAR(local_time, '{period}') AS period,
            COUNT(*) AS total_notices,
            TO_CHAR(MIN(local_time), 'YYYY-MM-DD HH24:MI:SS') AS first_notice,
            TO_CHAR(MAX(local_time), 'YYYY-MM-DD HH24:MI:SS') AS last_notice
        FROM notices
        {where}
        GROUP BY 1
        ORDER BY 1
    '''
    conn = get_snowflake_connection()
    cursor = conn.cursor()
    try:
        rows = cursor.execute(query, (timezone, *params)).fetchall()
    finally:
        cursor.close()
        conn.close()

    # Include minutes with no notices in the graph
    if year != 'all' and month != 'all' and day != 'all':
        selected_date = f'{year}-{month}-{day}'
        counts = {row[0]: row for row in rows}
        start_minute = 0
        end_minute = 1439
        if start_time and end_time:
            start_hour, start_min = map(int, start_time.split(':'))
            end_hour, end_min = map(int, end_time.split(':'))
            start_minute = start_hour * 60 + start_min
            end_minute = end_hour * 60 + end_min
        rows = [
            counts.get(
                f'{selected_date} {minute // 60:02d}:{minute % 60:02d}',
                (
                    f'{selected_date} {minute // 60:02d}:{minute % 60:02d}',
                    0, None, None
                )
            )
            for minute in range(start_minute, end_minute + 1)
        ]
    return rows, interval

# Count notices for each network protocol
@lru_cache(maxsize = 1)
def notice_protocols():
    conn = get_snowflake_connection()
    cursor = conn.cursor()
    rows = cursor.execute('''
        SELECT COALESCE(protocol, 'unknown') AS protocol,
               COUNT(*) AS total
        FROM ARGUS.PUBLIC.ZEEK_NOTICES
        GROUP BY protocol
        ORDER BY total DESC
    ''').fetchall()
    cursor.close()
    conn.close()
    return [(row[0], row[1]) for row in rows]

# Home page 
def advanced_home():
    timezone = get_local_timezone()
    protocols = notice_protocols()

    with ui.column().classes('w-full gap-4'):
        with ui.card().classes('card w-full p-5'):
            ui.label('Notice Activity').classes('w-full text-center text-xl font-semibold')

            # Get available years and the latest date from the database 
            conn = get_snowflake_connection()
            cursor = conn.cursor()
            try:
                available_years = [row[0] for row in cursor.execute('''
                    SELECT DISTINCT TO_CHAR(
                        CONVERT_TIMEZONE('UTC', %s, TO_TIMESTAMP_NTZ(timestamp::NUMBER(20,6))), 
                        'YYYY'
                    )
                    FROM ARGUS.PUBLIC.ZEEK_NOTICES
                    WHERE timestamp IS NOT NULL
                    ORDER BY 1
                ''', (timezone,)).fetchall()]
                latest_date = cursor.execute('''
                    SELECT TO_CHAR(
                        CONVERT_TIMEZONE('UTC', %s, TO_TIMESTAMP_NTZ(MAX(timestamp)::NUMBER(20,6))),
                        'YYYY-MM-DD'
                    )
                    FROM ARGUS.PUBLIC.ZEEK_NOTICES
                ''', (timezone,)).fetchone()[0]
            finally:
                cursor.close()
                conn.close()
            latest_year, latest_month, latest_day = (
                latest_date.split('-') if latest_date else ('all', 'all', 'all')
            )

            # Create date and time filters for the notice activity graph
            with ui.row().classes('w-full items-center flex-wrap gap-3'):
                year = ui.select({'all': 'All Years', **{y: y for y in available_years}},
                                 value = latest_year, label = 'Year').props('outlined dense').classes('w-40')
                month = ui.select({'all': 'All Months', **{f'{i:02d}': calendar.month_name[i] for i in range(1, 13)}},
                                  value = latest_month, label = 'Month').props('outlined dense').classes('w-44')
                day = ui.select({'all': 'All Dates', **{f'{i:02d}': str(i) for i in range(1, 32)}},
                                value = latest_day, label = 'Date (day)').props('outlined dense').classes('w-36')
                start_time = ui.input(label = 'From', placeholder = 'HH:MM').props('outlined dense').classes('w-32')
                end_time = ui.input(label ='To', placeholder = 'HH:MM').props('outlined dense').classes('w-32')
                apply_button = ui.button('Filter', icon = 'search')
                reset_button = ui.button('Reset').props('outline')

            # Set up the notice activity graph
            chart = design.graph([], '#AD8BD9')
            chart['xAxis']['type'] = 'category'
            chart['xAxis']['name'] = 'Time'
            chart['xAxis']['axisLabel'].pop(':formatter', None)
            chart['xAxis']['axisLabel']['rotate'] = 25
            chart['xAxis']['axisLabel']['interval'] = 59
            chart['xAxis']['axisLabel'][':formatter'] = """
                (value) => value.length > 10 ? value.slice(11, 16) : value
            """
            chart['xAxis']['nameGap'] = 55
            chart['grid']['bottom'] = 85
            chart['yAxis']['name'] = 'Notices'
            chart['series'][0]['type'] = 'line'
            chart['series'][0]['smooth'] = True
            chart['series'][0]['showSymbol'] = False  
            chart['series'][0]['areaStyle'] = {
                'color': '#AD8BD9',
                'opacity': 0.35
            }
            # Show notice counts and first/last event times when hovering over the graph
            chart['tooltip'][':formatter'] = """
                (params) => {
                    const point = params[0];
                    const data = point.data;
                    let tooltip = `${point.axisValue}<br/>
                        ${point.marker} Notices: ${Number(data.value).toLocaleString()}`;
                    if (data.first && data.last) {
                        tooltip += `<br/>First notice: ${data.first}`;
                        tooltip += `<br/>Last notice: ${data.last}`;
                    }
                    return tooltip;
                }
            """
            activity_chart = ui.echart(chart).classes('w-full').style('height: 350px')
            empty_label = ui.label('No notices match these filters.').classes('text-sm text-slate-500')

            # Apply the selected date and time filters to the graph
            def apply_filters():
                start = (start_time.value or '').strip()
                end = (end_time.value or '').strip()
                if bool(start) != bool(end):
                    ui.notify('Fill out both From and To.', type='warning')
                    return
                try:
                    if start:
                        start = datetime.strptime(start, '%H:%M').strftime('%H:%M')
                        end = datetime.strptime(end, '%H:%M').strftime('%H:%M')
                except ValueError:
                    ui.notify('Time must use HH:MM.', type='warning')
                    return
                if start and start > end:
                    ui.notify('No data found.', type='warning')
                    activity_chart.options['xAxis']['data'] = []
                    activity_chart.options['series'][0]['data'] = []
                    activity_chart.update()
                    empty_label.set_visibility(True)
                    return

                rows, interval = notice_activity(year.value, month.value, day.value, start, end)
                activity_chart.options['xAxis']['data'] = [row[0] for row in rows]
                # Adjust the number of time labels based on the selected range
                activity_chart.options['xAxis']['axisLabel']['interval'] = max(0, (len(rows) + 23) // 24 - 1)
                activity_chart.options['xAxis']['name'] = f'Time ({interval})'
                activity_chart.options['series'][0]['data'] = [
                    {
                        'value': row[1],
                        'first': row[2],
                        'last': row[3]
                    }
                    for row in rows
                ]
                activity_chart.update()
                empty_label.set_visibility(not rows or all(row[1] == 0 for row in rows))
            
            # Reset the filters to the latest date
            def reset_filters():
                year.value = latest_year
                month.value = latest_month
                day.value = latest_day
                start_time.value = ''
                end_time.value = ''
                apply_filters()

            apply_button.on_click(apply_filters)
            reset_button.on_click(reset_filters)
            start_time.on('keydown.enter', lambda _: apply_filters())
            end_time.on('keydown.enter', lambda _: apply_filters())
            apply_filters()
        
        # Display the number of notices for each network protocol
        with ui.card().classes('card w-full p-5'):
            ui.label('Protocol Types').classes('w-full text-xl font-semibold text-center')
            ui.echart({
                'color': ['#F2B88D', '#F4DF94'],
                'tooltip': {'trigger': 'item'},
                'series': [{
                    'type': 'pie',
                    'radius': ['45%', '70%'],
                    'center': ['50%', '58%'],
                    'data': [
                        {'name': protocol.upper(), 'value': total}
                        for protocol, total in protocols
                    ]
                }]
            }).classes('w-full').style('height: 260px')

# Search notices with filters
def search_notices(filter_by, search, start_time, end_time, page = 0):
    timezone = get_local_timezone()
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
        
    # Filter notices based on the selected search option
    if filter_by == 'time':
        conditions.append("TO_CHAR(local_time, 'HH24:MI') BETWEEN %s AND %s")
        params.extend([start_time, end_time])
    elif search:
        if filter_by == 'all':
            conditions.append('''(
                TO_CHAR(local_time, 'YYYY-MM-DD HH24:MI:SS') LIKE %s
                OR CAST(notice_type AS VARCHAR) LIKE %s
                OR CAST(source_ip AS VARCHAR) LIKE %s
                OR CAST(source_port AS VARCHAR) LIKE %s
                OR CAST(destination_ip AS VARCHAR) LIKE %s
                OR CAST(destination_port AS VARCHAR) LIKE %s
                OR CAST(protocol AS VARCHAR) LIKE %s
            )''')
            params.extend([f'%{search}%'] * 7)
        elif filter_by == 'date':
            conditions.append("TO_CHAR(local_time, 'YYYY-MM-DD') = %s")
            params.append(search)
        elif filter_by == 'year':
            conditions.append("TO_CHAR(local_time, 'YYYY') = %s")
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
            conditions.append("TO_CHAR(local_time, 'MM') = %s")
            params.append(f'{month:02d}')
        else:
            fields = {
                'notice_type': 'notice_type',
                'source_ip': 'source_ip',
                'source_port': 'source_port',
                'destination_ip': 'destination_ip',
                'destination_port': 'destination_port',
                'protocol': 'protocol'
            }
            column = fields[filter_by]
            conditions.append(f'CAST({column} AS VARCHAR) LIKE %s')
            params.append(f'%{search}%')

    where = f"WHERE {' AND '.join(conditions)}" if conditions else ''
    query = f'''
        WITH notices AS (
            SELECT
                timestamp, notice_type, source_ip, source_port,
                destination_ip, destination_port, protocol, message, uid,
                CONVERT_TIMEZONE('UTC', %s, TO_TIMESTAMP_NTZ(timestamp::NUMBER(20,6))) AS local_time
            FROM ARGUS.PUBLIC.ZEEK_NOTICES
            WHERE timestamp IS NOT NULL
        )
        SELECT
            TO_CHAR(local_time, 'YYYY-MM-DD HH24:MI:SS') AS timestamp,
            notice_type, source_ip, source_port,
            destination_ip, destination_port, protocol, message, uid
        FROM notices
        {where}
        ORDER BY local_time DESC, uid, notice_type, source_ip, destination_ip
        LIMIT %s OFFSET %s
    '''
    
    # Retrieve up to 50 notices per page and check for more results
    params.extend([limit + 1, page * limit])
    conn = get_snowflake_connection()
    cursor = conn.cursor()
    try:
        results = cursor.execute(query, (timezone, *params)).fetchall()
    finally:
        cursor.close()
        conn.close()
    # Convert Snowflake results into dictionaries and assign temporary row IDs
    columns = [
        'timestamp', 'notice_type', 'source_ip', 'source_port',
        'destination_ip', 'destination_port', 'protocol', 'message', 'uid'
    ]
    notices = []
    for index, row in enumerate(results[:limit]):
        notice = dict(zip(columns, row))
        notice['id'] = page * limit + index
        notices.append(notice)
    next_page = len(results) > limit
    return notices, next_page

# Advanced dashboard layout 
def advanced_dashboard():
    with ui.column().classes('w-full gap-4'):
        ui.label('Security Notices').classes('text-xl font-bold').style('color: #7764A6')
        with ui.card().classes('card w-full p-5'):

            # Create search controls with specific filters
            options = {
                'all': 'All',
                'time': 'Time',
                'date': 'Date',
                'year': 'Year',
                'month': 'Month',
                'notice_type': 'Notice Type',
                'source_ip': 'Source IP',
                'source_port': 'Source Port',
                'destination_ip': 'Destination IP',
                'destination_port': 'Destination Port',
                'protocol': 'Protocol'
            }
            search, filter_by, search_button, filter_time, start_time, end_time = design.search_controls(options)

            # Update the search inputs when a different filter is selected
            filter_by.on_value_change(
                lambda _: design.change_filter(search, filter_by, filter_time, options)
            )

            columns = [
                {'name': 'timestamp', 'label': 'Timestamp', 'field': 'timestamp', 'align': 'left'},
                {'name': 'notice_type', 'label': 'Notice Type', 'field': 'notice_type', 'align': 'left'},
                {'name': 'source_ip', 'label': 'Source IP', 'field': 'source_ip', 'align': 'left'},
                {'name': 'source_port', 'label': 'Source Port', 'field': 'source_port'},
                {'name': 'destination_ip', 'label': 'Destination IP', 'field': 'destination_ip', 'align': 'left'},
                {'name': 'destination_port', 'label': 'Destination Port', 'field': 'destination_port'},
                {'name': 'protocol', 'label': 'Protocol', 'field': 'protocol'}
            ]
            table = design.table(columns)

            # Display more details of the notice when it is clicked
            def show_details(row):
                with ui.dialog() as dialog, ui.card().classes('w-full').style('min-width: min(90vw, 550px)'):
                    ui.label('Notice Details').classes('text-lg font-bold')
                    for label, key in [
                        ('Connection UID', 'uid'),
                        ('Message', 'message')
                    ]:
                        value = row.get(key)
                        ui.label(f'{label}: {value if value is not None else ""}').classes('break-all')
                    ui.button('Close', on_click = dialog.close).props('flat')
                dialog.open()
            table.on('rowClick', lambda e: show_details(e.args[1]))

            # Get the current search filters and input values
            def get_filters():
                return (
                    filter_by.value,
                    search.value,
                    start_time.value,
                    end_time.value
                )
            load_notices, apply_search = design.page_layout(table, search_notices, get_filters)

            # Apply the search when the button or Enter key is pressed
            search_button.on_click(apply_search)
            search.on('keydown.enter', lambda _: apply_search())
            start_time.on('keydown.enter', lambda _: apply_search())
            end_time.on('keydown.enter', lambda _: apply_search())
            search.on_value_change(lambda e: apply_search() if not e.value else None)

            load_notices()