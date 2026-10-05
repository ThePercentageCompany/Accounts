import 'package:web/web.dart' as web;

void clearInviteLocation() {
  if (web.window.location.hash.startsWith('#employee-invite=')) {
    web.window.history.replaceState(
      null,
      '',
      '${web.window.location.pathname}${web.window.location.search}',
    );
  }
}
