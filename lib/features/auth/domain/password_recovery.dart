Uri passwordRecoveryRedirect(Uri appUri) {
  final base = ['http', 'https'].contains(appUri.scheme)
      ? Uri.parse('${appUri.origin}/')
      : Uri.parse('https://accounts.thepercentagecompany.com/');
  return base.replace(queryParameters: {'auth': 'recovery'});
}

bool isPasswordRecoveryLink(Uri uri) {
  final fragment =
      Uri.splitQueryString(uri.fragment.startsWith('/') ? '' : uri.fragment);
  return uri.queryParameters['auth'] == 'recovery' ||
      uri.queryParameters['type'] == 'recovery' ||
      fragment['type'] == 'recovery';
}
