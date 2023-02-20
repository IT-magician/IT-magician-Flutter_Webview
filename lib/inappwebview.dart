import 'dart:collection';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart'; //
import 'dart:io'; // platform.android, platform.ios가 정의되어 있음.

import 'package:http/http.dart' as http;


class InappWebviewScreen extends StatefulWidget {
  final String init_url;

  const InappWebviewScreen({Key? key, required this.init_url}) : super(key: key);

  @override
  State<InappWebviewScreen> createState() => _InappWebview();
}



class _InappWebview extends State<InappWebviewScreen> {

  final GlobalKey webViewKey = GlobalKey();
  String ?access_token;

  InAppWebViewController? webViewController;
  InAppWebViewGroupOptions options = InAppWebViewGroupOptions(
      crossPlatform: InAppWebViewOptions(
        useShouldOverrideUrlLoading: true,
        mediaPlaybackRequiresUserGesture: false,
      ),
      android: AndroidInAppWebViewOptions(
        useHybridComposition: true,
      ),
      ios: IOSInAppWebViewOptions(
        allowsInlineMediaPlayback: true,
      ));

  late PullToRefreshController pullToRefreshController;
  String url = "";
  double progress = 0;
  final urlController = TextEditingController();


  Future<void> saveTokenToDatabase(String token) async {
    print("firebase cloud message device token : ${token}");

    // 여기에 access_token, fcm_token을 rest api로 등록 요청 로직 짜야함
  }

  Future<void> setupToken() async {
    // Get the token each time the application loads
    String? token = await FirebaseMessaging.instance.getToken();

    // Save the initial token to the database
    saveTokenToDatabase(token!);

    // Any time the token refreshes, store this in the database too.
    FirebaseMessaging.instance.onTokenRefresh.listen(saveTokenToDatabase);
  }


  Future<void> aaaaaaaaaaaaaaaaaaaaaa() async {

    // https://jellybeanz.medium.com/how-to-use-flutters-rest-api-f2658b4336cc
    http.Response response = await http.get(
        Uri.parse("https://i8b309.p.ssafy.io/oauth2/hello")
        , headers: {}
    );
    print(response.body);
  }

  @override
  void initState() {
    super.initState();

    setupToken();

    pullToRefreshController = PullToRefreshController(
      options: PullToRefreshOptions(
        color: Colors.blue,
      ),
      onRefresh: () async {
        webViewController?.reload();
        if (Platform.isAndroid) {
          webViewController?.reload();
          print("it's android");
        } else if (Platform.isIOS) {
          webViewController?.loadUrl(
              urlRequest: URLRequest(url: await webViewController?.getUrl()));
          print("it's ios");
        }
      },
    );

    aaaaaaaaaaaaaaaaaaaaaa();
  }

