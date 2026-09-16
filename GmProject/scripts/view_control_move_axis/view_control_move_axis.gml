/// view_control_move_axis(view, control, valueid, color, start, end, [fade])
/// @arg view
/// @arg control
/// @arg valueid
/// @arg color
/// @arg start
/// @arg end
/// @arg [fade]

function view_control_move_axis(view, control, vid, color, start3D, end3D, fade = true)
{
	var center3D, center2D;
	
	center3D = tl_edit.world_pos
	
	// Convert to screen
	center2D = view_shape_project(center3D)
	if (point3D_project_error)
		return 0
	
	var start2D;
	
	start2D = view_shape_project(start3D)
	if (point3D_project_error)
		return 0
	
	var end2D;
	
	end2D = view_shape_project(end3D)
	if (point3D_project_error)
		return 0
	
	var alpha = fade ? percent(abs(vec3_dot(vec3_normalize(vec3_sub(end3D, center3D)), vec3_normalize(vec3_sub(cam_from, center3D)))), .975, .95) : 1;
	
	if ((window_busy = "rendercontrol" && view_control_edit = control) || view.control_mouseon_last = control || !setting_fade_gizmos)
		alpha = 1
	
	if (alpha = 0)
		return 0
	
	draw_set_alpha(alpha)
	
	// Check state
	if (window_busy = "rendercontrol")
	{
		if (view_control_edit != control || view_control_edit_view != view)
		{
			draw_set_color(c_white)
			draw_set_alpha(1)
			return 0
		}
		
		// Update dragging
		view_control_vec = point2D_sub(end2D, center2D)
		draw_set_color(c_white)
	}
	// Android OR-fallback (Fase 4): control_mouseon_last is only correct here because it
	// was written by THIS SAME function's own "Check mouse" block (below, line ~110) one
	// frame in the past - a continuously-updating mouse cursor makes that 1-frame lag
	// invisible, but a touch tap delivers press+position together, so the position may
	// never have been "hovered" on a prior frame at all. Duplicating the exact same
	// point_line_distance check here, using start2D/end2D already computed above (lines
	// 21-29, before this block), lets Android grab on the SAME frame as the tap - no
	// dependency on Qt's touch-to-mouse event ordering either way (unverified on device,
	// see research/2026-09-15-fase4-timeline-gizmos-inventory.md). Desktop's own path
	// (control_mouseon_last) is untouched.
	else if (view.control_mouseon_last = control || (platform_get() == e_platform.ANDROID && place_tl = null && content_mouseon && point_line_distance(start2D[X], start2D[Y], end2D[X], end2D[Y], mouse_x - content_x, mouse_y - content_y) < view_3d_control_width / 2))
	{
		// Left click
		if (mouse_left_pressed)
		{
			window_busy = "rendercontrol"
			view_control_edit = control
			view_control_edit_view = view
			
			if (vid <= Z)
				view_control_flip = view_control_move_flip_axis[vid]
			
			if (control = e_view_control.ROT_DISTANCE)
				view_control_value = tl_edit.value[e_value.CAM_ROTATE_DISTANCE]
			else
				view_control_value = point3D(tl_edit.value[e_value.POS_X], tl_edit.value[e_value.POS_Y], tl_edit.value[e_value.POS_Z])
			
			view_control_vec = point2D_sub(end2D, center2D)
			view_control_move_distance = 0
		}
		
		// Right click
		if (mouse_right_pressed && keyboard_check(vk_shift))
		{
			if (control = e_view_control.ROT_DISTANCE)
			{
				action_tl_frame_cam_rotate_distance(tl_edit.value_default[vid], false)
			}
			else
			{
				axis_edit = vid
				action_tl_frame_pos(tl_edit.value_default[vid], false)
			}
			
			app_mouse_clear()
		}
		
		draw_set_color(c_white)
	}
	else
		draw_set_color(color)
	
	// Line
	view_shape_line_draw(start2D, end2D)
	
	var rotation;
	rotation = point3D_angle(start3D, end3D)
	
	// Arrow
	var size = (point3D_distance(cam_from, control = e_view_control.ROT_DISTANCE ? tl_edit.world_pos_rotate : center3D) * view_3d_control_size) * .05 * view_control_ratio;
	view_shape_cone_draw(MAT_IDENTITY, end3D, rotation, size)
	
	// Check mouse
	if (place_tl = null && content_mouseon && point_line_distance(start2D[X], start2D[Y], end2D[X], end2D[Y], mouse_x - content_x, mouse_y - content_y) < view_3d_control_width / 2)
		view.control_mouseon = control
	
	draw_set_color(c_white)
	draw_set_alpha(1)
}
