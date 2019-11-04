enum NIMNetCallMediaType {
    //音频通话
    Audio,
    //视频通话
    Video,
}

enum NIMNetCallCamera {

    //  前置摄像头
    front,
    // 后置摄像头
    back,
}

/// 消息内容类型枚举
enum NIMMessageType {
  Text, // 文本类型消息 0
  Image, // 图片类型消息 1
  Audio, // 声音类型消息 2
  Video, // 视频类型消息 3
  Location, // 位置类型消息 4
  Notification, // 通知类型消息 5
  File, // 文件类型消息 6
  Tip, // 提醒类型消息 10
  Robot, // 机器人类型消息 11
  Custom, // 自定义类型消息 100
}

/// 消息投递状态（仅针对发送的消息）
enum NIMMessageDeliveryState {
  Failed, // 消息发送失败 0
  Delivering, // 消息发送中 1
  Delivered, // 消息发送成功 2
}

///会话类型
enum NIMSessionType {

    P2P,//点对点0
    Team,// 群组 1
    Chatroom, //聊天室 2
    SuperTeam, // 超大群 3
}