//
//  ViewController.m
//  RouterTest
//
//  Created by Chengguangfa on 2019/2/11.
//  Copyright © 2019年 com.medosport.mo. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    self.view.backgroundColor = [UIColor orangeColor];
    
    
    UIButton *first = [[UIButton alloc] init];
    [self.view addSubview:first];
    [first setTitle:@"第1个控制器" forState:UIControlStateNormal];
    [first setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [first sizeToFit];
    
    first.frame = CGRectMake(50, 50, first.frame.size.width, first.frame.size.height);
    first.tag = 200;
    
    UIButton *second = [[UIButton alloc] init];
    [self.view addSubview:second];
    [second setTitle:@"第2个控制器" forState:UIControlStateNormal];
    [second setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [second sizeToFit];
    
    second.frame = CGRectMake([UIScreen mainScreen].bounds.size.width - second.bounds.size.width - 50, 50, second.frame.size.width, second.frame.size.height);
    second.tag = 201;
    
    [first addTarget:self action:@selector(click:) forControlEvents:UIControlEventTouchUpInside];
    [second addTarget:self action:@selector(click:) forControlEvents:UIControlEventTouchUpInside];
    
}
-(void)click:(UIButton *)sender
{
    NSString *urlStr = nil;
    if (sender.tag == 200) {
        urlStr = @"routerTest://first";
    }
    else{
        urlStr = @"routerTest://second";
    }
    
    NSURL *url = [NSURL URLWithString:urlStr];
    
    [[UIApplication sharedApplication] openURL:url options:nil completionHandler:nil];
}


@end
