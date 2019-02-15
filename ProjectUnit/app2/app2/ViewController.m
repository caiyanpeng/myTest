//
//  ViewController.m
//  app2
//
//  Created by Chengguangfa on 2019/2/15.
//  Copyright © 2019年 com.medosport.mo. All rights reserved.
//

#import "ViewController.h"
#import <appStaticLibrary/appStaticLibrary.h>
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor greenColor];
    [appStaticLibrary saySomething];
}


@end
