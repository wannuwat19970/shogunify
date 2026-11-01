import 'package:flutter/material.dart';
import 'package:shogunify/widgets/shogunify_drawer.dart';

class Support extends StatelessWidget {
  const Support({super.key, this.username = 'Logged-in user', this.onLogout});
  final String username;

  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: const Color.fromARGB(255, 72, 61, 115),
        title: const Text(
          'Shogunify - Support dev',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      drawer: const ShogunifyDrawer(),
      backgroundColor: const Color.fromARGB(255, 37, 37, 37),
      body: Stack(
        children: [
          Align(
            alignment: Alignment(0, -0.6),
            child: FractionallySizedBox(
              widthFactor: 0.8, // 50% of parent width
              child: Image.asset(
                'assets/images/support.jpeg',
                fit: BoxFit.contain,
              ),
            ),
          ),
          Align(
            alignment: Alignment(0, 0.48),
            child: Text(
              "ซัพพอร์ตชั้นที",
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white,
                decorationThickness: 2,
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, 0.65),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: const Text(
                "ขอบคุณทุกคนมากๆ ที่ยอมเอาแอปนี้ลงเครื่อง\n"
                "ถ้าใช้แล้วชอบ อยากเลี้ยงข้าว/สนับสนุนโอนเลย\n"
                "(ถ้ากดโอนผิดทักมาบอกได้ พร้อมโอนคืน ไม่บิดชัว)",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white,
                  height: 1.5,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment(0, 0.9),
            child: Text(
              "***เดี๋ยวจะมีช่องให้ส่งfeedback ในแพทซ์ 1.0.5(coming soon)***",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white,
                decorationThickness: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
