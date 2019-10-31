import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_nimsdk/flutter_nimsdk.dart';


void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  EventChannel eventChannel = EventChannel("flutter_nimsdk/Event/Channel", const StandardMethodCodec());
  // 初始化一个广播流从channel中接收数据，返回的Stream调用listen方法完成注册，需要在页面销毁时调用Stream的cancel方法取消监听
  StreamSubscription _streamSubscription;
  //创建 “ MethodChannel”这个名字要与原生创建时的传入值保持一致
  static const MethodChannel _methodChannelPlugin = const MethodChannel('flutter_nimsdk/Method/Channel');
  
  
  @override
  void initState() {
    super.initState();
    registerNIMSDK("8c2ed2ed508d1dacea2f0007852605ae");
    _streamSubscription = eventChannel.receiveBroadcastStream().listen(_onEvent, onError: _onError);
  }

  @override
  void dispose() {
    if (_streamSubscription != null) {
      _streamSubscription.cancel();
      _streamSubscription = null;
    }
    super.dispose();
  }

  // 数据接收
  void _onEvent(Object value) {
    print(value);
  }
  // 错误处理
  void _onError(dynamic) {
    print("on error");
  }


// 注册
  void registerNIMSDK(String appkey) async {
        SDKOptions sdkOptions = SDKOptions(appKey: appkey);
        await FlutterNimsdk.initSDK(sdkOptions);
            
  }
// 登录
  void login() {
    //  28   f51d1656315ac021d623f556dd493985
    LoginInfo loginInfo = LoginInfo(account: "28",token: "f51d1656315ac021d623f556dd493985");
    FlutterNimsdk.login(loginInfo).then((result) {
      print(result);
    });
  }

  // 自动登陆
  void autoLogin() async {

      LoginInfo loginInfo = LoginInfo(account: "28",token: "f51d1656315ac021d623f556dd493985");
      await FlutterNimsdk.autoLogin(loginInfo);
  }

  ///登出
  void logout() async {
    await FlutterNimsdk.logout();
  }

  /// 主叫发起通话请求
  void start() {
    NIMNetCallOption callOption = NIMNetCallOption(extendMessage: "extendMessage",apnsContent: "apnsContent",apnsSound: "apnsSound");
    FlutterNimsdk.start("", NIMNetCallMediaType.Video, callOption).then((result) {
        print(result);
    });
  }

  ///被叫响应通话请求
  void response() async {

    NIMResponse nimResponse = NIMResponse(callID: 0,accept: true);
    await _methodChannelPlugin.invokeMethod('response', nimResponse.toJson());
  }

  /// 挂断
  void hangup() async {
    await FlutterNimsdk.hangup(0);
  }

  /// 获取话单
  void records() {
    FlutterNimsdk.records().then((result){
      print(result);
    });
  }

  /// 清空本地话单
  void deleteRecords() async {
    await FlutterNimsdk.deleteAllRecords();
  }

  /// 动态设置摄像头开关
  void setCameraDisable() async {
    await FlutterNimsdk.setCameraDisable(false);
  }

  /// 动态切换摄像头
  void switchCamera() async {
    await FlutterNimsdk.switchCamera(NIMNetCallCamera.front);
  }

  /// 设置静音
  void setMute() async {
    await FlutterNimsdk.setMute(false);
  }
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Column(
            children: <Widget>[
              RaisedButton(
                onPressed: (){
                  this.login();
                  },
                child: Text("登陆"),
              ),
              RaisedButton(
                onPressed: () {
                  this.autoLogin();
                },
                child: Text("自动登陆"),
              ),
              RaisedButton(
                onPressed: () {
                  this.logout();
                },
                child: Text("登出"),
              ),
              RaisedButton(
                onPressed: () {
                  this.start();
                },
                child: Text("发起通话"),
              ),
              RaisedButton(
                onPressed: (){
                  this.response();
                },
                child: Text("向原生发送消息"),
              ),
              RaisedButton(
                onPressed: (){
                  this.hangup();
                },
                child: Text("挂断"),
              ),
              RaisedButton(
                onPressed: (){
                  this.records();
                },
                child: Text("获取话单"),
              ),
              RaisedButton(
                onPressed: (){
                  this.deleteRecords();
                },
                child: Text("清空话单"),
              ),
              RaisedButton(
                onPressed: (){
                  this.setCameraDisable();
                },
                child: Text("动态设置摄像头"),
              ),
              RaisedButton(
                onPressed: (){
                  this.switchCamera();
                },
                child: Text("动态切换摄像头"),
              ),
              RaisedButton(
                onPressed: (){
                  this.setMute();
                },
                child: Text("设置静音"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
