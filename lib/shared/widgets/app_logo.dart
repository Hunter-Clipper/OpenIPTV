import 'package:material_ui/material_ui.dart';

/// The OpenIPTV "Open Ring" mark for AppBar leading slots.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(4),
      child: Image(
        image: AssetImage('assets/images/logo_mark.png'),
        fit: BoxFit.contain,
      ),
    );
  }
}
