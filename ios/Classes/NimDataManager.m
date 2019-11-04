//
//  NimDataManager.m
//  flutter_nimsdk
//
//  Created by HyBoard on 2019/11/4.
//

#import "NimDataManager.h"

@implementation NimDataManager

+ (instancetype)shared {
    
    static NimDataManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[NimDataManager alloc] init];
    });
    return manager;
}




@end
