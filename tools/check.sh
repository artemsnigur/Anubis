#!/bin/sh
# Compiles all scripts with every GDScript warning promoted to an error.
# Usage: sh tools/check.sh   (from the project root)
cd "$(dirname "$0")/.." || exit 1
{
  echo "[debug]"
  for w in assert_always_false assert_always_true confusable_capture_reassignment confusable_identifier \
    confusable_local_declaration confusable_local_usage confusable_temporary_modification deprecated_keyword \
    empty_file enum_variable_without_default incompatible_ternary int_as_enum_without_cast \
    int_as_enum_without_match missing_tool narrowing_conversion redundant_await redundant_static_unload \
    shadowed_global_identifier shadowed_variable shadowed_variable_base_class standalone_expression \
    standalone_ternary static_called_on_instance unassigned_variable unassigned_variable_op_assign \
    unreachable_code unreachable_pattern unsafe_void_return unused_local_constant unused_parameter \
    unused_private_class_variable unused_signal unused_variable; do
    echo "gdscript/warnings/$w=2"
  done
} > override.cfg
godot --headless --import > /dev/null 2>&1
godot --headless --script res://tools/check_scripts.gd 2>&1 | grep -v "^\s*$" | grep -v "^Godot Engine" | grep -v "backtrace\|\[[0-9]\]"
rm -f override.cfg
