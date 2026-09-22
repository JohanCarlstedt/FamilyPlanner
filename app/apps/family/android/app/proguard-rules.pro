# Release builds shrink with R8; debug builds do not. That difference is
# why this file exists and why it was missing for so long: the whiteboard
# reader was added, every debug build kept working, and the only thing
# that broke was a release bundle nobody had built since.

# ML Kit's text recognition can read Latin, Chinese, Devanagari, Japanese
# and Korean script. Each non-Latin one is a separate dependency, and this
# app takes only Latin — a photo of a Swedish whiteboard. The plugin
# still names all five so it can offer whichever you depend on, so R8
# sees references to four classes that are deliberately absent and
# refuses to finish.
#
# Suppressed rather than satisfied: pulling in four script models the
# family will never use would add tens of megabytes to every install to
# silence a warning about code that is never reached.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
