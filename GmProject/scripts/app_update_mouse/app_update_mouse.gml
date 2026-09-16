/// app_update_mouse()

function app_update_mouse()
{
	window_set_cursor(mouse_cursor)
	
	mouse_cursor = cr_default
	mouse_previous_x = mouse_current_x
	mouse_previous_y = mouse_current_y
	mouse_current_x = mouse_x
	mouse_current_y = mouse_y
	mouse_dx = mouse_x - mouse_previous_x
	mouse_dy = mouse_y - mouse_previous_y
	mouse_left_pressed = (!mouse_left && mouse_check_button(mb_left))
	mouse_left_released = (mouse_left && !mouse_check_button(mb_left))
	mouse_left = mouse_check_button(mb_left)
	mouse_right_pressed = (!mouse_right && mouse_check_button(mb_right))
	mouse_right_released = (mouse_right && !mouse_check_button(mb_right))
	mouse_right = mouse_check_button(mb_right)
	mouse_middle_pressed = (!mouse_middle && mouse_check_button(mb_middle))
	mouse_middle = mouse_check_button(mb_middle)
	mouse_wheel = mouse_wheel_down() - mouse_wheel_up()
	
	if (mouse_left_pressed)
	{
		mouse_click_x = mouse_x
		mouse_click_y = mouse_y
	}
	else if (mouse_left)
		mouse_move = max(abs(mouse_x - mouse_click_x), abs(mouse_y - mouse_click_y))
	else
		mouse_move = 0
	
	if (mouse_previous_x != mouse_x || mouse_previous_y != mouse_y)
		mouse_still = 0
	else
		mouse_still++
	
	if (mouse_left_released || mouse_right_released)
	{
		mouse_wrap_x = 0
		mouse_wrap_y = 0
	}
	
	window_scroll_focus_prev = window_scroll_focus
	window_scroll_focus = ""
	
	#region Double click
	
	if (mouse_still = 0)
	{
		mouse_click_count = 0
		mouse_click_timer = 0
	}
	
	if (mouse_click_count = 1)
	{
		mouse_click_timer += (1/fps) * 1000
		
		if (mouse_click_timer < 500 && mouse_left_pressed)
			mouse_click_count++
		
		if (mouse_click_timer >= 500)
		{
			mouse_click_count = 0
			mouse_click_timer = 0
		}
	}
	
	if (mouse_click_count >= 2 && mouse_left_pressed)
		mouse_left_double_pressed = true
	else
		mouse_left_double_pressed = false
	
	if (mouse_click_count >= 2 && mouse_left_released)
	{
		mouse_click_count = 0
		mouse_click_timer = 0
	}
	
	if (mouse_left_pressed && mouse_click_count = 0)
		mouse_click_count++

	#endregion

	#region Long press

	// Touch equivalent of right-click (CLAUDE.md §6.4/§17, Fase 3) - context_menu_area.gml
	// is the single shared entry point for right-click across 5 primitives + the focused
	// textbox, so this one addition covers all of them at once. mouse_move (computed above)
	// is the same "distance since press" signal view_update.gml already uses to tell a
	// click from a drag - reused here so a long-press cancels (resets, not permanently) if
	// the touch turns into an actual drag (dragger scrub, wheel rotate, etc.) instead of a
	// hold. Edge-triggered like mouse_right_pressed: true for exactly one frame per press.
	if (mouse_left_pressed)
	{
		mouse_long_press_timer = 0
		mouse_long_press_fired = false
	}
	else if (mouse_left && !mouse_long_press_fired)
	{
		if (mouse_move <= 5)
			mouse_long_press_timer += (1/fps) * 1000
		else
			mouse_long_press_timer = 0
	}

	mouse_long_press_pressed = (mouse_left && !mouse_long_press_fired && mouse_long_press_timer >= 500)
	mouse_long_press_fired = (mouse_long_press_fired || mouse_long_press_pressed)

	#endregion
}
