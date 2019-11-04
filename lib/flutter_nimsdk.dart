import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'src/config.dart';
export 'src/config.dart';
import 'src/enum.dart';
export 'src/enum.dart';
import 'src/nim_session_model.dart';
export 'src/nim_session_model.dart';

class FlutterNimsdk {

  // static const MethodChannel _channel = const MethodChannel('flutter_nimsdk');

  // EventChannel eventChannel = EventChannel("flutter_nimsdk/Event/Channel", const StandardMethodCodec());
    // 初始化一个广播流从channel中接收数据，返回的Stream调用listen方法完成注册，需要在页面销毁时调用Stream的cancel方法取消监听
    StreamSubscription _streamSubscription;
    //创建 “ MethodChannel”这个名字要与原生创建时的传入值保持一致
    static const MethodChannel _methodChannelPlugin = const MethodChannel('flutter_nimsdk/Method/Channel');
  
  factory FlutterNimsdk() {
    if (_instance == null) {
      final MethodChannel methodChannel = const MethodChannel("flutter_nimsdk");
      final EventChannel eventChannel = const EventChannel('flutter_nimsdk/Event/Channel');
      _instance = FlutterNimsdk._private(methodChannel, eventChannel);
    }
    return _instance;
  }

  FlutterNimsdk._private(this._channel, this._eventChannel) {
    // _streamSubscription = _eventChannel.receiveBroadcastStream().listen(_onEvent, onError: _onError);
  }

  static FlutterNimsdk _instance;

  final MethodChannel _channel;
  final EventChannel _eventChannel;


  MethodChannel methodChannelPlugin() {
    return _methodChannelPlugin;
  }

  StreamSubscription streamSubscription() {
    return _streamSubscription;
  }

  EventChannel eventChannel() {
    return _eventChannel;
  }

  /// 初始化
  Future<void> initSDK(SDKOptions options) async {

    return await _channel.invokeMethod("initSDK", {"options": options.toJson()});
  }

  /// 登录
  Future<Map> login(LoginInfo loginInfo) async {    
    return await  _channel.invokeMethod("login",loginInfo.toJson());
  }
  
  /// 自动登录
  Future<void> autoLogin(LoginInfo loginInfo) async {
    return await _channel.invokeMethod("autoLogin",loginInfo.toJson());
  }

  /// 登出
  Future<void> logout() async {
    return await _channel.invokeMethod("logout");
  }

  /// 主叫发起通话请求
  Future<Map> start(String callees,NIMNetCallMediaType type,NIMNetCallOption option) async {
    String netCallMediaType = "video";
    if (type == NIMNetCallMediaType.Video) {
      netCallMediaType = "video";
    }else {
      netCallMediaType = "audio";
    }
    return await _channel.invokeMethod("start",{"callees":callees, "type": netCallMediaType, "option": option.toJson()});
  }

  /// 挂断
  Future<void> hangup(int callID) async {
    return await _channel.invokeMethod("hangup",{"callID": callID.toString()});
  }

  /// 获取话单
  Future<Map> records() async {
    return await _channel.invokeMethod("records");
  }

  /// 清空本地话单
  Future<void> deleteAllRecords() async {
    return await _channel.invokeMethod("deleteAllRecords");
  }

  /// 动态设置摄像头开关
  Future<void> setCameraDisable(bool disable) async {

    return await _channel.invokeMethod("setCameraDisable",{"disable": disable});
  }

   /// 动态设置摄像头开关
  Future<void> switchCamera(NIMNetCallCamera callCamera) async {

    String camera = "front";
    if (callCamera == NIMNetCallCamera.front) {
      camera = "front";
    } else {
      camera = "back";
    }
    return await _channel.invokeMethod("switchCamera",{"camera": camera});
  }

  /// 设置静音
  Future<void> setMute(bool mute) async {

    return await _channel.invokeMethod("setMute",{"mute": mute});
  }

  /// IM 
  /// 最近会话列表
  Future<Map> mostRecentSessions() async {

    return await _channel.invokeMethod("mostRecentSessions");
  }
  /// 获取所有最近会话
  Future<Map> allRecentSessions() async {

    return await _channel.invokeMethod("allRecentSessions");
  }

  ///发送文本消息
  Future<void> sendMessageText(String text,NIMSession nimSession) async {
    return await _channel.invokeMethod("sendTextMessage",{"message":text,"nimSession":nimSession.toJson()});
  }

  ///发送提示消息
  Future<void> sendMessageTip(String text,NIMSession nimSession) async {
    return await _channel.invokeMethod("sendTipMessage",{"message":text,"nimSession":nimSession.toJson()});
  }

  ///发送图片消息
  Future<void> sendMessageImage(String imagePath,NIMSession nimSession) async {
    return await _channel.invokeMethod("sendImageMessage",{"imagePath":imagePath,"nimSession":nimSession.toJson()});
  }

  ///发送视频消息
  Future<void> sendMessageVideo(String videoPath,NIMSession nimSession) async {
    return await _channel.invokeMethod("sendVideoMessage",{"videoPath":videoPath,"nimSession":nimSession.toJson()});
  }

  ///发送音频消息
  Future<void> sendMessageAudio(String audioPath,NIMSession nimSession) async {
    return await _channel.invokeMethod("sendAudioMessage",{"audioPath":audioPath,"nimSession":nimSession.toJson()});
  }

  ///发送文件消息
  Future<void> sendMessageFile(String filePath,NIMSession nimSession) async {
    return await _channel.invokeMethod("sendFileMessage",{"filePath":filePath,"nimSession":nimSession.toJson()});
  }

  ///发送位置消息
  Future<void> sendMessageLocation(NIMSession nimSession, NIMLocationObject locationObject) async {
    return await _channel.invokeMethod("sendLocationMessage",{"nimSession":nimSession.toJson(),"locationObject": locationObject.toJson()});
  }

  /// 会话内发送自定义消息
  Future<void> sendMessageCustom(NIMSession nimSession,Map customObject, {String apnsContent}) async {
    final String customEncodeString = json.encode(customObject);

    Map<String, dynamic> map = {
      "nimSession": nimSession.toJson(),
      "customEncodeString": customEncodeString,
      "apnsContent": apnsContent ?? "[自定义消息]",
    };

    return await _channel.invokeMethod("sendCustomMessage", map);
  }

  // 开始录音
  Future<void> onStartRecording(String sessionId) async {
    return await _channel.invokeMethod("onStartRecording",{"sessionId": sessionId});
  }

  // 结束录音
  Future<void> onStopRecording(String sessionId) async {
    return await _channel.invokeMethod("onStopRecording",{"sessionId": sessionId});
  }

  // 取消录音
  Future<void> onCancelRecording(String sessionId) async {
    return await _channel.invokeMethod("onCancelRecording",{"sessionId": sessionId});
  }

}
