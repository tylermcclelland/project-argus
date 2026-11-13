# Install dependencies before running:
# python3 -m pip install nicegui 

import simple
import advanced
import design
from nicegui import ui

@ui.page('/')
def main():
    design.apply_theme()
    state = {'page': 'Home', 'mode': 'Simple', 'severity': None}

    # Header
    with ui.header().classes('items-center px-5').style('background: #E4DCF4; color: #51476D'):
        ui.button(
            icon = 'menu', on_click = lambda: drawer.toggle()
        ).props('flat round color = primary')
        ui.label('Project Argus').classes('text-2xl font-bold')
        ui.space()

    # Sidebar
    with ui.left_drawer(value = False).classes('p-3') as drawer:
        # Switch pages and reset previously selected filters
        def navigate(page):
            state['page'] = page
            state['severity'] = None
            if page == 'Dashboard' and state['mode'] == 'Simple':
                simple.search_alerts.cache_clear()
            render.refresh()

        # Open the simple dashboard filtered to the selected severity from Home
        def navigate_severity(severity):
            state['page'] = 'Dashboard'
            state['severity'] = severity
            simple.search_alerts.cache_clear()
            render.refresh()

        ui.button(
            'Home', icon = 'home', on_click = lambda: navigate('Home')
        ).props('flat no-caps align = left').classes('w-full text-bold text-lg').style('color: #7764A6')
        
        ui.button(
            'Dashboard', icon = 'dashboard', on_click = lambda: navigate('Dashboard')
        ).props('flat no-caps align = left').classes('w-full text-bold text-lg').style('color: #7764A6')
        
        ui.separator().classes('my-4') 
        
        ui.label('Mode').classes('font-semibold').style('color: #7764A6')

        # Simple/Advanced mode switch
        with ui.row().classes('w-full items-center justify-center gap-2'):
            ui.label('Simple').classes('font-bold').style('color: #7764A6')
            switch_mode = ui.switch(value = False)
            switch_mode.props('color = primary')
            ui.label('Advanced').classes('font-bold').style('color: #7764A6')
        def change_mode(mode):
            state['mode'] = 'Advanced' if mode.value else 'Simple'
            state['severity'] = None
            render.refresh()
        switch_mode.on_value_change(change_mode)

    with ui.column().classes('w-full p-5'):
        # Display the Home or Dashboard page based on the selected mode
        @ui.refreshable
        def render():
            if state['page'] == 'Home':
                if state['mode'] == 'Simple':
                    simple.simple_home(navigate_severity)
                else:
                    advanced.advanced_home()
            elif state['page'] == 'Dashboard':
                if state['mode'] == 'Simple':
                    simple.simple_dashboard(state['severity'])
                else:
                    advanced.advanced_dashboard()
        render()

if __name__ in {'__main__', '__mp_main__'}:
    ui.run(title='Project Argus', reload = True)