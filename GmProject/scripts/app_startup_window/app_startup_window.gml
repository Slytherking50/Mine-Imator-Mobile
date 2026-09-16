/// app_startup_window()

function app_startup_window()
{
	globalvar window_list, window_debug_current;
	window_list = ds_list_create()
	window_debug_current = e_window.MAIN
	
	globalvar current_step, minute_steps, delta;
	current_step = 0
	minute_steps = 60 * 60
	delta = 1
	
	log("Windows startup")
	
	http_assets = null
	http_download_assets_file = null
	http_download_assets_zip = null
	http_alert_news = null
	http_downloadskin = null

	// Android auto-update (2026-09-15)
	http_check_update = null
	http_download_update = null
	
	window_width = 1
	window_height = 1
	window_set_focus()
	window_set_min_width(100)
	window_set_min_height(100)
	window_set_caption("Mine-imator")
	
	window_scroll_focus = ""
	window_scroll_focus_prev = ""
	window_state = ""
	window_busy = ""
	window_focus = ""
	
	mouse_cursor = cr_default
	mouse_current_x = 0
	mouse_current_y = 0
	mouse_previous_x = 0
	mouse_previous_y = 0
	mouse_move = 0
	mouse_still = 0
	mouse_wrap_x = 0
	mouse_wrap_y = 0
	mouse_click_timer = 0
	mouse_click_count = 0
	app_mouse_clear()
	
	dragger_drag_value = 0
	meter_drag_value = 0
	wheel_drag_value = 0
	wheel_drag_moon = false
	
	handle_drag_offset_x = 0
	handle_drag_offset_y = 0
	
	dragger_multiplier = 1
	dragger_snap = false
	
	sortlist_resize = null
	sortlist_resize_column = 0
	sortlist_resize_column_x = 0
	
	content_x = 0
	content_y = 0
	content_width = 0
	content_height = 0
	content_mouseon = false
	content_tab = null
	content_direction = null
	
	dx = 0
	dy = 0
	dw = 0
	dh = 0
	dx_start = 0
	dy_start = 0
	dw_start = 0
	dh_start = 0
	tab = null
	tab_control_h = 0
	tab_collapse = false
	
	tab_collumns = false
	tab_collumns_index = 0
	tab_collumns_width = 0
	tab_collumns_count = 2
	tab_collumns_start_x = 0
	
	// Tips
	tip_show = false
	tip_window = e_window.MAIN
	tip_alpha = 0
	tip_text = ""
	tip_text_wrap = ""
	tip_x = 0
	tip_y = 0
	tip_final_x = -1
	tip_final_y = -1
	tip_arrow_final_x = -1
	tip_arrow_final_y = -1
	tip_w = 0
	tip_h = 0
	tip_box_x = 0
	tip_box_y = 0
	tip_location_x = 0
	tip_location_y = 0
	tip_wrap = true
	tip_keybind_draw = false
	tip_arrow_x = 0
	tip_arrow_y = 0
	tip_arrow_xscale = 1
	tip_arrow_yscale = 1
	tip_arrow = 0
	tip_text_array = array()
	tip_force_right = false
	tip_right = false
	tip_keybind = null
	
	// Popups
	popup = null
	popup_ani = 0
	popup_block_ani = 0
	popup_block_ani_ease = "easeoutcirc"
	popup_ani_type = ""
	popup_switch_to = null
	popup_switch_from = null
	popup_mouseon = false

	// Place
	place_tl = null
	place_tl_render = true
	place_spawn = false
	place_view_pos = null
	place_view_mouse = null
	place_cam_work_from = vec3(0)
	place_cam_work_angle_look_xy = 0
	place_cam_work_angle_look_z = 0
	
	// Compact
	ui_large_height = 32
	ui_small_height = 24
	window_compact = false
	panel_compact = false

	// Virtual joystick (Android, Fase 4) - active-state fields, shared globally since only one
	// view can ever be mid-interaction at a time (window_busy is itself a single global state
	// machine). Screen position/radius used to live here too as bare globals, but that only
	// ever supported ONE view having a joystick - the split-view "Cámara activa" panel showed
	// no joystick at all when it was also in work-camera mode (2026-09-15 user report). Moved
	// to view_main.joystick_screen_x/y/radius and view_second.joystick_screen_x/y/radius
	// instead (app_startup_interface_views.gml), set every frame by view_draw.gml and read a
	// frame later by view_update.gml's hit-test (draw always runs after update, so "last
	// frame's position" is what's available there - the viewport practically never moves frame
	// to frame, a 1-frame-stale hit region is not perceptible).
	joystick_active = false
	joystick_knob_x = 0
	joystick_knob_y = 0
	joystick_alpha = 0.35
	joystick_slot = -1
	joystick_look_tracking = false
	joystick_look_prev_x = 0
	joystick_look_prev_y = 0

	// Virtual joystick (Android only, view_draw.gml/camera_control_move.gml) - WASD has no
	// touch equivalent (§6.4), this is the on-screen replacement for the work camera's free
	// movement while looking around with a one-finger drag at the same time.
	joystick_active = false
	joystick_knob_x = 0
	joystick_knob_y = 0
	joystick_alpha = 0.35

	// Android loading screen's own render+credit (window_draw_load_assets.gml, 2026-09-12) -
	// deliberately separate from load_assets_splash/load_assets_credits (the desktop dialog's
	// own splash, picked once in minecraft_assets_load_startup.gml at a different time for a
	// different screen) - explicit user request: this screen's render shouldn't depend on
	// that older variable/timing at all. Picked lazily, once, the first time this screen
	// actually draws (android_load_render == null guards it) rather than here at startup,
	// since irandom() needs randomize() to have already run (app_event_create.gml) and this
	// script runs earlier than that.
	android_load_render = null
	android_load_render_credit = ""

	// Android loading screen's own logo (window_draw_load_assets.gml, 2026-09-12 remake) -
	// replaces spr_load_assets (the shared desktop/Android placeholder clapperboard) on
	// this screen only, without touching spr_load_assets itself, which the desktop dialog
	// below in the same script still draws. Loaded lazily like android_load_render above -
	// no randomize() dependency here, but kept in the same lazy spot for consistency and
	// because file_exists_lib()/data_directory need data_directory_seed_android() to have
	// already run, which happens after this script too.
	android_load_logo = null

	// Set garbage collector
	gc_target_frame_time(0)
}
