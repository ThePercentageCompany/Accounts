import 'package:tpc_invoice/core/widgets/tpc_logo.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';

const _ink = Color(0xff0a0a0c);
const _panel = Color(0xff121214);
const _line = Color(0xff29292c);
const _muted = Color(0xffa2a2ab);

class LandingView extends StatelessWidget {
  const LandingView(
      {super.key,
      required this.busy,
      required this.onSignIn,
      required this.onFaq,
      required this.onEmployeeLogin,
      this.error});
  final bool busy;
  final VoidCallback onSignIn, onFaq, onEmployeeLogin;
  final String? error;

  Widget _button(String label, VoidCallback action, {bool primary = true}) =>
      FilledButton(
          onPressed: busy ? null : action,
          style: FilledButton.styleFrom(
              backgroundColor: primary ? Colors.white : const Color(0xff232326),
              foregroundColor: primary ? _ink : Colors.white,
              disabledBackgroundColor: _line,
              disabledForegroundColor: _muted,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              shape: const StadiumBorder(),
              side: primary
                  ? BorderSide.none
                  : const BorderSide(color: Color(0xff45454b))),
          child: Text(label));

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 700;
    final gap = mobile ? 24.0 : 56.0;
    return Theme(
        data: ThemeData(
            brightness: Brightness.dark,
            useMaterial3: true,
            fontFamily: 'Inter',
            scaffoldBackgroundColor: _ink,
            colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xff69d5b2),
                brightness: Brightness.dark)),
        child: DefaultTextStyle(
            style: const TextStyle(
                fontFamily: 'Inter', color: Colors.white, fontSize: 14),
            child: ColoredBox(
                color: _ink,
                child: SingleChildScrollView(
                    child: Center(
                        child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Container(
                      decoration: const BoxDecoration(
                          border: Border.symmetric(
                              vertical: BorderSide(color: _line))),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: gap, vertical: 20),
                                child: Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 24,
                                    runSpacing: 16,
                                    children: [
                                      const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TpcLogo(
                                                size: 32,
                                                brightness: Brightness.dark),
                                            SizedBox(width: 10),
                                            Text('TPC / ACCOUNTS',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 1.2))
                                          ]),
                                      Wrap(
                                          spacing: 16,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            TextButton(
                                                onPressed: onFaq,
                                                child: const Text(
                                                    'Getting started',
                                                    style: TextStyle(
                                                        color: _muted))),
                                            TextButton(
                                                onPressed: busy
                                                    ? null
                                                    : onEmployeeLogin,
                                                child: const Text(
                                                    'Employee login',
                                                    style: TextStyle(
                                                        color: Colors.white))),
                                          ]),
                                    ])),
                            const Divider(height: 1, color: _line),
                            Stack(children: [
                              Positioned.fill(
                                  child: RepaintBoundary(
                                      child: CustomPaint(
                                          painter: _AuroraPainter()))),
                              Padding(
                                  padding: EdgeInsets.fromLTRB(
                                      gap,
                                      mobile ? 64 : 100,
                                      gap,
                                      mobile ? 72 : 112),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const _Eyebrow(
                                            'ONE WORKSPACE. A CLEARER PICTURE.'),
                                        const SizedBox(height: 24),
                                        ConstrainedBox(
                                            constraints: const BoxConstraints(
                                                maxWidth: 960),
                                            child: Text(
                                                'Your business.\nEverything connected.',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: mobile ? 42 : 76,
                                                    height: 1.08,
                                                    letterSpacing:
                                                        mobile ? -1.8 : -3.6,
                                                    fontWeight:
                                                        FontWeight.w500))),
                                        const SizedBox(height: 28),
                                        const SizedBox(
                                            width: 650,
                                            child: Text(
                                                'From the first invoice to the final balance sheet. Bring your accounts, projects and team together in one company workspace.',
                                                style: TextStyle(
                                                    color: Color(0xffc2c2c8),
                                                    fontSize: 18,
                                                    height: 1.65))),
                                        const SizedBox(height: 32),
                                        Wrap(
                                            spacing: 12,
                                            runSpacing: 12,
                                            children: [
                                              _button(
                                                  busy
                                                      ? 'Opening sign-in…'
                                                      : 'Get started with Google',
                                                  onSignIn),
                                              _button('Explore the workspace',
                                                  onFaq,
                                                  primary: false),
                                            ]),
                                        const SizedBox(height: 18),
                                        const Text(
                                            'Already have a workspace? Sign in to pick up where you left off.',
                                            style: TextStyle(
                                                color: _muted,
                                                fontSize: 12,
                                                height: 1.6)),
                                        if (busy)
                                          Padding(
                                              padding: EdgeInsets.only(top: 16),
                                              child: Semantics(
                                                  liveRegion: true,
                                                  child: Text(
                                                      'Please wait while we connect you to Google.',
                                                      style: TextStyle(
                                                          color:
                                                              Colors.white)))),
                                        if (error != null)
                                          Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 16),
                                              child: Semantics(
                                                  liveRegion: true,
                                                  child: Text(error!,
                                                      style: const TextStyle(
                                                          color:
                                                              Color(0xffffa8a8),
                                                          height: 1.5)))),
                                      ])),
                            ]),
                            const _HatchedDivider(),
                            Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: gap, vertical: 28),
                                child: Wrap(
                                    spacing: mobile ? 22 : 48,
                                    runSpacing: 20,
                                    alignment: WrapAlignment.spaceBetween,
                                    children: [
                                      for (final item in const [
                                        (
                                          Icons.receipt_long_outlined,
                                          'INVOICES'
                                        ),
                                        (
                                          Icons.account_balance_outlined,
                                          'ACCOUNTING'
                                        ),
                                        (Icons.work_outline, 'PROJECTS'),
                                        (Icons.groups_outlined, 'YOUR TEAM')
                                      ])
                                        Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(item.$1,
                                                  color: _muted, size: 20),
                                              const SizedBox(width: 10),
                                              Text(item.$2,
                                                  style: const TextStyle(
                                                      color: _muted,
                                                      fontSize: 12,
                                                      letterSpacing: 1.3))
                                            ]),
                                    ])),
                            const _HatchedDivider(),
                            Padding(
                                padding: EdgeInsets.all(gap),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const _Eyebrow(
                                          'BUILT AROUND YOUR EVERYDAY WORK'),
                                      const SizedBox(height: 20),
                                      Text('Less admin.\nMore clarity.',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: mobile ? 36 : 54,
                                              height: 1.12,
                                              letterSpacing: -1.8)),
                                      const SizedBox(height: 20),
                                      const Text(
                                          'Follow the money. Move work forward. See how it all fits together.',
                                          style: TextStyle(
                                              color: _muted,
                                              fontSize: 16,
                                              height: 1.6)),
                                      const SizedBox(height: 36),
                                      LayoutBuilder(builder: (context, bounds) {
                                        final columns =
                                            bounds.maxWidth >= 850 ? 3 : 1;
                                        final width = (bounds.maxWidth -
                                                (columns - 1) * 16) /
                                            columns;
                                        return Wrap(
                                            spacing: 16,
                                            runSpacing: 16,
                                            children: [
                                              for (final item in const [
                                                (
                                                  '01',
                                                  'From quote to paid.',
                                                  'Create quotations and invoices, manage customers and record payments.',
                                                  0
                                                ),
                                                (
                                                  '02',
                                                  'Know your numbers.',
                                                  'Review income, expenses, ledger activity and financial reports together.',
                                                  1
                                                ),
                                                (
                                                  '03',
                                                  'Keep work moving.',
                                                  'Connect projects, tasks and calendars. Give your team the access they need.',
                                                  2
                                                ),
                                              ])
                                                SizedBox(
                                                    width: width,
                                                    child: _FeatureCard(
                                                        number: item.$1,
                                                        title: item.$2,
                                                        body: item.$3,
                                                        graphic: item.$4)),
                                            ]);
                                      }),
                                    ])),
                            const _HatchedDivider(),
                            Padding(
                                padding: EdgeInsets.all(gap),
                                child:
                                    LayoutBuilder(builder: (context, bounds) {
                                  final heading = Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const _Eyebrow('A SIMPLE START'),
                                        const SizedBox(height: 20),
                                        Text('Your workspace.\nYour way.',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: mobile ? 36 : 48,
                                                height: 1.15,
                                                letterSpacing: -1.5)),
                                        const SizedBox(height: 20),
                                        const Text(
                                            'Start with the essentials.\nBuild your daily workflow from there.',
                                            style: TextStyle(
                                                color: _muted, height: 1.7))
                                      ]);
                                  const steps = Column(children: [
                                    _Step('01', 'Sign in with Google',
                                        'Access your owner account with your Google sign-in.'),
                                    _Step('02', 'Connect your company',
                                        'Create a company and connect Google to prepare its workspace storage.'),
                                    _Step('03', 'Make it yours',
                                        'Set up your profile, add your first customer and create an invoice draft.'),
                                  ]);
                                  return bounds.maxWidth < 750
                                      ? Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                              heading,
                                              const SizedBox(height: 36),
                                              steps
                                            ])
                                      : Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                              Expanded(child: heading),
                                              const SizedBox(width: 64),
                                              Expanded(child: steps)
                                            ]);
                                })),
                            const _HatchedDivider(),
                            Stack(children: [
                              Positioned.fill(
                                  child: CustomPaint(
                                      painter: _AuroraPainter(subtle: true))),
                              Padding(
                                  padding: EdgeInsets.all(gap),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const _Eyebrow('BRING IT ALL TOGETHER'),
                                        const SizedBox(height: 24),
                                        Text(
                                            'A better view of\nyour business starts here.',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: mobile ? 34 : 52,
                                                height: 1.15,
                                                letterSpacing: -1.8)),
                                        const SizedBox(height: 28),
                                        _button(
                                            'Open your workspace', onSignIn),
                                      ]))
                            ]),
                            const Divider(height: 1, color: _line),
                            Padding(
                                padding: EdgeInsets.all(gap),
                                child: Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 24,
                                    runSpacing: 20,
                                    children: [
                                      const Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text('TPC ACCOUNTS',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 1.3)),
                                            SizedBox(height: 10),
                                            Text('Accounts. Projects. People.',
                                                style: TextStyle(color: _muted))
                                          ]),
                                      Wrap(spacing: 16, children: [
                                        TextButton(
                                            onPressed: onFaq,
                                            child: const Text(
                                                'FAQ & getting started',
                                                style:
                                                    TextStyle(color: _muted))),
                                        TextButton(
                                            onPressed:
                                                busy ? null : onEmployeeLogin,
                                            child: const Text('Employee login',
                                                style: TextStyle(
                                                    color: Colors.white)))
                                      ]),
                                    ])),
                          ])),
                ))))));
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: _muted,
          fontSize: 11,
          letterSpacing: 1.8,
          fontWeight: FontWeight.w600,
          height: 1.6));
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard(
      {required this.number,
      required this.title,
      required this.body,
      required this.graphic});
  final String number, title, body;
  final int graphic;
  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
          color: _panel,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            height: 200,
            width: double.infinity,
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: ExcludeSemantics(
                    child: CustomPaint(painter: _ProductPainter(graphic))))),
        const Divider(height: 1, color: _line),
        Padding(
            padding: const EdgeInsets.all(24),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(number, style: const TextStyle(color: _muted, fontSize: 12)),
              const SizedBox(height: 18),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 24, letterSpacing: -.7)),
              const SizedBox(height: 12),
              Text(body, style: const TextStyle(color: _muted, height: 1.7))
            ])),
      ]));
}

