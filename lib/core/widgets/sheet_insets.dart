import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:tokri/app/theme/app_theme.dart';

/// Bottom padding for a modal bottom sheet's content.
///
/// Modal sheet routes only guard the top inset, so each sheet must clear the
/// system navigation area itself (48dp on 3-button navigation — ledgr
/// lesson). Keyboard inset plus a floor of [min] or the system bar plus
/// breathing room, whichever is larger.
double sheetBottomInset(BuildContext context, {double min = Gaps.lg}) =>
    MediaQuery.viewInsetsOf(context).bottom +
    math.max(min, MediaQuery.viewPaddingOf(context).bottom + Gaps.sm);
