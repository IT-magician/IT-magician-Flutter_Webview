import 'dart:collection';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:playground/page/error.dart';
import 'package:url_launcher/url_launcher.dart'; //
import 'dart:io'; // platform.android, platform.ios가 정의되어 있음.

import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:http/http.dart' as http;

import 'component/back_pressed.dart';


class InappWebviewScreen extends StatefulWidget {
  final String api_gateway_url;
  InAppWebViewController? webViewController;

  InappWebviewScreen({Key? key, required this.api_gateway_url}) : super(key: key);

  @override
  State<InappWebviewScreen> createState() => _InappWebview();
}



class _InappWebview extends State<InappWebviewScreen> {
  static final storage = FlutterSecureStorage();

  final GlobalKey webViewKey = GlobalKey();
  String ?access_token;

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
    print("firebase cloud message device token : ${token} (will be saved)");
    String? access_token = await getAccess_token();

    if (access_token == null || access_token.isEmpty) return;

    try {

      final jsonEncoder = JsonEncoder();

      // 여기에 access_token, fcm_token을 rest api로 등록 요청 로직 짜야함
      String url = "${widget.api_gateway_url}/user/update";
      http.Response response = await http.post(
          Uri.parse(url),
          headers: <String, String> {
            "Content-Type": "application/json",
            'Authorization' : 'Bearer ' + access_token,
          },
          body: jsonEncoder.convert({
            'mobile_fcm_token' : token,
          })
      );

      print("saveTokenToDatabase rest api result code : ${response.statusCode}");
    }
    catch (e) {
      print("saveTokenToDatabase error : ${e}");
    }
  }

  Future<void> setupToken() async {
    // Get the token each time the application loads
    String? token = await FirebaseMessaging.instance.getToken();

    // Save the initial token to the database
    saveTokenToDatabase(token!);

    // Any time the token refreshes, store this in the database too.
    FirebaseMessaging.instance.onTokenRefresh.listen(saveTokenToDatabase);
  }

  // 0 - Everything is ok, 1 - http or other error fixed
  int _errorCode = 0;
  final BackPressed _backPressed = BackPressed();
  bool _isLoading = false, _isVisible = false, _isOffline = false;
  Future<void> checkError() async {
    //Hide CircularProgressIndicator
    _isLoading = false;

    //Check Network Status
    ConnectivityResult result = await Connectivity().checkConnectivity();

    //if Online: hide offline page and show web page
    if (result != ConnectivityResult.none) {
      if (_isOffline == true) {
        _isVisible = false; //Hide Offline Page
        _isOffline = false; //set Page type to error
      }
    }

    //If Offline: hide web page show offline page
    else {
      _errorCode = 0;
      _isOffline = true; //Set Page type to offline
      _isVisible = true; //Show offline page
    }

    // If error is fixed: hide error page and show web page
    if (_errorCode == 1) _isVisible = false;
    setState(() {});
  }

  Future<void> saveAccess_token(String access_token) async {
    storage.write(key: "access_token_for_app", value: access_token);
  }

  Future<String?> getAccess_token() async {
    String? access_token = await storage.read(key: "access_token_for_app");
    // print("access_token_for_app : ${access_token}");
    return access_token;
  }

  @override
  void initState() {
    super.initState();

    // saveAccess_token("NzRlMGM5NmUtNTAyZS00MDRhLWJlYjQtZDI5Y2NkMzAwOTU1");
    setupToken();

    pullToRefreshController = PullToRefreshController(
      options: PullToRefreshOptions(
        color: Colors.blue,
      ),
      onRefresh: () async {
        widget.webViewController?.reload();
        if (Platform.isAndroid) {
          widget.webViewController?.reload();
          print("it's android");
        } else if (Platform.isIOS) {
          widget.webViewController?.loadUrl(
              urlRequest: URLRequest(url: await widget.webViewController?.getUrl()));
          print("it's ios");
        }
      },
    );

  }

  @override
  void dispose() {
    super.dispose();
  }




  @override
  Widget build(BuildContext context) {
    return WillPopScope(child: Scaffold(
        body: SafeArea(
            child: Stack(
              alignment: Alignment.center,
              children: [
                InAppWebView(
                  // androidOnGeolocationPermissionsShowPrompt:
                  key: webViewKey,
                  initialUrlRequest:
                  URLRequest(url: Uri.parse(widget.api_gateway_url)),
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
                    widget.webViewController = controller;

                    controller.addJavaScriptHandler(handlerName: "setAccess_token", callback: (args) async {
                      print("flutter!!!!!!!!!!! : ${args}");
                      await saveAccess_token(args[0]);


                      // Get the token each time the application loads
                      String? token = await FirebaseMessaging.instance.getToken();

                      // Save the initial token to the database
                      saveTokenToDatabase(token!);
                    });
                  },
                  initialUserScripts: UnmodifiableListView<UserScript>([
                    UserScript(
                        source: """
                                window.isFluttApp = true
                                window.setAccess_tokenOnFlutterApp = (...args) => window.flutter_inappwebview.callHandler('setAccess_token', ...args);
                                """, injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START),
                    // UserScript(
                    //     source: """
                    //       window.setAccess_token = (...args) => window.flutter_inappwebview.callHandler('setAccess_token', ...args);
                    //       window.isFluttApp = true
                    //
                    //       console.log('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!')
                    //       """,
                    //     injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END),
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
                    checkError(); //Check Error type: offline or other error
                    // setState(() {
                    //   this.url = url.toString();
                    //   urlController.text = this.url;
                    // });



                  },
                  onLoadError: (controller, url, code, message) {
                    // pullToRefreshController.endRefreshing();
                    // Show
                    print("onLoadError url : ${url}");
                    _errorCode = code;
                    _isVisible = true;
                  },
                  onLoadHttpError: (controller, url, statusCode, description) {
                    print("onLoadHttpError url : ${url}");
                    _errorCode = statusCode;
                    _isVisible = true;
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

                ),

                //Error Page
                Visibility(
                  visible: _isVisible,
                  child: ErrorScreen(
                      isOffline: _isOffline,
                      onPressed: () {
                        widget.webViewController!.reload();
                        if (_errorCode != 0) {
                          _errorCode = 1;
                        }
                      }),
                ),
              ],
            )
        )
    ),






        onWillPop: () async {
      //If website can go back page
      if (await widget.webViewController!.canGoBack()) {
    await widget.webViewController!.goBack();
    return false;
    } else {
    //Double pressed to exit app
    return _backPressed.exit(context);
    }
  });
  }

  void requestPermission() async {
    Map<Permission, PermissionStatus> statuses = await [Permission.location].request();
  }
}

