#import "FlutterNimsdkPlugin.h"
#import <flutter_nimsdk/flutter_nimsdk-Swift.h>
#import <NIMSDK/NIMSDK.h>
#import <NIMAVChat/NIMAVChat.h>

@interface FlutterNimsdkPlugin()<NIMLoginManagerDelegate,FlutterStreamHandler,NIMNetCallManagerDelegate>

@property(nonatomic) FlutterEventSink eventSink;
@property(nonatomic, strong) FlutterMethodChannel *methodChannel;

@end

static NSString *const kEventChannelName = @"flutter_nimsdk/Event/Channel";
static NSString *const kMethodChannelName = @"flutter_nimsdk/Method/Channel";

@implementation FlutterNimsdkPlugin
//+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
//  [SwiftFlutterNimsdkPlugin registerWithRegistrar:registrar];
//}


+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"flutter_nimsdk"
                                     binaryMessenger:[registrar messenger]];
    FlutterNimsdkPlugin* instance = [[FlutterNimsdkPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
    
    // 初始化FlutterEventChannel对象
    FlutterEventChannel *eventChannel = [FlutterEventChannel eventChannelWithName: kEventChannelName binaryMessenger: [registrar messenger]];
    [eventChannel setStreamHandler: instance];
    
    [instance initChannel:[registrar messenger]];
}

///处理 flutter 向 native 发送的一些消息
- (void)initChannel:(NSObject<FlutterBinaryMessenger> *)messenger {
    
    self.methodChannel = [FlutterMethodChannel methodChannelWithName:kMethodChannelName binaryMessenger:messenger];
    [self.methodChannel setMethodCallHandler:^(FlutterMethodCall * _Nonnull call, FlutterResult  _Nonnull result) {
        if ([call.method isEqualToString:@"response"]) {//调用哪个方法
            
            NSLog(@"%@------%@",call.method,call.arguments);
            
            //初始化option
            NIMNetCallOption *option = [[NIMNetCallOption alloc] init];
            
            //指定 option 中的 videoCaptureParam 参数
            NIMNetCallVideoCaptureParam *param = [[NIMNetCallVideoCaptureParam alloc] init];
            option.videoCaptureParam = param;
            
            [[NIMAVChatSDK sharedSDK].netCallManager response:0 accept:YES option:option completion:^(NSError * _Nullable error, UInt64 callID) {
                
                //链接成功
                if (!error) {
                    
                    result(nil);
                }else{//链接失败
                    
                    NSDictionary *dic = @{@"callID": [NSNumber numberWithInteger:callID],@"msg": @"响应呼叫结果"};
                    result(dic);
                }
            }];
            result([NSString stringWithFormat:@"MethodChannel:收到Dart消息：%@",call.arguments]);
        }
    }];
}

    
- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    
    if ([@"initSDK" isEqualToString:call.method]) {// 初始化
        
        NSDictionary *dict = call.arguments;
        
        NSDictionary *optionDict = dict[@"options"];
        NSString *appKey = optionDict[@"appKey"];
        if (appKey==nil || [appKey isEqual:[NSNull null]] || [appKey isEqualToString:@""]) {
            result([FlutterError errorWithCode:@"ERROR"
                                       message:@"appKey is null"
                                       details:nil]);
            return;
        }
        NIMSDKOption *option = [NIMSDKOption optionWithAppKey:appKey];
        
        id pushConfigDict = optionDict[@"mixPushConfig"];
        //CerName 为开发者为推送证书在云信管理后台定义的名字，在使用中，云信服务器会寻找同名推送证书发起苹果推送服务。
        //目前 CerName 可传 APNs 证书 和 Voip 证书两种，分别对应了参数中 apnsCername 和 pkCername 两个字段。
        if (pushConfigDict!=nil&&[pushConfigDict isEqual:[NSNull null]]&&[pushConfigDict isKindOfClass:[NSDictionary class]]) {
            option.apnsCername = pushConfigDict[@"apnsCername"];
            option.pkCername = pushConfigDict[@"pkCername"];
        }
        
        [[NIMSDK sharedSDK] registerWithOption: option];
        
        //为了更好的应用体验，SDK 需要对应用数据做一些本地持久，比如消息，用户信息等等。在默认情况下，所有数据将放置于 $Document/NIMSDK 目录下。
        //设置该值后 SDK 产生的数据(包括聊天记录，但不包括临时文件)都将放置在这个目录下
        
        [self getValue:optionDict key:@"sdkStorageRootPath" :^(id result) {
            [[NIMSDKConfig sharedConfig] setupSDKDir:result];
        }];
        
        //是否在收到消息后自动下载附件
        BOOL preloadAttach = [optionDict[@"preloadAttach"] boolValue];
        [NIMSDKConfig sharedConfig].fetchAttachmentAutomaticallyAfterReceiving = preloadAttach;
        [NIMSDKConfig sharedConfig].fetchAttachmentAutomaticallyAfterReceivingInChatroom = preloadAttach;
        
        //是否需要将被撤回的消息计入未读计算考虑
        [self getValue:optionDict key:@"shouldConsiderRevokedMessageUnreadCount" :^(id result) {
            [NIMSDKConfig sharedConfig].shouldConsiderRevokedMessageUnreadCount = [result boolValue];
        }];
        
        //是否需要多端同步未读数
        BOOL shouldSyncUnreadCount = [optionDict[@"sessionReadAck"] boolValue];
        [NIMSDKConfig sharedConfig].shouldSyncUnreadCount = shouldSyncUnreadCount;
        
        //是否将群通知计入未读
        BOOL shouldCountTeamNotification = [optionDict[@"teamNotificationMessageMarkUnread"] boolValue];
        [NIMSDKConfig sharedConfig].shouldCountTeamNotification = shouldCountTeamNotification;
        
        //是否支持动图缩略
        BOOL animatedImageThumbnailEnabled = [optionDict[@"animatedImageThumbnailEnabled"] boolValue];
        [NIMSDKConfig sharedConfig].animatedImageThumbnailEnabled = animatedImageThumbnailEnabled;
        
        //客户端自定义信息，用于多端登录时同步该信息
        [self getValue:optionDict key:@"customTag" :^(id result) {
            [NIMSDKConfig sharedConfig].customTag = result;
        }];
        
        result(nil);
    }else if([@"login" isEqualToString: call.method]){// 登陆
        
        NSDictionary *args = call.arguments;
        NSString *account = args[@"account"];
        NSString *token = args[@"token"];
        [[[NIMSDK sharedSDK] loginManager] addDelegate:self];
        [[[NIMSDK sharedSDK] loginManager]login:account token:token completion:^(NSError * _Nullable error) {

            NSLog(@"请求结果：%@",error);
            if (error == nil) {
                result(nil);
            }else{
                
                NSString *msg = error.userInfo[@"NSLocalizedDescription"] == nil ? @"" : error.userInfo[@"NSLocalizedDescription"];
                NSDictionary *dic = @{@"code": [NSNumber numberWithInteger:error.code],@"msg": [NSString stringWithFormat:@"%@",msg]};
                result(dic);
            }
        }];

        
    }else if([@"autoLogin" isEqualToString: call.method]){ // 自动登陆
        
        
        NSDictionary *args = call.arguments;
        NSString *account = args[@"account"];
        NSString *token = args[@"token"];

        NIMAutoLoginData *loginData = [[NIMAutoLoginData alloc] init];
        loginData.account = account;
        loginData.token = token;
        [[[NIMSDK sharedSDK] loginManager] addDelegate:self];
        [[[NIMSDK sharedSDK] loginManager] autoLogin:loginData];
        

        
    }else if ([@"logout" isEqualToString: call.method]) { //登出
        
        [[[NIMSDK sharedSDK] loginManager] logout:^(NSError *error) {
            //jump to login page
        }];
        
    } else if([@"start" isEqualToString: call.method]){ // 发起通话
        
        NSDictionary *args = call.arguments;
        NSString *callees = args[@"callees"];
        NIMNetCallMediaType nimNetCallMediaType = NIMNetCallMediaTypeVideo;
        NSString *type = args[@"type"];
        if ([type isEqualToString: @"video"]) {
            nimNetCallMediaType = NIMNetCallMediaTypeVideo;
        }else {
            nimNetCallMediaType = NIMNetCallMediaTypeAudio;
        }
        NIMNetCallOption *option = [[NIMNetCallOption alloc] init];
        option.extendMessage = args[@"options"][@"extendMessage"];
        option.apnsContent = args[@"options"][@"apnsContent"];
        option.apnsSound = args[@"options"][@"apnsSound"] == nil ? @"video_chat_tip_receiver.aac" : args[@"options"][@"apnsSound"];

        //开始通话
        [[[NIMAVChatSDK sharedSDK] netCallManager] addDelegate:self];
        [[NIMAVChatSDK sharedSDK].netCallManager start:@[callees] type:nimNetCallMediaType option:option completion:^(NSError *error, UInt64 callID) {
            if (!error) {
                    //通话发起成功
                
                result(nil);
                
            }else{
                    //通话发起失败
                NSDictionary *dic = @{@"callID": [NSNumber numberWithInteger:callID],@"msg": @"通话发起失败"};
                result(dic);
            }
        }];
        
    } else if ([@"hangup" isEqualToString:call.method]) { //挂断
        
        NSDictionary *args = call.arguments;
        NSString *callID_str = args[@"callID"];
        int callID = callID_str == nil ? 0 : callID_str.intValue;
        //挂断电话
        [[NIMAVChatSDK sharedSDK].netCallManager hangup:callID];
        
    }else if ([@"records" isEqualToString:call.method]) { // 获取话单
        
        NIMNetCallRecordsSearchOption *searchOption = [[NIMNetCallRecordsSearchOption alloc] init];
        searchOption.timestamp = [[NSDate date] timeIntervalSince1970];
        
        [[NIMAVChatSDK sharedSDK].netCallManager recordsWithOption:nil completion:^(NSArray<NIMMessage *> * _Nullable records, NSError * _Nullable error) {
            
            if (!error) {
                NSMutableArray *recordArray = [NSMutableArray array];
                for (NIMMessage *msg in records) {
                    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
                    [dict setObject:msg.messageId forKey:@"messageId"];
                    [dict setObject:[NSNumber numberWithInteger:msg.messageType] forKey:@"messageType"];
                    [recordArray addObject:dict];
                }
                NSDictionary *dic = @{@"records": recordArray};
                result(dic);
            }else {
                NSString *msg = error.userInfo[@"NSLocalizedDescription"] == nil ? @"获取话单失败" : error.userInfo[@"NSLocalizedDescription"];
                NSDictionary *dic = @{@"error": msg, @"errorCode": [NSNumber numberWithInteger:error.code]};
                result(dic);
            }
        }];
        
    } else if ([@"deleteAllRecords" isEqualToString:call.method]) {//清空点对点通话记录
        
        [[NIMAVChatSDK sharedSDK].netCallManager deleteAllRecords];
    } else if ([@"setCameraDisable" isEqualToString:call.method]) {//动态设置摄像头开关
        
        NSDictionary *args = call.arguments;
        BOOL isDisable = args[@"disable"];
        //打开摄像头 false    关闭摄像头  true
        [[NIMAVChatSDK sharedSDK].netCallManager setCameraDisable:isDisable];
        
    }else if ([@"switchCamera" isEqualToString:call.method]) {//动态切换摄像头前后
        
        NSDictionary *args = call.arguments;
        NSString *camera = args[@"camera"];
        NIMNetCallCamera position = NIMNetCallCameraFront;
        if ([camera isEqualToString:@"front"]) {
            position = NIMNetCallCameraFront;
        } else {
            position = NIMNetCallCameraBack;
        }
        [[NIMAVChatSDK sharedSDK].netCallManager switchCamera:position];
        
    }else if ([@"setMute" isEqualToString:call.method]) {//动态设置摄像头开关
        
        NSDictionary *args = call.arguments;
        BOOL isMute = args[@"mute"];
        //开启静音 YES  关闭静音 No
        [[NIMAVChatSDK sharedSDK].netCallManager setMute:isMute];
        
    } else {
        result(FlutterMethodNotImplemented);
    }
}

