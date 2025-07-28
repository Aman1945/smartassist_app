import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/services.dart';
import 'package:smartassist/config/environment/environment.dart';
import 'package:smartassist/config/route/route.dart';
import 'package:smartassist/config/route/route_name.dart';
import 'package:smartassist/services/notifacation_srv.dart';
import 'package:smartassist/services/socket_backgroundsrv.dart';
import 'package:smartassist/utils/connection_service.dart';
import 'package:smartassist/utils/testdrive_notification_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    await Environment.init();
    Environment.validateConfig();

    // Initialize background service early
    await NotificationHelper.setupNotificationChannels();
    await NotificationHelper.requestNotificationPermissions();
    await BackgroundService.initializeService();

    // Request necessary permissions
    await _requestPermissions();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitDown,
      DeviceOrientation.portraitUp,
    ]);

    print("Firebase initialized successfully!");
  } catch (e) {
    print("Initialization failed: $e");
  }

  await Hive.initFlutter();

  try {
    await NotificationService.instance.initialize();
    final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
    if (apnsToken != null) {
      print('🔔 APNs Token retrieved: $apnsToken');
    } else {
      print(
        '❌ APNs Token is null - make sure you are testing on a real iOS device',
      );
    }
    // Get FCM token
    final fcmToken = await FirebaseMessaging.instance.getToken();
    print('📱 FCM Token: $fcmToken');
  } catch (e) {
    print("Notification initialization failed: $e");
  }

  await ConnectionService().initialize();
  runApp(const ProviderScope(child: MyApp()));
}

Future<void> _requestPermissions() async {
  // Request location permissions including background location
  LocationPermission permission = await Geolocator.checkPermission();

  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.deniedForever) {
    print('Location permissions are permanently denied');
    return;
  }

  // For Android 10+ (API 29+), request background location permission
  if (permission == LocationPermission.whileInUse) {
    // Show dialog explaining why background location is needed
    permission = await Geolocator.requestPermission();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return GetMaterialApp(
          builder: (context, widget) {
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.0)),
              child: widget!,
            );
          },
          initialRoute: RoutesName.splashScreen,
          // home: ProfileScreen(), //remove this
          onGenerateRoute: Routes.generateRoute,
          theme: ThemeData(
            scaffoldBackgroundColor: const Color(0xFFFFFFFF),
            appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFFFFFFF)),
          ),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}


// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:get/get.dart';
// import 'package:hive_flutter/hive_flutter.dart';
// import 'package:flutter/services.dart';
// import 'package:smartassist/config/environment/environment.dart';
// import 'package:smartassist/config/route/route.dart';
// import 'package:smartassist/config/route/route_name.dart';
// import 'package:smartassist/services/notifacation_srv.dart';
// import 'package:smartassist/utils/connection_service.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();

//   try {
//     await Firebase.initializeApp(); 
//     await Environment.init();
//     Environment.validateConfig(); 
//     print("🔍 Environment loaded: ${Environment.googleMapsApiKey}");
//     SystemChrome.setPreferredOrientations([
//       DeviceOrientation.portraitDown,
//       DeviceOrientation.portraitUp,
//     ]);
//     print("Firebase initialized successfully!");
//   } catch (e) {
//     print("Firebase initialization failed: $e");
//   }

//   await Hive.initFlutter(); 
//   try {
//     await NotificationService.instance.initialize(); // Initialize Notifications
//     final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
//     if (apnsToken != null) {
//       print('🔔 APNs Token retrieved: $apnsToken');
//     } else {
//       print(
//         '❌ APNs Token is null - make sure you are testing on a real iOS device',
//       );
//     }
//     // Get FCM token
//     final fcmToken = await FirebaseMessaging.instance.getToken();
//     print('📱 FCM Token: $fcmToken');
//   } catch (e) {
//     print("Firebase initialization failed: $e");
//   }
//   // Initialize connection service
//   await ConnectionService().initialize();

//   runApp(const ProviderScope(child: MyApp()));
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return ScreenUtilInit(
//       designSize: const Size(375, 812),
//       minTextAdapt: true,
//       splitScreenMode: true,
//       builder: (context, child) {
//         return GetMaterialApp(
//           builder: (context, widget) {
//             return MediaQuery(
//               data: MediaQuery.of(
//                 context,
//               ).copyWith(textScaler: const TextScaler.linear(1.0)),
//               child: widget!,
//             );
//           },
//           initialRoute: RoutesName.splashScreen,
//           // home: ProfileScreen(), //remove this
//           onGenerateRoute: Routes.generateRoute,
//           theme: ThemeData(
//             scaffoldBackgroundColor: const Color(0xFFFFFFFF),
//             appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFFFFFFF)),
//           ),
//           debugShowCheckedModeBanner: false,
//         );
//       },
//     );
//   }
// }
