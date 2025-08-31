import 'dart:ffi';
import 'dart:io';
import 'package:flutter_libgodot/godot/wrapper.dart';
import '../src/bindings.dart';

// Generate ffigen bindings from libgodot binary
LibGodotBindings getGodotBindings() {
  final exeDir = File(Platform.resolvedExecutable).parent;
  final libPath = '${exeDir.path}/../Frameworks/libgodot.dylib'; // macOS only (iOS maybe?)
  final dylib = DynamicLibrary.open(libPath);
  final godot = LibGodotBindings(dylib);

  return godot;
}

typedef DartGDExtensionInterfaceObjectGetInstanceBindingFunction = GDExtensionInterfaceObjectGetInstanceBindingFunction;

// Wrapper class for Godot interface functions
class GodotInterface {
  // Common interface functions you'll need
  late final DartGDExtensionInterfaceVariantCallFunction? variantCall;
  late final DartGDExtensionInterfaceObjectMethodBindCallFunction? objectMethodBindCall;
  late final DartGDExtensionInterfaceClassdbGetMethodBindFunction? classdbGetMethodBind;
  late final DartGDExtensionInterfaceObjectGetInstanceBindingFunction? objectGetInstanceBinding;
  late final DartGDExtensionInterfaceStringNameNewWithUtf8CharsFunction? stringNameNewWithUtf8Chars;
  
  void Function(
    Pointer<Void> stringName,
  )? stringNameDestroy;
  
  bool initialize() {
    
    // Get the interface functions and convert them to callable Dart functions
    final variantCallPtr = getInterfacePtr('variant_call');
    if (variantCallPtr != null) {
      variantCall = variantCallPtr.cast<NativeFunction<GDExtensionInterfaceVariantCallFunction>>().asFunction<DartGDExtensionInterfaceVariantCallFunction>();
    }
    
    final methodBindCallPtr = getInterfacePtr('object_method_bind_call');
    if (methodBindCallPtr != null) {
      objectMethodBindCall = methodBindCallPtr.cast<NativeFunction<GDExtensionInterfaceObjectMethodBindCallFunction>>().asFunction<DartGDExtensionInterfaceObjectMethodBindCallFunction>();
    }
    
    final getMethodBindPtr = getInterfacePtr('classdb_get_method_bind');
    if (getMethodBindPtr != null) {
      classdbGetMethodBind = getMethodBindPtr.cast<NativeFunction<GDExtensionInterfaceClassdbGetMethodBindFunction>>().asFunction<DartGDExtensionInterfaceClassdbGetMethodBindFunction>();
    }
    
    final getInstanceBindingPtr = getInterfacePtr('object_get_instance_binding');
    if (getInstanceBindingPtr != null) {
      objectGetInstanceBinding = getInstanceBindingPtr.cast<NativeFunction<GDExtensionInterfaceObjectGetInstanceBindingFunction>>().asFunction<DartGDExtensionInterfaceObjectGetInstanceBindingFunction>();
    }

    final getStringNameNewPtr = getInterfacePtr('string_name_new_with_utf8_chars');
    if (getStringNameNewPtr != null) {
      stringNameNewWithUtf8Chars = getStringNameNewPtr.cast<NativeFunction<GDExtensionInterfaceStringNameNewWithUtf8CharsFunction>>().asFunction<DartGDExtensionInterfaceStringNameNewWithUtf8CharsFunction>();
    }

    // Need a stringNameDestroy to avoid memory leaks

    return variantCall != null && 
           objectMethodBindCall != null && 
           classdbGetMethodBind != null &&
           objectGetInstanceBinding != null &&
           stringNameNewWithUtf8Chars != null;
  }
}
