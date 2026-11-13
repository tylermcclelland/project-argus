# Install dependencies before running:
# python3 -m pip install nicegui 

from nicegui import ui
from datetime import datetime

# Theme design for the dashboards 
def apply_theme():
    ui.colors(primary = '#9A87C4')
    ui.add_css('''
        body {
            background: #F7F5FC;
            color: #414159;
        }
        .card {
            background: white;
            border: 1px solid #E8E3F2;
        }
        .q-drawer {
            background: #EAE5F7;
        }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(min(100%, 215px), 1fr));
            gap: 15px;
        }
        .q-table thead th {
            text-align: center !important;
        }
        .q-table tbody td {
            text-align: left !important;
        }
        .q-table tbody td:nth-child(2) {
            text-align: center !important;
        }
    ''')

# Semicircle severity gauge for the simple mode Home page 
def gauge(percentage, color):
    return {
        'series': [{
            'type': 'gauge',
            'startAngle': 180,
            'endAngle': 0,
            'min': 0,
            'max': 100,
            'center': ['50%', '80%'],
            'radius': '95%',
            'progress': {
                'show': True,
                'width': 15,
                'itemStyle': {'color': color}
            },
            'pointer': {'show': False},
            'axisLine': {
                'lineStyle': {
                    'width': 15,
                    'color': [[1, '#EEE8F4']]
                }
            },
            'axisTick': {'show': False},
            'splitLine': {'show': False},
            'axisLabel': {'show': False},
            'detail': {'show': False},
            'data': [{'value': percentage}]
        }]
    }

# Activity graph designs
def graph(rows, color):
    return {
        'animation': False,
        'tooltip': {
            'trigger': 'axis',
            ':formatter': '''
                (params) => {
                    const point = params[0];
                    const timestamp = point.value[0].replace('T', ' ');
                    const count = point.value[1].toLocaleString();

                    return `${timestamp}<br/>${point.marker} Alerts: ${count}`;
                }
            '''
        },
        'grid': {'left': 40, 'right': 40, 'top': 25, 'bottom': 40}, 
        'xAxis': {
            'type': 'time',
            'name': 'Time (min)',
            'nameLocation': 'middle',
            'nameTextStyle': {'color': '#796E91'},
            'axisLabel': {
                'color': '#796E91',
                'hideOverlap': True,
                ':formatter': '''
                    (value) => {
                        const date = new Date(value);
                        return date.toLocaleTimeString('en-US', {
                            hour: '2-digit',
                            minute: '2-digit',
                            hour12: false
                        });
                    }
                '''
            },
            'axisPointer': {
                'lineStyle': {'color': '#AD8BD9'}
            }
        },
        'yAxis': {
            'type': 'value',
            'name': 'Alerts Per Min',
            'nameTextStyle': {'color': '#796E91'},
            'axisLabel': {'color': '#796E91'}
        },
        'series': [{
            'data': rows,
            'type': 'line',
            'smooth': True,
            'showSymbol': False,
            'lineStyle': {'color': color},
            'itemStyle': {'color': color},
            'areaStyle': {
                'color': color,
                'opacity': 0.35
            }
        }]
    }

# Create a clickable severity card that opens the filtered simple dashboard
def severity_card(title, count, total, color, severity, on_click):
    percentage = (count / total * 100) if total > 0 else 0
    with ui.card().classes('card w-full h-64 p-4 items-center justify-center cursor-pointer').on('click', lambda: on_click(severity)):
        ui.label(title).classes('text-lg font-semibold')
        ui.echart(gauge(percentage, color)).classes('w-full min-w-0').style('height: 110px')
        ui.label(f'{count:,} alerts').classes('text-xl font-bold')
        ui.label(f'{percentage:.1f}% of total').classes('text-sm text-slate-500')

# Create search controls with customizable filters and default values
def search_controls(options, selected = 'all', value = ''):
    with ui.row().classes('w-full items-center flex-wrap gap-3'):
        search = ui.input(
            placeholder = 'Search',
            value = value
        ).props('outlined dense clearable').classes('flex-1 min-w-48')
        with ui.row().classes('flex-1 items-center gap-3 min-w-0') as filter_time:
            ui.label('From:')
            start_time = ui.input(placeholder = 'HH:MM').props('outlined dense').classes('flex-1 min-w-0')
            ui.label('To:')
            end_time = ui.input(placeholder = 'HH:MM').props('outlined dense').classes('flex-1 min-w-0')
        filter_time.set_visibility(False)
        filter_by = ui.select(
            options,
            value = selected
        ).props('outlined dense').classes('w-44')
        search_button = ui.button('Search', icon = 'search')
    return search, filter_by, search_button, filter_time, start_time, end_time

# Show From/To inputs only when searching by time.
def change_filter(search, filter_by, filter_time, options):
    selected = filter_by.value
    is_time = selected == 'time'
    search.set_visibility(not is_time)
    filter_time.set_visibility(is_time)
    if not is_time:
        placeholder = (
            'Search' if selected == 'all'
            else 'Search by YYYY-MM-DD' if selected == 'date'
            else f'Search by {options[selected]}'
        )
        search.props(f'placeholder="{placeholder}"')

# Create a table with customizable columns
def table(columns):
    return ui.table(
        columns = columns,
        rows = [],
        row_key = 'id',
        pagination = {'rowsPerPage': 0}
    ).classes('w-full').props('flat')

# Create previous and next buttons 
def buttons(previous, next):
    with ui.row().classes('w-full items-center gap-3'):
        prev_page = ui.button('Previous', on_click = previous).props('outline')
        next_page = ui.button('Next', on_click = next).props('outline')
    return prev_page, next_page

# Handle page layout
def page_layout(table, search, get_filters):
    state = {'page': 0}

    # Load matching records and update the previous and next buttons 
    def load():
        filters = get_filters()
        if filters[0] == 'time' and (not filters[2] or not filters[3]):
            table.update_rows([])
            prev_button.set_enabled(False)
            next_button.set_enabled(False)
            return
        rows, has_next = search(*filters, state['page'])
        table.update_rows(rows)
        prev_button.set_enabled(state['page'] > 0)
        next_button.set_enabled(has_next)

    # Return to the first page when a new search is applied
    def apply_search():
        state['page'] = 0
        load()

    # Go to the previous page of search results
    def prev_page():
        if state['page'] > 0:
            state['page'] -= 1
            load()

    # Go to the next page of search results
    def next_page():
        state['page'] += 1
        load()

    prev_button, next_button = buttons(prev_page, next_page)
    return load, apply_search

# Format From and To inputs as HH:MM for accurate time filtering
def format_time(start_time, end_time):
    try:
        start_time = datetime.strptime(start_time, '%H:%M').strftime('%H:%M')
        end_time = datetime.strptime(end_time, '%H:%M').strftime('%H:%M')
    except (ValueError, TypeError):
        return None
    if start_time > end_time:
        return None
    return start_time, end_time