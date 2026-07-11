import 'package:flutter/material.dart';

/// The one way Tokri shows a snackbar. Replaces whatever is currently
/// showing instead of queueing (rapid actions were stacking snackbars —
/// same class of bug as ledgr's sheet gotchas, fixed centrally).
void showToast(
  BuildContext context,
  String message, {
  SnackBarAction? action,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: action,
        behavior: SnackBarBehavior.floating,
      ),
    );
}
