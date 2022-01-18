import 'dart:convert';
import 'dart:core';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:seerbit_flutter/models/payload.dart';
import 'package:seerbit_flutter/utilities/checkForPublicKey.dart';
import 'package:seerbit_flutter/utilities/initiateRequest.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SeerbitBottomSheet extends StatefulWidget {
  const SeerbitBottomSheet(
      {Key? key,
      required this.payload,
      this.onFailure,
      this.onSuccess,
      this.closeOnFinish = true})
      : super(key: key);

  final Function()? onSuccess;
  final Function()? onFailure;
  final bool closeOnFinish;
  final PayloadModel payload;

  @override
  _SeerbitBottomSheetState createState() => _SeerbitBottomSheetState();
}

class _SeerbitBottomSheetState extends State<SeerbitBottomSheet> {
  String currentUrl = '';
  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers =
      [Factory(() => EagerGestureRecognizer())].toSet();

  bool isInitialized = false;
  bool isLoading = false;
  String? mimeType = 'text/html';
  String response = 'Scales';
  String currentObject = '';
  String event = 'Events';
  bool isCancelled = false;
  late WebViewController webViewController;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) WebView.platform = SurfaceAndroidWebView();
    // if(Platform.isIOS) WebView.platform=WkWeb
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    return Container(
      height: height,
      width: width,
      child: Stack(
        children: [
          CircularProgressIndicator(),
          Column(
            children: [
              Flexible(
                child: Container(
                  height: height,
                  width: width,
                  color: Colors.white,
                  // padding: EdgeInsets.all(width * .07),
                  child: WebView(
                      gestureRecognizers: gestureRecognizers,
                      javascriptMode: JavascriptMode.unrestricted,
                      onWebViewCreated: (controller) => {
                            webViewController = controller,
                            setState(() => isInitialized = true)
                          },
                      javascriptChannels: Set.from([
                        JavascriptChannel(
                            name: 'Success',
                            onMessageReceived: (JavascriptMessage message) {
                              setState(() {
                                response =
                                    jsonDecode(message.message)['response'];

                                event = message.message.toString();
                              });

                              if (RegExp(
                                      r"^((ftp|http|https):\/\/)|www\.?([a-zA-Z]+)\.([a-zA-Z]{2,})\$\/")
                                  .hasMatch(response)) {
                                webViewController.loadUrl(response);
                              }
                            }),
                        JavascriptChannel(
                            name: 'Failure',
                            onMessageReceived: (JavascriptMessage message) {
                              setState(() {
                                response =
                                    jsonDecode(message.message)['response'];
                                event = message.message.toString();
                              });
                              if (jsonDecode(message.message)['event'] ==
                                  'cancelled') Navigator.pop(context);
                              if (RegExp(
                                      r"^((ftp|http|https):\/\/)|www\.?([a-zA-Z]+)\.([a-zA-Z]{2,})\$\/")
                                  .hasMatch(response)) {
                                webViewController.loadUrl(response);
                              }
                            })
                      ]),
                      navigationDelegate: (nav) {
                        return NavigationDecision.navigate;
                      },
                      onPageFinished: (_) {
                        setState(() {
                          mimeType = 'text/css';
                          isLoading = false;
                          webViewController.currentUrl().then(
                              (value) => currentObject = value.toString());
                        });
                      },
                      onPageStarted: (_) {
                        setState(() {
                          isLoading = true;
                          webViewController.currentUrl().then(
                              (value) => currentObject = value.toString());
                        });
                      },
                      onProgress: (_) {
                        setState(() => isLoading = true);
                      },
                      initialUrl: Uri.dataFromString(
                              initRequest(widget.payload, "==", ''),
                              encoding: Encoding.getByName('utf-8'),
                              mimeType: mimeType)
                          .toString()),
                ),
              ),
            ],
          ),
          IgnorePointer(
            child: Align(
                alignment: Alignment.bottomCenter,
                child: Text('Reponse:$event')),
          ),
          isInitialized
              ? Positioned.fill(
                  bottom: height * .06,
                  child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FutureBuilder<String?>(
                          future: webViewController.currentUrl(),
                          builder: (context, snapshot) {
                            return snapshot.data != null
                                ? Visibility(
                                    visible: containsPublicKey(
                                        snapshot.data!, widget.payload),
                                    child: TextButton(
                                        onPressed: () async => Future.delayed(
                                                Duration(milliseconds: 10),
                                                isSuccessful(snapshot.data!)
                                                    ? widget.onSuccess
                                                    : widget.onFailure)
                                            .then((value) =>
                                                widget.closeOnFinish
                                                    ? Navigator.pop(context)
                                                    : null),
                                        child: SizedBox(
                                          width: width * .8,
                                          height: height * .07,
                                          child: Material(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            child: Center(
                                              child: Text(
                                                'Close',
                                                style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: width * .05),
                                              ),
                                            ),
                                          ),
                                        )),
                                  )
                                : SizedBox();
                          })),
                )
              : SizedBox(),
          Center(child: isLoading ? CircularProgressIndicator() : Container()),
          Positioned(
            top: height * .05,
            left: width * .03,
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context)),
            ),
          )
        ],
      ),
    );
  }
}