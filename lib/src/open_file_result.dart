/// Outcome of opening a local file.
enum OpenFileStatus {
  /// The operating system accepted the viewer launch.
  done,

  /// The operating system accepted the share-sheet launch.
  shareSheet,

  /// The path does not point to an existing regular file.
  fileNotFound,

  /// Android could launch neither a viewer nor a share sheet.
  noAppToOpen,

  /// iOS has no active screen on which to present.
  noViewController,

  /// The current platform is not supported.
  unsupportedPlatform,

  /// Opening failed. See [OpenFileResult.message].
  error,
}

/// A non-throwing outcome of a file launch, not confirmation the file was read.
class OpenFileResult {
  /// Creates an outcome with a human-readable diagnostic.
  const OpenFileResult(this.status, this.message);

  /// Decodes a native response, treating malformed responses as errors.
  factory OpenFileResult.fromMap(Map<Object?, Object?>? map) {
    final status = map?['status'];
    final message = map?['message'];
    if (status is! String || (message != null && message is! String)) {
      return const OpenFileResult(
        OpenFileStatus.error,
        'Invalid native response',
      );
    }
    for (final value in OpenFileStatus.values) {
      if (value.name == status) {
        return OpenFileResult(value, message as String? ?? '');
      }
    }
    return OpenFileResult(
      OpenFileStatus.error,
      'Unknown native status: $status',
    );
  }

  /// Machine-readable launch outcome.
  final OpenFileStatus status;

  /// Human-readable diagnostic; do not use it for control flow.
  final String message;

  /// Whether a viewer or share-sheet launch was accepted.
  bool get isSuccess =>
      status == OpenFileStatus.done || status == OpenFileStatus.shareSheet;

  @override
  String toString() => 'OpenFileResult(${status.name}, $message)';
}
