import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shogunify/controllers/provider.dart';
import 'package:shogunify/controllers/states.dart';
import 'package:shogunify/controllers/auth_controller.dart';
import 'package:shogunify/pages/addsongs.dart';
import 'package:shogunify/pages/home.dart';
import 'package:shogunify/pages/library.dart';
import 'package:shogunify/pages/login.dart';
import 'package:shogunify/pages/player.dart';
import 'package:shogunify/pages/playlist_detail.dart';
import 'package:shogunify/pages/settings.dart';
import 'package:shogunify/pages/support.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final PlayerController controller = await AudioService.init<PlayerController>(
    builder: () => PlayerController(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.shogunify.audio',
      androidNotificationChannelName: 'Shogunify Playback',
      androidNotificationOngoing: true,
    ),
  );

  runApp(MyApp(playerController: controller));
}

class MyApp extends StatelessWidget {
  final PlayerController playerController;

  const MyApp({super.key, required this.playerController});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<PlayerController>.value(value: playerController),
        ChangeNotifierProvider<States>(create: (_) => States()),
        ChangeNotifierProvider<AuthController>(
          create: (_) => AuthController()..checkLoginStatus(),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(
          textTheme: GoogleFonts.kanitTextTheme(Theme.of(context).textTheme),
          scaffoldBackgroundColor: const Color.fromARGB(255, 34, 34, 34),
        ),
        debugShowCheckedModeBanner: false,
        home: const AuthGate(),
        routes: {
          '/home': (_) => const Home(),
          '/player': (_) => const PlayPause(),
          '/settings': (_) => const Settings(),
          '/library': (_) => const Library(),
          '/addsongs': (_) => const Addsongs(),
          '/support': (_) => const Support(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/playlist-detail') {
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => PlaylistDetail(
                playlistId: args['playlistId'] as int,
                token: args['token'] as String,
              ),
            );
          }
          return null;
        },
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, auth, child) {
        if (auth.isLoading) {
          return const Scaffold(
            backgroundColor: Color.fromARGB(255, 34, 34, 34),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return auth.token != null ? const Home() : const Login();
      },
    );
  }
}

// import 'package:audio_service/audio_service.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';

// import 'package:shogunify/controllers/provider.dart';
// import 'package:shogunify/controllers/states.dart';
// import 'package:shogunify/pages/addsongs.dart';
// import 'package:shogunify/pages/home.dart';
// import 'package:shogunify/pages/library.dart';
// import 'package:shogunify/pages/player.dart';
// import 'package:shogunify/pages/settings.dart';
// import 'package:google_fonts/google_fonts.dart';

// import 'package:shogunify/controllers/auth_controller.dart';
// import 'package:shogunify/pages/login.dart';

// import 'package:package_info_plus/package_info_plus.dart';
// import 'package:url_launcher/url_launcher.dart';

// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();

//   await SystemChrome.setPreferredOrientations([
//     DeviceOrientation.portraitUp,
//     DeviceOrientation.portraitDown,
//   ]);

//   final PlayerController controller = await AudioService.init<PlayerController>(
//     builder: () => PlayerController(),
//     config: const AudioServiceConfig(
//       androidNotificationChannelId: 'com.shogunify.audio',
//       androidNotificationChannelName: 'Shogunify Playback',
//       androidNotificationOngoing: true,
//     ),
//   );

//   runApp(MyApp(playerController: controller));
// }

// class MyApp extends StatelessWidget {
//   final PlayerController playerController;

//   const MyApp({super.key, required this.playerController});

//   @override
//   Widget build(BuildContext context) {
//     return MultiProvider(
//       providers: [
//         ChangeNotifierProvider<PlayerController>.value(value: playerController),
//         ChangeNotifierProvider<States>(create: (_) => States()),
//         ChangeNotifierProvider<AuthController>(
//           create: (_) => AuthController()..checkLoginStatus(),
//         ),
//       ],
//       child: MaterialApp(
//         theme: ThemeData(
//           textTheme: GoogleFonts.kanitTextTheme(Theme.of(context).textTheme),
//           scaffoldBackgroundColor: const Color.fromARGB(255, 34, 34, 34),
//         ),
//         debugShowCheckedModeBanner: false,
//         home: const AuthGate(),
//         routes: {
//           '/home': (_) => const Home(),
//           '/player': (_) => const PlayPause(),
//           '/settings': (_) => const Settings(),
//           '/library': (_) => const Library(),
//           '/addsongs': (_) => const Addsongs(),
//         },
//       ),
//     );
//   }
// }

// class AuthGate extends StatelessWidget {
//   const AuthGate({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Consumer<AuthController>(
//       builder: (context, auth, child) {
//         if (auth.isLoading) {
//           return const Scaffold(
//             backgroundColor: Color.fromARGB(255, 34, 34, 34),
//             body: Center(child: CircularProgressIndicator()),
//           );
//         }
//         return auth.token != null ? const Home() : const Login();
//       },
//     );
//   }
// }
