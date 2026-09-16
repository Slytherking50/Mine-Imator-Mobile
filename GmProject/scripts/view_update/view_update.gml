/// view_update(view, camera)
/// @arg view
/// @arg camera

function view_update(view, cam)
{
	var editcamobj = false;
	
	// Camera object disabled while placing or object locked
	if (cam)
		editcamobj = (place_tl = null && !cam.lock)
		
	// Surface
	view_update_surface(view, cam)

	// Virtual joystick + simultaneous look (Fase 4) - WASD (camera_control_move.gml,
	// keybinds CAM_FORWARD/BACK/LEFT/RIGHT) has no touch equivalent (§6.4) for the work
	// camera's free-fly movement. Placed here, BEFORE the "Click" block below, on purpose:
	// that block claims window_busy="viewclick" for any press anywhere in the viewport the
	// instant it happens, and view_update() always runs before view_draw() each frame - the
	// joystick used to live only in view_draw.gml's draw-phase code, so it always lost that
	// race for the exact same touch, which is why it activated inconsistently on a real
	// device ("cuesta que se logre activar"). view.joystick_screen_x/y/radius come from
	// view_draw.gml one frame stale (app_startup_interface_views.gml) - close enough since the
	// viewport doesn't move frame to frame. Per-view, not a bare global, since 2026-09-15 -
	// the split-view second panel needs its own joystick box too when it's also showing the
	// work camera (see the matching comment in view_draw.gml).
	// (!cam || editcamobj): work camera OR a real, editable camera object - matches
	// camera_control_move.gml's own two branches (2026-09-15, "creé una cámara y no aparece
	// el joystick" - it only ever handled the work camera before, same gap right-click-drag
	// fly-navigation doesn't have on desktop since camera_control_move.gml has a real-camera
	// branch too).
	if (platform_get() == e_platform.ANDROID && (!cam || editcamobj) && view.joystick_screen_radius > 0)
	{
		var jx, jy, jr;
		jx = view.joystick_screen_x
		jy = view.joystick_screen_y
		jr = view.joystick_screen_radius

		if (window_busy = "" && view.mouseon && !popup_mouseon && !toast_mouseon && !context_menu_mouseon)
		{
			if (touch_point_active(0) && point_distance(jx, jy, touch_point_x(0), touch_point_y(0)) <= jr)
			{
				window_busy = "joystick"
				window_focus = string(view)
				joystick_slot = 0
				joystick_active = true
			}
			else if (touch_point_active(1) && point_distance(jx, jy, touch_point_x(1), touch_point_y(1)) <= jr)
			{
				window_busy = "joystick"
				window_focus = string(view)
				joystick_slot = 1
				joystick_active = true
			}
		}

		// window_focus check: without it, once one view claims window_busy="joystick" this
		// frame, the OTHER view's own call to view_update() later this same frame would also
		// see window_busy="joystick" (a single global state machine) and re-run the movement
		// math below against ITS OWN jx/jy - double-processing one touch through two different
		// joystick boxes (2026-09-15, alongside the split-view joystick fix above).
		if (window_busy = "joystick" && window_focus = string(view))
		{
			// !mouse_left is a defensive second release condition, not just
			// !touch_point_active(joystick_slot) alone - if Android/Qt ever fails to deliver
			// a clean per-finger release for the raw touch slot (a device/timing quirk this
			// session couldn't fully pin down without more logging), the joystick got stuck
			// "on" forever (reported on real device, 2026-09-11: "se queda pegado", camera
			// unmovable afterward, and a stale slot index got silently reused by the NEXT
			// unrelated touch anywhere on screen, making the knob jump there instead).
			// mouse_left going false is the same reliable "nothing is touching the screen
			// anymore" signal the already-proven single-finger drag path depends on -
			// guaranteed to catch a release even if the raw-touch path doesn't.
			if (!touch_point_active(joystick_slot) || !mouse_left)
			{
				window_busy = ""
				joystick_active = false
				joystick_knob_x = 0
				joystick_knob_y = 0
				joystick_look_tracking = false
			}
			else
			{
				var dx, dy, dist, fx, fy;

				// Qt/Android only keeps delivering QTouchEvent updates for a finger once
				// 2+ are down at once - a lone finger's TouchBegin is left unaccepted
				// here (AppWindow::event()) so the already-proven single-finger
				// mouse-synthesis path (camera drag) keeps working, and Qt's own rule is
				// that an unaccepted TouchBegin gets no further TouchUpdate/TouchEnd for
				// that point. That's what froze touch_point_x/y(joystick_slot) at the
				// initial contact position ("se queda pegado", confirmed on device
				// 2026-09-11) whenever the joystick finger was alone - only mouse_x/y
				// (synthesized from that same lone finger) kept tracking it. Once a 2nd
				// finger joins, Qt does deliver real touch updates (confirmed on device:
				// joystick "funciona fluido" as soon as a look finger touches down), and
				// mouse_x/y is the one that goes stale then (see lookslot comment below)
				// - so pick whichever source is actually live for the current finger count.
				if (touch_count() >= 2)
				{
					fx = touch_point_x(joystick_slot)
					fy = touch_point_y(joystick_slot)
				}
				else
				{
					fx = mouse_x
					fy = mouse_y
				}

				dx = fx - jx
				dy = fy - jy
				dist = point_distance(0, 0, dx, dy)

				if (dist > jr)
				{
					dx = (dx / dist) * jr
					dy = (dy / dist) * jr
					dist = jr
				}

				// Deadzone (15% of radius) - every game joystick has one; without it a
				// thumb that's not perfectly still on a phone (or just resting slightly
				// off true center) reads as constant tiny movement, which is likely most of
				// "se mueve raro" (no mobile game joystick moves without one). Below the
				// deadzone the knob visually snaps back to dead center (not just a frozen
				// offset) and produces zero movement, instead of a jittery dead unresponsive
				// feeling in between.
				if (dist < jr * 0.15)
				{
					dx = 0
					dy = 0
				}

				joystick_knob_x = dx
				joystick_knob_y = dy

				// Movement - mirrors camera_control_move.gml's two branches (!cam: abstract
				// work camera; else: a real, editable camera object, added 2026-09-15). No
				// CAM_FAST/SLOW modifier, no CAM_RESET, no ascend/descend (joystick only has
				// the 2 axes a thumb drags, not 4 discrete keys) - touch substitute for the
				// WASD keys specifically, not a full reimplementation.
				var joymove, joyfwd, joystrafe, joyxd, joyyd;
				joymove = 4 * setting_move_speed * delta
				joyfwd = -(joystick_knob_y / jr)
				joystrafe = (joystick_knob_x / jr)

				if (joyfwd != 0 || joystrafe != 0)
				{
					if (!cam)
					{
						joyxd = -sin(degtorad(cam_work_angle_look_xy)) * joymove * joystrafe
						joyyd = -cos(degtorad(cam_work_angle_look_xy)) * joymove * joystrafe
						joyxd += -lengthdir_x(joymove * joyfwd, cam_work_angle_look_xy)
						joyyd += -lengthdir_y(joymove * joyfwd, cam_work_angle_look_xy)

						cam_work_from[X] += joyxd
						cam_work_from[Y] += joyyd
						cam_work_from[Z] += dsin(cam_work_angle_look_z) * joymove * joyfwd

						if (!cam_work_focus_tl)
						{
							cam_work_focus[X] += joyxd
							cam_work_focus[Y] += joyyd
							cam_work_focus[Z] += dsin(cam_work_angle_look_z) * joymove * joyfwd
						}

						camera_work_set_angle()
					}
					else
					{
						joyxd = -sin(degtorad(cam.value[e_value.ROT_Z] + 90)) * joymove * joystrafe
						joyyd = -cos(degtorad(cam.value[e_value.ROT_Z] + 90)) * joymove * joystrafe
						joyxd += -lengthdir_x(joymove * joyfwd, cam.value[e_value.ROT_Z] + 90)
						joyyd += -lengthdir_y(joymove * joyfwd, cam.value[e_value.ROT_Z] + 90)

						tl_value_set_start(camera_control_move, true)
						tl_value_set(e_value.POS_X, joyxd, true)
						tl_value_set(e_value.POS_Y, joyyd, true)
						tl_value_set(e_value.POS_Z, (-dsin(cam.value[e_value.ROT_X])) * joymove * joyfwd, true)
						tl_value_set_done()
					}
				}

				// Simultaneous look (explicit user request, "por comodidad") - whichever raw
				// touch slot ISN'T the joystick's own finger drives look-rotation from its
				// own per-frame delta directly, independent of mouse_x/mouse_y (frozen while
				// 2 fingers are down, AppWindow::event()) and of the joystick finger's own
				// motion. Work camera: same rotation math as camera_control_rotate.gml's
				// Android branch. Real camera (2026-09-15): free rotation via ROT_X/ROT_Z,
				// matching camera_control_move.gml's own cam branch - CAM_ROTATE_* (used by
				// camera_control_rotate.gml's cam branch) is the look-at/orbit mode, not the
				// free fly-look this gesture stands in for.
				var lookslot = (joystick_slot = 0) ? 1 : 0;

				if (touch_point_active(lookslot))
				{
					if (joystick_look_tracking)
					{
						var lx, ly, lookmx, lookmy;
						lx = touch_point_x(lookslot) - joystick_look_prev_x
						ly = touch_point_y(lookslot) - joystick_look_prev_y

						lookmx = -(lx / 4)
						lookmy = (ly / 4)

						if (!cam)
						{
							cam_work_angle_xy += lookmx
							cam_work_angle_z += lookmy
							cam_work_angle_z = clamp(cam_work_angle_z, -89.9, 89.9)
							cam_work_angle_look_xy += lookmx
							cam_work_angle_look_z -= lookmy
							cam_work_angle_look_z = clamp(cam_work_angle_look_z, -89.9, 89.9)
							camera_work_set_from()
						}
						else
						{
							tl_value_set_start(camera_control_move, true)
							tl_value_set(e_value.ROT_X, -lookmy, true)
							tl_value_set(e_value.ROT_Z, lookmx, true)
							tl_value_set_done()
						}
					}

					joystick_look_prev_x = touch_point_x(lookslot)
					joystick_look_prev_y = touch_point_y(lookslot)
					joystick_look_tracking = true
				}
				else
					joystick_look_tracking = false
			}
		}

		joystick_alpha = test_reduced_motion(joystick_active ? 1 : 0.35, joystick_alpha + ((joystick_active ? 1 : 0.35) - joystick_alpha) / max(1, 6 / delta))
	}

	// Click
	if (content_mouseon && (window_busy = "" || window_busy = "place"))
	{
		place_view_mouse = view
		mouse_cursor = cr_handpoint
		if (mouse_left_pressed)
		{
			window_busy = "viewclick"
			window_focus = string(view)
		}
		
		if ((!cam || editcamobj) && mouse_right_pressed)
		{
			view_click_x = display_mouse_get_x()
			view_click_y = display_mouse_get_y()
			window_busy = "viewmovecamera"
			window_focus = string(view)
			if (cam)
				action_tl_select_single(cam)
		}
	}
	
	// Jump to object
	if ((window_busy = "" && content_mouseon) && tl_edit != null && tl_edit != cam && !cam && keybinds[e_keybind.CAM_VIEW_TIMELINE].pressed)
	{
		cam_work_focus = tl_edit.world_pos
		cam_work_focus_last = point3D_copy(cam_work_focus)
		
		camera_work_set_angle()
		cam_work_angle_look_xy = cam_work_angle_xy
		cam_work_angle_look_z = -cam_work_angle_z
		cam_work_zoom_goal = 100
		camera_work_set_from()
		
		cam_work_jump = true
	}
	
	// Mousewheel / pinch-zoom
	// touch_pinch_delta() (Fase 4, Trampa 1/B10) is the two-finger equivalent of mouse_wheel -
	// §6.4 mapped "rueda del mouse" to "pinch / scroll con dos dedos" and this is that half
	// (two-finger pan is handled below, in the viewclick block). Raw logical-pixel delta per
	// frame, divided by 100 to land in roughly the same order of magnitude as mouse_wheel's
	// discrete +-1 ticks before going through the exact same *0.25 zoom formula already used
	// for the wheel - a starting sensitivity, not device-tuned yet. Included in the busy-state
	// check for viewpancamera too (pinch can happen mid-pan, doesn't need its own gate).
	var wheelzoom = mouse_wheel;
	if (platform_get() == e_platform.ANDROID && touch_count() >= 2)
		wheelzoom += touch_pinch_delta() / 100

	if (((((window_busy = "" || window_busy = "place") && content_mouseon) || ((window_busy = "viewrotatecamera" || window_busy = "viewpancamera") && window_focus = string(view)))) && wheelzoom <> 0)
	{
		if (!cam)
			cam_work_zoom_goal = clamp(cam_work_zoom_goal * (1 + 0.25 * wheelzoom), cam_near, cam_far)
		else if (cam.value[e_value.CAM_ROTATE] && editcamobj)
		{
			action_tl_select_single(cam)
			if (cam.cam_goalzoom < 0) // Reset
				cam.cam_goalzoom = cam.value[e_value.CAM_ROTATE_DISTANCE]
			cam.cam_goalzoom = max(1, cam.cam_goalzoom * (1 + 0.25 * wheelzoom))
		}
	}
	
	if (window_focus = string(view))
	{
		// Select or move camera
		if (window_busy = "viewclick")
		{
			mouse_cursor = cr_handpoint
			
			// Two-finger pan (Fase 4, Trampa 1/B10) - desktop's pan modifier is Shift+drag,
			// which has no reliable equivalent on Android (no physical keyboard); a second
			// finger landing is the touch-native substitute, checked before the mouse_move>5
			// threshold so pan wins immediately instead of momentarily orbiting first. Only
			// catches the common case of both fingers landing together while still in
			// "viewclick" (the state a single mouse_left_pressed enters) - a second finger
			// added after rotation has already started (mouse_move>5 already fired) isn't
			// handled by this first pass, documented limitation, not an oversight.
			var twofingerpan = (platform_get() == e_platform.ANDROID && touch_count() >= 2);

			if ((!cam || editcamobj) && (mouse_move > 5 || twofingerpan))
			{
				if (keyboard_check(vk_shift) || twofingerpan)
				{
					window_busy = "viewpancamera"
					window_focus = string(view)

					if (cam)
						action_tl_select_single(cam)
				}
				else
				{
					view_click_x = display_mouse_get_x()
					view_click_y = display_mouse_get_y()
					window_busy = "viewrotatecamera"
					if (cam)
						action_tl_select_single(cam)
				}
			}
			
			if (!mouse_left)
			{
				if (place_tl = null)
				{
					view_click(view, cam)
					window_busy = ""
				}
				else // Stop placing
					app_stop_place()
			}
		}
		
		// Rotate camera
		if (window_busy = "viewrotatecamera")
		{
			// Android: upgrade to two-finger pan if a second finger lands mid-rotation (Fase
			// 4, closes the documented limitation from the first Trampa 1 pass, 2026-09-11 -
			// that pass only caught both fingers landing together in "viewclick", not a
			// second finger added after rotation already started). Mirrors the exact same
			// transition "viewclick" does above when it first sees 2 touches. The very next
			// "if (window_busy = "viewpancamera")" block below re-checks window_busy fresh,
			// so this also starts panning on this SAME frame, not one frame later.
			if (platform_get() == e_platform.ANDROID && touch_count() >= 2 && (!cam || editcamobj))
			{
				window_busy = "viewpancamera"
				window_focus = string(view)
			}
			else
			{
				render_samples = -1

				if (setting_camera_lock_mouse)
					mouse_cursor = cr_none

				if (!cam || cam.value[e_value.CAM_ROTATE])
					camera_control_rotate(cam, view_click_x, view_click_y)
				else
					camera_control_move(cam, view_click_x, view_click_y)

				if (!mouse_left)
					window_busy = (place_tl != null ? "place" : "")
			}
		}
		
		// Move camera
		if (window_busy = "viewmovecamera")
		{
			render_samples = -1
			
			if (cam = null)
				shortcut_bar_state = "cameramove"
			else
				shortcut_bar_state = "tlcameramove"
			
			if (setting_camera_lock_mouse)
				mouse_cursor = cr_none
			camera_control_move(cam, view_click_x, view_click_y)
			
			if (!mouse_right)
			{
				camera_work_set_focus()
				window_busy = (place_tl != null ? "place" : "")
			}
		}
		
		// Pan camera
		if (window_busy = "viewpancamera")
		{
			camera_control_pan(cam)
			
			if (!mouse_left)
			{
				camera_work_set_focus()
				window_busy = ""
			}
		}
	}
	
	// Clear busy
	if (window_busy = "viewpathpointclick")
		window_busy = ""
}
