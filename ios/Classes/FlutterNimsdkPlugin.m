#import "FlutterNimsdkPlugin.h"
#import <NIMSDK/NIMSDK.h>
#import <NIMAVChat/NIMAVChat.h>
#import <MJExtension/MJExtension.h>

typedef enum : NSUInteger {
    NIMDelegateTypeOnLogin = 0,
    NIMDelegateTypeOnReceive = 1,
    NIMDelegateTypeOnResponse = 2,
    NIMDelegateTypeOnCallEstablished = 3,
    NIMDelegateTypeOnHangup = 4,
    NIMDelegateTypeOnCallDisconnected = 5,
    NIMDelegateTypeDidAddRecentSession = 6,
    NIMDelegateTypeDidUpdateRecentSession = 7,
    NIMDelegateTypeDidRemoveRecentSession = 8,
    NIMDelegateTypeRecordAudioComplete = 9,
} NIMDelegateType;

@interface FlutterNimsdkPlugin()<NIMLoginManagerDelegate,
                                 FlutterStreamHandler,
                                 NIMNetCallManagerDelegate,
                                 NIMConversationManagerDelegate,
                                 NIMMediaManagerDelegate>

@property(nonatomic) FlutterEventSink eventSink;
@property(nonatomic, strong) FlutterMethodChannel *methodChannel;
@property(nonatomic, strong) NSMutableArray *sessions;

/// 录音时长
@property(nonatomic, assign) NSTimeInterval recordTime;

/// sessionID
@property(nonatomic, copy) NSString *sessionID;

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
            
            NSDictionary *args = call.arguments;
            int callID = [NSString stringWithFormat:@"%@",args[@"callID"]].intValue;
            BOOL accept = [NSString stringWithFormat:@"%@",args[@"accept"]].boolValue;
            
            [[NIMAVChatSDK sharedSDK].netCallManager response:callID accept:accept option:option completion:^(NSError * _Nullable error, UInt64 callID) {
                
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
                    
                    msg.messageObject = nil;
                    NSMutableDictionary *dict = [msg mj_keyValues];
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
        
    } else if ([@"mostRecentSessions" isEqualToString:call.method]) {
        
        NSArray *recentSessions = [NIMSDK sharedSDK].conversationManager.mostRecentSessions;
        self.sessions = [NSMutableArray arrayWithArray:recentSessions];
        NSMutableArray *array = [NSMutableArray array];
        for (NIMRecentSession *session in recentSessions) {
            session.lastMessage.messageObject = nil;
            NSMutableDictionary *tempDic = [session mj_keyValues];
            
            [array addObject:tempDic];
        }
        NSDictionary *dic = @{@"mostRecentSessions": array};
        result(dic);
        
    }else if ([@"allRecentSessions" isEqualToString:call.method]) {
        
        NSArray *recentSessions = [NIMSDK sharedSDK].conversationManager.allRecentSessions;
        self.sessions = [NSMutableArray arrayWithArray:recentSessions];
        NSMutableArray *array = [NSMutableArray array];
        for (NIMRecentSession *session in recentSessions) {
            session.lastMessage.messageObject = nil;
            NSMutableDictionary *tempDic = [session mj_keyValues];
            
            [array addObject:tempDic];
        }
        NSDictionary *dic = @{@"allRecentSessions": array};
        result(dic);
        
    }else if ([@"deleteRecentSession" isEqualToString:call.method]) {
        
        NSDictionary *args = call.arguments;
        NSString *sessionID = args[@"sessionID"];
        for (NIMRecentSession *session in self.sessions) {
            if ([session.session.sessionId isEqualToString:sessionID]) {
                [[NIMSDK sharedSDK].conversationManager deleteRecentSession:session];
            }
        }
        
    }else if ([@"sendTextMessage" isEqualToString:call.method]) {//文本
        
        [self sendMessage:NIMMessageTypeText args:call.arguments];
        
    }else if ([@"sendTipMessage" isEqualToString:call.method]) {//提示
        
        [self sendMessage: NIMMessageTypeTip args:call.arguments];
        
    }else if ([@"sendImageMessage" isEqualToString:call.method]) {//图片
        
        [self sendMessage:NIMMessageTypeImage args:call.arguments];
        
    }else if ([@"sendVideoMessage" isEqualToString:call.method]) {//视频
        
        [self sendMessage:NIMMessageTypeVideo args:call.arguments];
        
    }else if ([@"sendAudioMessage" isEqualToString:call.method]) {//音频
        
        [self sendMessage:NIMMessageTypeAudio args:call.arguments];
        
    }else if ([@"sendFileMessage" isEqualToString:call.method]) {//文件
        
        [self sendMessage: NIMMessageTypeFile args:call.arguments];
        
    }else if ([@"sendLocationMessage" isEqualToString:call.method]) {//位置
        
        [self sendMessage: NIMMessageTypeLocation args:call.arguments];
        
    }else if ([@"onStartRecording" isEqualToString:call.method]) {//录音
        
        self.sessionID = call.arguments[@"sessionId"];
        [[[NIMSDK sharedSDK] mediaManager] addDelegate:self];
        [[[NIMSDK sharedSDK] mediaManager] record:NIMAudioTypeAAC duration:60.0];
        
    }else if ([@"onStopRecording" isEqualToString:call.method]) {//结束录音
        
        self.sessionID = call.arguments[@"sessionId"];
        [[[NIMSDK sharedSDK] mediaManager] stopRecord];
        
    }else if ([@"onCancelRecording" isEqualToString:call.method]) {//取消录音
       
        self.sessionID = call.arguments[@"sessionId"];
        [[[NIMSDK sharedSDK] mediaManager] cancelRecord];
        
    } else {
        result(FlutterMethodNotImplemented);
    }
}