class _Step extends StatelessWidget {
  const _Step(this.number, this.title, this.body);
  final String number, title, body;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration:
          const BoxDecoration(border: Border(bottom: BorderSide(color: _line))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(number, style: const TextStyle(color: _muted, fontSize: 12)),
        const SizedBox(width: 24),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 10),
          Text(body, style: const TextStyle(color: _muted, height: 1.7))
        ]))
      ]));
}

class _HatchedDivider extends StatelessWidget {
  const _HatchedDivider();
  @override
  Widget build(BuildContext context) => const SizedBox(
      height: 32,
      width: double.infinity,
      child: CustomPaint(painter: _HatchPainter()));
}

class _HatchPainter extends CustomPainter {
  const _HatchPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final paint = Paint()
      ..color = _line
      ..strokeWidth = .6;
    for (double x = -size.height; x < size.width; x += 12) {
      canvas.drawLine(
          Offset(x, 0), Offset(x + size.height, size.height), paint);
    }
    canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
    canvas.drawLine(
        Offset(0, size.height), Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(_HatchPainter oldDelegate) => false;
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({this.subtle = false});
  final bool subtle;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final rect = Offset.zero & size;
    for (final glow in [
      (const Color(0xff008674), .65, .38),
      (const Color(0xffad531d), .85, .58),
      (const Color(0xff234899), .4, .7)
    ]) {
      canvas.drawRect(
          rect,
          Paint()
            ..shader = RadialGradient(
                center: Alignment(glow.$2 * 2 - 1, glow.$3 * 2 - 1),
                radius: .75,
                colors: [
                  glow.$1.withValues(alpha: subtle ? .15 : .38),
                  Colors.transparent
                ]).createShader(rect));
    }
    for (var i = 0; i < 120; i++) {
      final path = Path();
      for (var step = 0; step <= 65; step++) {
        final x = size.width * step / 65;
        final y = size.height * (.25 + i / 120 * .8) +
            math.sin(step / 65 * math.pi * 3.1 + i * .025) * size.height * .2;
        if (step == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = .7
            ..shader = LinearGradient(colors: [
              Colors.transparent,
              const Color(0xff147069).withValues(alpha: .35),
              const Color(0xffc47738).withValues(alpha: subtle ? .15 : .35),
              Colors.transparent
            ]).createShader(rect));
    }
    canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xdd0a0a0c), Color(0x220a0a0c)])
              .createShader(rect));
  }

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) =>
      oldDelegate.subtle != subtle;
}