  @override
  void dispose() {
    super.dispose();
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
          child: InAppWebView(
            // androidOnGeolocationPermissionsShowPrompt:
            key: webViewKey,
            initialUrlRequest:
            URLRequest(url: Uri.parse(widget.init_url)),
            // URLRequest(url: Uri.parse("https://www.google.co.in/maps/")),
            // URLRequest(url: Uri.parse("https://map.kakao.com")),
            //   URLRequest(url: Uri.parse("https://map.naver.com/")),
            // URLRequest(url: Uri.parse("https://it-magician.github.io/test/")),
            //   URLRequest(url: Uri.parse("https://i8b309.p.ssafy.io")),
            // URLRequest(url: Uri.parse("https://it-magician.github.io/test/ccc")),
            initialOptions: options,
            pullToRefreshController: pullToRefreshController,
            onWebViewCreated: (controller) {
              controller.clearCache();
              webViewController = controller;

              controller.addJavaScriptHandler(handlerName: "setAccess_token", callback: (args) {
                print(args);
              });
            },
            initialUserScripts: UnmodifiableListView<UserScript>([
              // UserScript(
              //     source: """
              //             var isFlutterApp = `yes, I'm Flutter`;
              //
              //             window.setAccess_token = (...args) => window.flutter_inappwebview.callHandler('setAccess_token', ...args);
              //             """, injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START),
              UserScript(
                  source: """
                          window.setAccess_token = (...args) => window.flutter_inappwebview.callHandler('setAccess_token', ...args); 
                          """,
                  injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END),
            ]),
            onLoadStart: (controller, url) async {
              setState(() {
                this.url = url.toString();
                urlController.text = this.url;
              });

              var fcm_token = await FirebaseMessaging.instance.getToken();
              await controller.evaluateJavascript(source: 'const test = ${fcm_token};');

              var result = await controller.evaluateJavascript(source: 'const test = "aaa";');
            },
            androidOnPermissionRequest: (controller, origin, resources) async {
              return PermissionRequestResponse(
                  resources: resources,
                  action: PermissionRequestResponseAction.GRANT);
            },
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              var uri = navigationAction.request.url!;

              if (![ "http", "https", "file", "chrome",
                "data", "javascript", "about"].contains(uri.scheme)) {
                if (await canLaunchUrl(Uri.parse(url))) {
                  // Launch the App
                  await launchUrl(
                    Uri.parse(url),
                  );
                  // and cancel the request
                  return NavigationActionPolicy.CANCEL;
                }
              }

              return NavigationActionPolicy.ALLOW;
            },
            onLoadStop: (controller, url) async {
              // await controller.evaluateJavascript(source: """
              // const isFlutterApp = `yes, I'm Flutter`;
              // """);


              pullToRefreshController.endRefreshing();
              setState(() {
                this.url = url.toString();
                urlController.text = this.url;
              });

              // await controller.evaluateJavascript(source: """"
              //   window.setAccess_token = (...args) => window.flutter_inappwebview.callHandler('setAccess_token', ...args);
              //
              //   window.flutter_inappwebview.callHandler('setAccess_token', 'hi, taehun');
              // """);


            },
            onLoadError: (controller, url, code, message) {
              pullToRefreshController.endRefreshing();
            },
            onProgressChanged: (controller, progress) {
              if (progress == 100) {
                pullToRefreshController.endRefreshing();
              }
              setState(() {
                this.progress = progress / 100;
                urlController.text = this.url;
              });
            },
            onUpdateVisitedHistory: (controller, url, androidIsReload) {
              setState(() {
                this.url = url.toString();
                urlController.text = this.url;
              });
            },
            onConsoleMessage: (controller, consoleMessage) {
              print(consoleMessage);
            },
            androidOnGeolocationPermissionsShowPrompt: (InAppWebViewController controller, String origin) async {
                // return Future.value(GeolocationPermissionShowPromptResponse(
                //     origin: origin, allow : true, retain : true));









  bool serviceEnabled;
  LocationPermission permission;

  // Test if location services are enabled.
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    // Location services are not enabled don't continue
    // accessing the position and request users of the
    // App to enable the location services.
    // return Future.error('Location services are disabled.');

    // showAlertDialog_for_geoPermission(context);

    return Future.value(GeolocationPermissionShowPromptResponse(
        origin: origin, allow : false, retain : false));
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      // Permissions are denied, next time you could try
      // requesting permissions again (this is also where
      // Android's shouldShowRequestPermissionRationale
      // returned true. According to Android guidelines
      // your App should show an explanatory UI now.
      // return Future.error('Location permissions are denied');


      // showAlertDialog_for_geoPermission(context);

      // set up the AlertDialog
      AlertDialog alert = AlertDialog(
        title: Text("경고"),
        content: const Text("GPS 권한을 허용하지 않으면, 지도 기능을 제대로 볼 수 없습니다.\n\n권한을 허용해주세요."),
        actions: [
          // continueButton,
        ],
      );

      // show the dialog
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return alert;
        },
      );


      return Future.value(GeolocationPermissionShowPromptResponse(
          origin: origin, allow : false, retain : false));
    }
  }

  if (permission == LocationPermission.deniedForever) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      // return Future.error(
      //     'Location permissions are permanently denied, we cannot request permissions.');

      // showAlertDialog_for_geoPermission(context);

      return Future.value(GeolocationPermissionShowPromptResponse(
          origin: origin, allow : false, retain : false));
    }
  }












  return Future.value(GeolocationPermissionShowPromptResponse(
      origin: origin, allow : true, retain : true));



            },
            onLoadHttpError: (controller, url, statusCode, description) {
              print("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb");
            },

          ),)
    );
  }

  void requestPermission() async {
    Map<Permission, PermissionStatus> statuses =
    await [Permission.location].request();
  }
}








/*
*
*
*
*
                androidOnGeolocationPermissionsShowPrompt:
                    (InAppWebViewController controller, String origin) async {
                  bool result = await showDialog<bool>(
                    context: context,
                    barrierDismissible: false, // user must tap button!
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text('Allow access location $origin'),
                        content: SingleChildScrollView(
                          child: ListBody(
                            children: <Widget>[
                              Text('Allow access location $origin'),
                            ],
                          ),
                        ),
                        actions: <Widget>[
                          TextButton(
                            child: Text('Allow'),
                            onPressed: () {
                              Navigator.of(context).pop(true);
                            },
                          ),
                          TextButton(
                            child: Text('Denied'),
                            onPressed: () {
                              Navigator.of(context).pop(false);
                            },
                          ),
                        ],
                      );
                    },
                  );
                  if (result) {
                    return Future.value(GeolocationPermissionShowPromptResponse(
                        origin: origin, allow: true, retain: true));
                  } else {
                    return Future.value(GeolocationPermissionShowPromptResponse(
                        origin: origin, allow: false, retain: false));
                  }
                },
*
*
*
* */