// MARK: - NIMLoginManagerDelegate
- (void)onLogin:(NIMLoginStep)step {
    
    if (self.eventSink) {
        self.eventSink(@{@"delegate": @"NIMLoginManagerDelegate",@"step": [NSNumber numberWithInteger:step]});
    }
}

// MARK: - FlutterStreamHandler
- (FlutterError* _Nullable)onListenWithArguments:(id _Nullable)arguments
                                       eventSink:(FlutterEventSink)eventSink{
    self.eventSink = eventSink;
    return nil;
}

- (FlutterError* _Nullable)onCancelWithArguments:(id _Nullable)arguments {
    return nil;
}


// MARK: - NIMNetCallManagerDelegate
//被叫收到呼叫
- (void)onReceive:(UInt64)callID from:(NSString *)caller type:(NIMNetCallMediaType)type message:(NSString *)extendMessage {
    if (self.eventSink) {
        NSDictionary *dic = @{@"delegate": @"NIMNetCallManagerDelegate",
                              @"callID": [NSNumber numberWithInteger:callID],
                              @"caller": caller,
                              @"type": [NSNumber numberWithInteger:type],
                              @"extendMessage": extendMessage};
        self.eventSink(dic);
    }
}

//主叫收到被叫响应
- (void)onResponse:(UInt64)callID from:(NSString *)callee accepted:(BOOL)accepted {
    
    if (self.eventSink) {
        
        NSDictionary *dic = @{@"delegate": @"NIMNetCallManagerDelegate",
                              @"accepted": [NSNumber numberWithBool:accepted]};
        self.eventSink(dic);
    }
    
}

