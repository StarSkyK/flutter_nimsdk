import 'dart:async';

import 'package:flutter/services.dart';
import 'src/config.dart';
export 'src/config.dart';
import 'src/enum.dart';
export 'src/enum.dart';

class FlutterNimsdk {

  static const MethodChannel _channel = const MethodChannel('flutter_nimsdk');

  /// 初始化
  static Future<void> initSDK(SDKOptions options) async {
    return await _channel.invokeMethod("initSDK", {"options": options.toJson()});
  }

  /// 登录
  static Future<Map> login(LoginInfo loginInfo) async {    
    return await  _channel.invokeMethod("login",loginInfo.toJson());
  }
  
  /// 自动登录
  static Future<void> autoLogin(LoginInfo loginInfo) async {
    return await _channel.invokeMethod("autoLogin",loginInfo.toJson());
  }

  /// 登出
  static Future<void> logout() async {
    return await _channel.invokeMethod("logout");
  }

  /// 主叫发起通话请求
  static Future<Map> start(String callees,NIMNetCallMediaType type,NIMNetCallOption option) async {
    String netCallMediaType = "video";
    if (type == NIMNetCallMediaType.Video) {
      netCallMediaType = "video";
    }else {
      netCallMediaType = "audio";
    }
    return await _channel.invokeMethod("start",{"callees":callees, "type": netCallMediaType, "option": option.toJson()});
  }

  /// 挂断
  static Future<void> hangup(int callID) async {
    return await _channel.invokeMethod("hangup",{"callID": callID.toString()});
  }

  /// 获取话单
  static Future<Map> records() async {
    return await _channel.invokeMethod("records");
  }

  /// 清空本地话单
  static Future<void> deleteAllRecords() async {
    return await _channel.invokeMethod("deleteAllRecords");
  }

  /// 动态设置摄像头开关
  static Future<void> setCameraDisable(bool disable) async {

    return await _channel.invokeMethod("setCameraDisable",{"disable": disable});
  }

   /// 动态设置摄像头开关
  static Future<void> switchCamera(NIMNetCallCamera callCamera) async {

    String camera = "front";
    if (callCamera == NIMNetCallCamera.front) {
      camera = "front";
    } else {
      camera = "back";
    }
    return await _channel.invokeMethod("switchCamera",{"camera": camera});
  }

  /// 设置静音
  static Future<void> setMute(bool mute) async {

    return await _channel.invokeMethod("setMute",{"mute": mute});
  }

}
