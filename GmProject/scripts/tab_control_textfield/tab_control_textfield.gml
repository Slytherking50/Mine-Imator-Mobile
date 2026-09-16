/// tab_control_textfield([toplabel, [size]])
/// @arg [toplabel
/// @arg [size]]

function tab_control_textfield(toplabel = true, size = undefined)
{
	// size can't default to ui_touch_textfield_height in the parameter list - same CppGen
	// limitation as draw_wheel.gml's rad (GML default parameter expressions that reference
	// instance variables transpile to an undeclared M_ui_touch_textfield_height identifier,
	// confirmed by a real build failure, not just reasoning). Computed here instead.
	if (is_undefined(size))
		size = ui_touch_textfield_height

	tab_control(size + ((label_height + 8) * toplabel))
}
