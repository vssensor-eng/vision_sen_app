import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.navy2, AppTheme.navy],
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -80, right: -70, child: _Glow(size: 190)),
          Positioned(bottom: -120, left: -90, child: _Glow(size: 230)),
          SafeArea(child: child),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final double size;
  const _Glow({required this.size});
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [AppTheme.cyan.withOpacity(.10), Colors.transparent],
            ),
          ),
        ),
      );
}

class StepHeader extends StatelessWidget {
  final int step;
  final String title;
  final VoidCallback? onBack;
  final bool showInfo;
  const StepHeader({super.key, required this.step, required this.title, this.onBack, this.showInfo = true});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBack ?? () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              ),
              const Spacer(),
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppTheme.green, shape: BoxShape.circle),
                child: Text('$step', style: const TextStyle(color: Color(0xFF082018), fontWeight: FontWeight.w900)),
              ),
              const Spacer(),
              IconButton(
                onPressed: showInfo ? () => _showInfo(context) : null,
                icon: Icon(Icons.info_outline, color: showInfo ? AppTheme.cyan : Colors.transparent),
              ),
            ],
          ),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: .4)),
          const SizedBox(height: 20),
        ],
      );

  void _showInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.panel,
      showDragHandle: true,
      builder: (_) => const Padding(
        padding: EdgeInsets.fromLTRB(22, 4, 22, 30),
        child: Text('Bu ekran cihaz kurulum adımının bir parçasıdır. Bilgiler BLE üzerinden cihaza aktarılır.'),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  const PrimaryButton({super.key, required this.text, this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 54,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: const LinearGradient(colors: [AppTheme.green, AppTheme.cyan]),
          ),
          child: ElevatedButton.icon(
            onPressed: onPressed,
            icon: icon == null ? const SizedBox.shrink() : Icon(icon, color: Colors.white),
            label: Text(text),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              textStyle: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: .2),
            ),
          ),
        ),
      );
}

class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  const SecondaryButton({super.key, required this.text, this.onPressed});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.text,
            side: const BorderSide(color: AppTheme.cyan),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      );
}

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: AppTheme.panel.withOpacity(.92),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppTheme.line),
          boxShadow: const [BoxShadow(color: Color(0x25000000), blurRadius: 18, offset: Offset(0, 8))],
        ),
        child: child,
      );
}

class SectionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  const SectionIcon({super.key, required this.icon, this.color = AppTheme.cyan});
  @override
  Widget build(BuildContext context) => Container(
        width: 82,
        height: 82,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.panel2,
          boxShadow: [BoxShadow(color: color.withOpacity(.10), blurRadius: 26)],
        ),
        child: Icon(icon, size: 42, color: color),
      );
}

class StatusDot extends StatelessWidget {
  final Color color;
  const StatusDot({super.key, this.color = AppTheme.green});
  @override
  Widget build(BuildContext context) => Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}