- (void)sendMessage:(NIMMessageType)messageType args:(NSDictionary *)args {
    
    NSDictionary *sessionDic = args[@"nimSession"];
    NSString *sessionID = sessionDic[@"sessionId"];
    int type = [NSString stringWithFormat:@"%@",args == nil ? @"0" : sessionDic[@"sessionType"]].intValue;
    NIMSessionType sessionType = NIMSessionTypeP2P;
    if (type == 3) {
        sessionType = NIMSessionTypeSuperTeam;
    }else {
        sessionType = type;
    }
    
    // 构造出具体会话
    NIMSession *session = [NIMSession session:sessionID type:sessionType];
    // 构造出具体消息
    NIMMessage *message = [[NIMMessage alloc] init];
    
    if (messageType == NIMMessageTypeText) {
        message.text        = args[@"message"];
        NSError *error = nil;
        [[NIMSDK sharedSDK].chatManager sendMessage:message toSession:session error:&error];
    }else if (messageType == NIMMessageTypeImage) {
        
        // 获得图片附件对象
        NIMImageObject *object = [[NIMImageObject alloc] initWithFilepath:args[@"imagePath"]];
        message.messageObject        = object;
        NSError *error = nil;
        [[NIMSDK sharedSDK].chatManager sendMessage:message toSession:session error:&error];
    }else if (messageType == NIMMessageTypeVideo) {
        
        // 获得视频附件对象
        NIMVideoObject *object = [[NIMVideoObject alloc] initWithSourcePath:args[@"videoPath"]];
        message.messageObject        = object;
        NSError *error = nil;
        [[NIMSDK sharedSDK].chatManager sendMessage:message toSession:session error:&error];
    }else if (messageType == NIMMessageTypeAudio) {
        
        // 获得音附件对象
        NIMAudioObject *object = [[NIMAudioObject alloc] initWithSourcePath:args[@"audioPath"]];
        message.messageObject        = object;
        NSError *error = nil;
        [[NIMSDK sharedSDK].chatManager sendMessage:message toSession:session error:&error];
    }else if (messageType == NIMMessageTypeFile) {
        
        // 获得文件附件对象
         NIMFileObject *object = [[NIMFileObject alloc] initWithSourcePath:args[@"filePath"]];
        message.messageObject        = object;
        NSError *error = nil;
        [[NIMSDK sharedSDK].chatManager sendMessage:message toSession:session error:&error];
    }else if (messageType == NIMMessageTypeLocation) {
        
        // 获得位置附件对象
        NSDictionary *locationDic = args[@"locationObject"];
        double latitude = [NSString stringWithFormat:@"%@",locationDic[@"latitude"]].doubleValue;
        double longitude = [NSString stringWithFormat:@"%@",locationDic[@"longitude"]].doubleValue;
        NSString *title = [NSString stringWithFormat:@"%@",locationDic[@"title"]];
        NIMLocationObject *object = [[NIMLocationObject alloc] initWithLatitude:latitude longitude:longitude title:title];
        message.messageObject = object;
        NSError *error = nil;
        [[NIMSDK sharedSDK].chatManager sendMessage:message toSession:session error:&error];
    }else if (messageType == NIMMessageTypeTip) {
        
         // 获得文件附件对象
        NIMTipObject *object = [[NIMTipObject alloc] init];
        message.messageObject        = object;
        message.text = args[@"message"];
        NSError *error = nil;
        [[NIMSDK sharedSDK].chatManager sendMessage:message toSession:session error:&error];
    }
}


