import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
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
    return variantCall != null && 
           objectMethodBindCall != null && 
           classdbGetMethodBind != null &&
           objectGetInstanceBinding != null;
  }
}
