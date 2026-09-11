import 'package:flutter/material.dart';

import '../views/helper_view.dart';

/// Opens the post-login shell and clears every pre-auth route.
///
/// Email login/signup are pushed on top of [StartupView]; replacing only the
/// auth page left startup under the shell so Android Back returned to
/// authorization.
void openPostAuthShell(NavigatorState navigator) {
  navigator.pushNamedAndRemoveUntil(HelperView.routeName, (route) => false);
}
