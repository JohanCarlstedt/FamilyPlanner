/// The family app's crypto core: envelope encryption per crypto design doc §4.
///
/// Call `await RustLib.init()` once before using anything here.
library;

export 'src/device_vault.dart';
export 'src/rust/api.dart';
export 'src/rust/frb_generated.dart' show RustLib;
