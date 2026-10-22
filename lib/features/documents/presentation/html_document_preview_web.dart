import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class HtmlDocumentPreview extends StatelessWidget {
  const HtmlDocumentPreview({super.key, required this.html});
  final String html;
  @override
  Widget build(BuildContext context) {
    // An iframe receives browser pointer events independently of Flutter's
    // hit testing. Remove it while a picker or other route covers this route
    // so it cannot swallow clicks on the dialog (especially on wide layouts).
    if (ModalRoute.isCurrentOf(context) == false) {
      return const SizedBox.expand();
    }
    return HtmlElementView.fromTagName(
      key: ValueKey(html),
      tagName: 'iframe',
      onElementCreated: (element) {
        final frame = element as web.HTMLIFrameElement;
        frame.setAttribute('sandbox', '');
        frame.setAttribute('title', 'Company HTML document preview');
        frame.style
          ..width = '100%'
          ..height = '100%'
          ..border = '0';
        frame.srcdoc = html.toJS;
      },
    );
  }
}
