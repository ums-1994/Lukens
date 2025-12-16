import 'package:flutter/material.dart';

class Footer extends StatelessWidget {
  const Footer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0xFF0B0F19),
        border: Border(top: BorderSide(color: Color(0x22333B53))),
      ),
      child: Center(
        child: RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFD1D5DB),
                  fontSize: 12,
                ),
            children: const [
              TextSpan(text: '© 2025 made with '),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Icon(Icons.favorite, size: 14, color: Color(0xFFE11D48)),
              ),
              TextSpan(text: '  by the Khonology Team. Digitizing Africa.'),
            ],
          ),
        ),
      ),
    );
  }
}



