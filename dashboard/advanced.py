# Install dependencies before running:
# python3 -m pip install nicegui 

from pathlib import Path
import sqlite3
import calendar
from datetime import datetime
from functools import lru_cache
from nicegui import ui
import design

DB_PATH = Path(__file__).parent / "zeek.db"

# Count notices using selected filters and retrieve the first and last event times
@lru_cache(maxsize = 128)
def notice_activity(year = 'all', month = 'all', day = 'all', start_time = '', end_time = ''):
    conditions = []
    params = []

    # Apply date and time filters to the Unix timestamps using local time
    if year != 'all':
        conditions.append("strftime('%Y', timestamp, 'unixepoch', 'localtime') = ?")
        params.append(year)
    if month != 'all':
        conditions.append("strftime('%m', timestamp, 'unixepoch', 'localtime') = ?")
        params.append(month)
    if day != 'all':
        conditions.append("strftime('%d', timestamp, 'unixepoch', 'localtime') = ?")
        params.append(day)
    if start_time and end_time:
        conditions.append("strftime('%H:%M', timestamp, 'unixepoch', 'localtime') BETWEEN ? AND ?")
        params.extend([start_time, end_time])

    # Group notices by minute, day, month, or year based on the selected filters for the graph
    if day != 'all' or (start_time and end_time):
        period = '%Y-%m-%d %H:%M'
        interval = 'Minute'
    elif month != 'all':
        period = '%Y-%m-%d'
        interval = 'Day'
    elif year != 'all':
        period = '%Y-%m'
        interval = 'Month'
    else:
        period = '%Y'
        interval = 'Year'

    where = f"WHERE {' AND '.join(conditions)}" if conditions else ''
    # Count notices and retrieve the earliest and latest event timestamps
    with sqlite3.connect(DB_PATH) as conn:
        rows = conn.execute(f'''
            SELECT
                strftime('{period}', timestamp, 'unixepoch', 'localtime') AS period,
                COUNT(*) AS total_notices,
                strftime('%Y-%m-%d %H:%M:%S', MIN(timestamp), 'unixepoch', 'localtime') AS first_notice,
                strftime('%Y-%m-%d %H:%M:%S', MAX(timestamp), 'unixepoch', 'localtime') AS last_notice
            FROM zeek_notices
            {where}
            GROUP BY period
            ORDER BY period
        ''', params).fetchall()

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
    with sqlite3.connect(DB_PATH) as conn:
        rows = conn.execute('''
            SELECT COALESCE(protocol, 'unknown') AS protocol,
                   COUNT(*) AS total
            FROM zeek_notices
            GROUP BY protocol
            ORDER BY total DESC
        ''').fetchall()
        return [(row[0], row[1]) for row in rows]
    
# Display timestamps using the local timezone.
def timestamp_text(value):
    if value is None:
        return ''
    return datetime.fromtimestamp(value).strftime('%Y-%m-%d %H:%M:%S')

# Home page 
def advanced_home():
    protocols = notice_protocols()

    with ui.column().classes('w-full gap-4'):
        with ui.card().classes('card w-full p-5'):
            ui.label('Notice Activity').classes('w-full text-center text-xl font-semibold')

            # Get available years and the latest date from the database 
            with sqlite3.connect(DB_PATH) as conn:
                available_years = [row[0] for row in conn.execute('''
                    SELECT DISTINCT strftime('%Y', timestamp, 'unixepoch', 'localtime')
                    FROM zeek_notices WHERE timestamp IS NOT NULL
                    ORDER BY 1
                ''').fetchall()]
                latest_date = conn.execute('''
                    SELECT strftime('%Y-%m-%d', MAX(timestamp), 'unixepoch', 'localtime')
                    FROM zeek_notices
                ''').fetchone()[0]
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
                (value) => value.slice(11, 16)
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
        conditions.append("strftime('%H:%M', timestamp, 'unixepoch', 'localtime') BETWEEN ? AND ?")
        params.extend([start_time, end_time])
    elif search:
        if filter_by == 'all':
            conditions.append('''(
                strftime('%Y-%m-%d %H:%M:%S', timestamp, 'unixepoch', 'localtime') LIKE ?
                OR CAST(notice_type AS TEXT) LIKE ?
                OR CAST(source_ip AS TEXT) LIKE ?
                OR CAST(source_port AS TEXT) LIKE ?
                OR CAST(destination_ip AS TEXT) LIKE ?
                OR CAST(destination_port AS TEXT) LIKE ?
                OR CAST(protocol AS TEXT) LIKE ?
            )''')
            params.extend([f'%{search}%'] * 7)
        elif filter_by == 'date':
            conditions.append("strftime('%Y-%m-%d', timestamp, 'unixepoch', 'localtime') = ?")
            params.append(search)
        elif filter_by == 'year':
            conditions.append("strftime('%Y', timestamp, 'unixepoch', 'localtime') = ?")
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
            conditions.append("strftime('%m', timestamp, 'unixepoch', 'localtime') = ?")
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
            conditions.append(f'CAST({column} AS TEXT) LIKE ?')
            params.append(f'%{search}%')

    where = f"WHERE {' AND '.join(conditions)}" if conditions else ''
    query = f'''
        SELECT
            id, timestamp, notice_type, source_ip, source_port,
            destination_ip, destination_port, protocol, message, uid
        FROM zeek_notices
        {where}
        ORDER BY timestamp DESC, id DESC
        LIMIT ? OFFSET ?
    '''
    
    # Retrieve up to 50 notices per page and check for more results
    params.extend([limit + 1, page * limit])
    with sqlite3.connect(DB_PATH) as conn:
        conn.row_factory = sqlite3.Row
        results = conn.execute(query, params).fetchall()
    
    # Format notice timestamps for the dashboard table
    notices = []
    for row in results[:limit]:
        notice = dict(row)
        notice['timestamp'] = timestamp_text(notice['timestamp'])
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