/// 发送音频消息
/// @param filePath 文件地址
- (void)sendAudioMessage:(NSString *)filePath {
    
    // 构造出具体会话
    NIMSession *session = [NIMSession session:self.sessionID type:NIMSessionTypeP2P];
    // 构造出具体消息
    NIMMessage *message = [[NIMMessage alloc] init];
    NIMAudioObject *object = [[NIMAudioObject alloc] initWithSourcePath:filePath];
    message.messageObject = object;
    NSError *error = nil;
    [[NIMSDK sharedSDK].chatManager sendMessage:message toSession:session error:&error];
}




// MARK: - NIMLoginManagerDelegate
- (void)onLogin:(NIMLoginStep)step {
    
    if (self.eventSink) {
        self.eventSink(@{@"delegateType": [NSNumber numberWithInteger:NIMDelegateTypeOnLogin],
                         @"step": [NSNumber numberWithInteger:NIMDelegateTypeOnLogin]});
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
        NSDictionary *dic = @{@"delegateType": [NSNumber numberWithInt:NIMDelegateTypeOnReceive],
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
        
        NSDictionary *dic = @{@"delegateType": [NSNumber numberWithInt:NIMDelegateTypeOnResponse],
                              @"callID": [NSNumber numberWithInteger:callID],
                              @"callee": callee,
                              @"accepted": [NSNumber numberWithBool:accepted]};
        self.eventSink(dic);
    }
    
}

//通话建立成功回调
- (void)onCallEstablished:(UInt64)callID {
    
    //通话建立成功 开始计时 刷新UI
    
    if (self.eventSink) {
        
        NSDictionary *dic = @{@"delegateType": [NSNumber numberWithInt:NIMDelegateTypeOnCallEstablished],
                              @"callID": [NSNumber numberWithInteger:callID]};
        self.eventSink(dic);
    }
}

//收到对方挂断电话
- (void)onHangup:(UInt64)callID by:(NSString *)user {
    
    if (self.eventSink) {
        
        NSDictionary *dic = @{@"delegateType": [NSNumber numberWithInt:NIMDelegateTypeOnHangup],
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
        NSDictionary *dic = @{@"delegateType": [NSNumber numberWithInt:NIMDelegateTypeOnCallDisconnected],
                              @"callID": [NSNumber numberWithInteger:callID],
                              @"error": msg};
        self.eventSink(dic);
    }
}

// MARK: - NIMConversationManagerDelegate

/**
 *  增加最近会话的回调
 *
 *  @param recentSession    最近会话
 *  @param totalUnreadCount 目前总未读数
 *  @discussion 当新增一条消息，并且本地不存在该消息所属的会话时，会触发此回调。
 */
- (void)didAddRecentSession:(NIMRecentSession *)recentSession
           totalUnreadCount:(NSInteger)totalUnreadCount {
    
    if (self.eventSink) {
        
        recentSession.lastMessage.messageObject = nil;
        NSDictionary *tempDic = [recentSession mj_keyValues];
        NSDictionary *dic = @{@"delegateType": [NSNumber numberWithInt:NIMDelegateTypeDidAddRecentSession],
                              @"totalUnreadCount": [NSNumber numberWithInteger:totalUnreadCount],
                              @"recentSession": tempDic};
        self.eventSink(dic);
    }
    
}

/**
 *  最近会话修改的回调
 *
 *  @param recentSession    最近会话
 *  @param totalUnreadCount 目前总未读数
 *  @discussion 触发条件包括: 1.当新增一条消息，并且本地存在该消息所属的会话。
 *                          2.所属会话的未读清零。
 *                          3.所属会话的最后一条消息的内容发送变化。(例如成功发送后，修正发送时间为服务器时间)
 *                          4.删除消息，并且删除的消息为当前会话的最后一条消息。
 */
- (void)didUpdateRecentSession:(NIMRecentSession *)recentSession
              totalUnreadCount:(NSInteger)totalUnreadCount {
    
    if (self.eventSink) {
        recentSession.lastMessage.messageObject = nil;
        NSDictionary *tempDic = [recentSession mj_keyValues];
        NSDictionary *dic = @{@"delegateType": [NSNumber numberWithInt:NIMDelegateTypeDidUpdateRecentSession],
                              @"totalUnreadCount": [NSNumber numberWithInteger:totalUnreadCount],
                              @"recentSession": tempDic};
        self.eventSink(dic);
    }
    
}

/**
 *  删除最近会话的回调
 *
 *  @param recentSession    最近会话
 *  @param totalUnreadCount 目前总未读数
 */
- (void)didRemoveRecentSession:(NIMRecentSession *)recentSession
              totalUnreadCount:(NSInteger)totalUnreadCount {
    
    if (self.eventSink) {
        recentSession.lastMessage.messageObject = nil;
        NSDictionary *tempDic = [recentSession mj_keyValues];
        NSDictionary *dic = @{@"delegateType": [NSNumber numberWithInt:NIMDelegateTypeDidRemoveRecentSession],
                              @"totalUnreadCount": [NSNumber numberWithInteger:totalUnreadCount],
                              @"recentSession": tempDic};
        self.eventSink(dic);
    }
}

// MARK: - NIMMediaManagerDelegate


/// 开始录音
/// @param filePath 路径
- (void)recordAudio:(NSString *)filePath didBeganWithError:(NSError *)error {
    self.recordTime = 0;
}

/// 录音中
/// @param currentTime 录音时长
- (void)recordAudioProgress:(NSTimeInterval)currentTime {
    self.recordTime = currentTime;
}


/// 取消录音
- (void)recordAudioDidCancelled {
    self.recordTime = 0;
}

- (void)recordAudio:(NSString *)filePath didCompletedWithError:(NSError *)error {
    
    if (error == nil && filePath != nil) {
        if (self.recordTime > 1) {
            
            [self sendAudioMessage:filePath];
        } else {
            NSLog(@"说话时间太短");
            if (self.eventSink) {
                NSDictionary *dic = @{@"delegateType": [NSNumber numberWithInt:NIMDelegateTypeRecordAudioComplete],
                                      @"msg": @"说话时间太短"};
                self.eventSink(dic);
            }
        }
    }
}

- (void)recordAudioInterruptionBegin {
    [[[NIMSDK sharedSDK] mediaManager] cancelRecord];
}

    
-(void)getValue:(NSDictionary*)dict key:(NSString*) key :(void(^)(id result))block{
    id value = dict[key];
    if (value==nil||[value isEqual:[NSNull null]]||[value isEqualToString:@""]) {
        return;
    }
    block(value);
}

- (NSMutableArray *)sessions {
    if (!_sessions) {
        _sessions = [NSMutableArray array];
    }
    return _sessions;
}

@end
