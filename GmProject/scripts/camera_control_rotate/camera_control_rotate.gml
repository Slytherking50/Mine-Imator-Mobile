/// camera_control_rotate(camera, lockx, locky)
/// @arg camera
/// @arg lockx
/// @arg locky

function camera_control_rotate(cam, lockx, locky)
{
	var mx, my;

	// INSTRUMENTAL, no es el diseño de input táctil elegido - ver KNOWN_ISSUES.md.
	// display_mouse_set() recentra el cursor del SO cada frame para permitir arrastre
	// infinito en escritorio; en touch no hay cursor que recentrar, Android reporta la
	// posición REAL del dedo cada frame sin importar qué "fuerce" este código, así que el
	// recentro compite con el toque real y la cámara salta erráticamente (confirmado en
	// dispositivo real, 2026-09-09). Este branch NO diseña el modelo de input táctil (eso
	// es Fase 3/4, CLAUDE.md §12) - es el mínimo cambio para poder arrastrar sin que bugee
	// y así poder hacer la verificación visual pendiente de Fase 2 (cielo, personaje de
	// cerca, aliasing). Sigue sin pellizco-zoom y sigue sin resolver el contrato de
	// mouse_x/mouse_y entre toques (B10, CLAUDE.md §6.3) - no tomar esto como el gesto de
	// cámara final.
	if (platform_get() == e_platform.ANDROID)
	{
		mx = -(mouse_dx / 4)
		my = (mouse_dy / 4)
	}
	else
	{
		mx = -((display_mouse_get_x() - lockx) / 4)
		my = ((display_mouse_get_y() - locky) / 4)
		display_mouse_set(lockx, locky)
	}

	if (!cam)
	{
		cam_work_angle_xy += mx
		cam_work_angle_z += my
		cam_work_angle_z = clamp(cam_work_angle_z, -89.9, 89.9)
		
		cam_work_angle_look_xy += mx
		cam_work_angle_look_z -= my
		cam_work_angle_look_z = clamp(cam_work_angle_look_z, -89.9, 89.9)
		camera_work_set_from()
		
		if (keybinds[e_keybind.CAM_RESET].pressed)
			camera_work_reset()
	}
	else
	{
		tl_value_set_start(camera_control_rotate, true)
		tl_value_set(e_value.CAM_ROTATE_ANGLE_XY, mx, true)
		tl_value_set(e_value.CAM_ROTATE_ANGLE_Z, my, true)
		
		if (frame_editor.camera.look_at_rotate)
		{
			tl_value_set(e_value.ROT_Z, cam.value[e_value.CAM_ROTATE_ANGLE_XY], false)
			tl_value_set(e_value.ROT_X, cam.value[e_value.CAM_ROTATE_ANGLE_Z], false)
		}
		
		tl_value_set_done()
	}
}
