// import 'package:http/http.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:playground/webview_page.dart';
import 'package:geolocator/geolocator.dart';
import 'firebase_options.dart';


import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'inappwebview.dart';



final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

// push notification setting
final channel = const AndroidNotificationChannel(
  'high_importance_channel', // id
  'High Importance Notifications', // title
  description:
  'This channel is used for important notifications.', // description
  importance: Importance.high,
);


Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  await Firebase.initializeApp();

  print("Handling a background message: ${message.notification?.title}");
  if (message.notification != null) {
    print('Message also contained a notification: ${message.notification?.title} ${message.notification?.body}');
    flutterLocalNotificationsPlugin.show(
        message.hashCode,
        message.notification?.title,
        message.notification?.body,
        NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: const DarwinNotificationDetails (
              badgeNumber: 1,
              subtitle: 'the subtitle',
              sound: 'slow_spring_board.aiff',
            )));
  }
}



void main() async {
  // 웹 환경에서 카카오 로그인을 정상적으로 완료하려면 runApp() 호출 전 아래 메서드 호출 필요
  WidgetsFlutterBinding.ensureInitialized();

  // ***************************** firebase init *****************************
  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // var token = await FirebaseMessaging.instance.getToken();
  // print("firebase cloud message device token : ${token}");

  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  // // print('User granted permission: ${settings.authorizationStatus}');
  //
  // // foreground message
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');

    String notification = "";

    if (message.notification != null) {
      print('Message also contained a notification: ${message.notification?.title} ${message.notification?.body}');





      // flutterLocalNotificationsPlugin.show(
      //     message.hashCode,
      //     message.notification?.title,
      //     message.notification?.body,
      //     NotificationDetails(
      //         android: AndroidNotificationDetails(
      //           channel.id,
      //           channel.name,
      //           channelDescription: channel.description,
      //           icon: '@mipmap/ic_launcher',
      //         ),
      //         iOS: const DarwinNotificationDetails (
      //           badgeNumber: 1,
      //           subtitle: 'the subtitle',
      //           sound: 'slow_spring_board.aiff',
      //         )));


      // final SnackBar snackBar = SnackBar(content: Text("${message.notification?.title} : ${message.notification?.body}"));
      // snackbarKey.currentState?.showSnackBar(snackBar);



      notification = '"title":"${message.notification?.title}", "body":"${message.notification?.body}"';
    }



    final jsonEncoder = JsonEncoder();
    // webview.webViewController?.evaluateJavascript(source: """
    //                     writeFCM_data('${notification.isEmpty?"null":notification}, ${jsonEncoder.convert(message.data)}')
    //    """);

    if (message.data != null && message.data.isNotEmpty)
      webview.webViewController?.evaluateJavascript(source: """
                        window.fcmForegroundOnFlutterApp('${jsonEncoder.convert(message.data)}')
       """);

  });


  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
  // ***************************** firebase init *****************************

  // _determinePosition();


  // *****************************   kakao      ******************************

  // 웹 환경에서 카카오 로그인을 정상적으로 완료하려면 runApp() 호출 전 아래 메서드 호출 필요
  WidgetsFlutterBinding.ensureInitialized();

  // runApp() 호출 전 Flutter SDK 초기화
  KakaoSdk.init(nativeAppKey: '67fadb0c2e58144896ec4c10c5c2beb7');
  // *************************************************************************


  runApp( MyApp());
}

// InappWebviewScreen webview = InappWebviewScreen(init_url: "https://www.google.co.in/maps/",);
// InappWebviewScreen webview = InappWebviewScreen(init_url: "https://i8b309.p.ssafy.io/",);
InappWebviewScreen webview = InappWebviewScreen(api_gateway_url: "https://i8b309.p.ssafy.io", alwaysCleanCacheBeforeStart: true, debug_showURL: false,);
// InappWebviewScreen webview = InappWebviewScreen(init_url: "https://it-magician.github.io/test/bbb/",);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Playground',
      home: SafeArea(
        // child: const InappWebviewScreen(init_url: "https://map.kakao.com",),
        child: webview,
        // child: WebScreen(),
      )
    );
  }
}