//通话建立成功回调
- (void)onCallEstablished:(UInt64)callID {
    
    //通话建立成功 开始计时 刷新UI
    
    if (self.eventSink) {
        
        NSDictionary *dic = @{@"delegate": @"NIMNetCallManagerDelegate",
                              @"callID": [NSNumber numberWithInteger:callID]};
        self.eventSink(dic);
    }
}

//收到对方挂断电话
- (void)onHangup:(UInt64)callID by:(NSString *)user {
    
    if (self.eventSink) {
        
        NSDictionary *dic = @{@"delegate": @"NIMNetCallManagerDelegate",
                              @"callID": [NSNumber numberWithInteger:callID],
                              @"user": user};
        self.eventSink(dic);
    }
}

//通话异常断开回调
/**
 通话异常断开
 
 @param callID call id
 @param error 断开的原因，如果是 nil 表示正常退出
 */
- (void)onCallDisconnected:(UInt64)callID withError:(NSError *)error {
    
    if (self.eventSink) {
        
        NSString *msg = error.userInfo[@"NSLocalizedDescription"] == nil ? @"通话异常" : error.userInfo[@"NSLocalizedDescription"];
        NSDictionary *dic = @{@"delegate": @"NIMNetCallManagerDelegate",
                              @"callID": [NSNumber numberWithInteger:callID],
                              @"error": msg};
        self.eventSink(dic);
    }
}


    
-(void)getValue:(NSDictionary*)dict key:(NSString*) key :(void(^)(id result))block{
    id value = dict[key];
    if (value==nil||[value isEqual:[NSNull null]]||[value isEqualToString:@""]) {
        return;
    }
    block(value);
}


@end