class _ProductPainter extends CustomPainter {
  const _ProductPainter(this.kind);
  final int kind;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    void box(Rect rect, Color color) {
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)),
          paint..color = color);
    }

    void line(Offset a, Offset b, Color color, [double width = 2]) {
      canvas.drawLine(
          a,
          b,
          paint
            ..color = color
            ..strokeWidth = width);
    }

    const green = Color(0xff83c8ad);
    if (kind == 0) {
      final w = math.min(size.width * .75, 220.0);
      final x = (size.width - w) / 2;
      box(Rect.fromLTWH(x, 0, w, size.height), const Color(0xff202024));
      for (var i = 0; i < 4; i++) {
        line(
            Offset(x + 16, 25 + i * 26),
            Offset(x + w * (i == 0 ? .7 : .5), 25 + i * 26),
            i == 0 ? Colors.white70 : const Color(0xff4b4b52),
            i == 0 ? 4 : 2);
      }
      box(Rect.fromLTWH(x + w - 85, size.height - 42, 70, 24),
          const Color(0xff254238));
      final label = TextPainter(
          text: const TextSpan(
              text: 'PAID',
              style: TextStyle(color: green, fontSize: 10, letterSpacing: 2)),
          textDirection: TextDirection.ltr)
        ..layout();
      label.paint(canvas, Offset(x + w - 70, size.height - 36));
    } else if (kind == 1) {
      for (var i = 0; i < 4; i++) {
        line(Offset(0, i * 40), Offset(size.width, i * 40), _line, 1);
      }
      final bar = size.width / 12;
      for (var i = 0; i < 8; i++) {
        final h = 28.0 + i * 12 + math.sin(i * 2) * 20;
        box(
            Rect.fromLTWH(12 + i * bar * 1.35, size.height - h, bar * .8, h),
            i == 7
                ? green
                : Color.lerp(const Color(0xff223d35), green, i / 12)!);
      }
    } else {
      final centers = [
        Offset(size.width * .17, size.height * .5),
        Offset(size.width * .5, size.height * .23),
        Offset(size.width * .83, size.height * .5),
        Offset(size.width * .5, size.height * .8)
      ];
      for (var i = 0; i < centers.length; i++) {
        line(centers[i], centers[(i + 1) % 4], const Color(0xff426058), 1);
      }
      for (final c in centers) {
        canvas.drawCircle(c, 20, paint..color = const Color(0xff203830));
        canvas.drawCircle(c, 6, paint..color = green);
      }
      line(centers[0], centers[2], const Color(0xff426058), 1);
    }
  }

  @override
  bool shouldRepaint(_ProductPainter oldDelegate) => oldDelegate.kind != kind;
}
