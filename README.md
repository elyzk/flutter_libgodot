# flutter_libgodot

Embedding Godot in a Flutter project using the GDExtension exposed API from [migeran/libgodot_project](https://github.com/migeran/libgodot_project/tree/e1a22de33525f6495685214a329c05f2cbbb14df). Bindings are generated using Dart's [ffigen](https://pub.dev/packages/ffigen) library.

This code currently calls libgodot's native ``libgodot_create_godot_instance`` function from Dart with a callback that indicates an instance has been successfully created.

Requires building libgodot for macOS and placing the resulting binary ``libgodot.dylib`` in ``/macos/`` as well as bundling the library into the Flutter build by following the steps [here](https://docs.flutter.dev/platform-integration/macos/c-interop#compiled-dynamic-library-macos).

## To do:
- Properly embed Godot's renderer (recreate the spinning cube demo from libgodot's docs)
- Embed the full godot editor
- Support other platforms