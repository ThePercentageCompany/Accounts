import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class HtmlDocumentPreview extends StatelessWidget {
  const HtmlDocumentPreview({super.key, required this.html});
  final String html;
  @override
  Widget build(BuildContext context) => HtmlElementView.fromTagName(
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
