# flutter_nimsdk
用于`Flutter`的网易云信SDK
    
    
## 已完成功能
* 初始化  
* 登录
* 自动登录
* 登陆状态回调
* 登出
* 主动发起通话请求
* 接收到通话请求
* 被叫响应通话请求
* 主叫收到被叫响应回调
* 通话建立结果回调
* 挂断
* 收到对方结束通话回调
* 通话断开
* 获取话单
* 清空本地话单
* 动态设置摄像头开关
* 动态切换前后摄像头
* 设置静音
 

## 部分示例

### 初始化

使用前，先进行初始化：
      
```dart 

SDKOptions sdkOptions = SDKOptions(appKey: appkey);
await FlutterNimsdk.initSDK(sdkOptions);

```


### 登录

```dart
LoginInfo loginInfo = LoginInfo(account: "",token: "");
FlutterNimsdk.login(loginInfo).then((result) {
   print(result);
});

```

### 退出登录

```dart
await FlutterNimsdk.logout();
```



