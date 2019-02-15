//
//  appStaticLibrary.m
//  appStaticLibrary
//
//  Created by Chengguangfa on 2019/2/15.
//  Copyright © 2019年 com.medosport.mo. All rights reserved.
//

#import "appStaticLibrary.h"

@implementation appStaticLibrary
+(void)saySomething{
    NSLog(@"静态库调用文件");
    NSLog(@"静态库调用文件第二次");
}
+(void)sayHello
{
    NSLog(@"hello world");
}
@end
