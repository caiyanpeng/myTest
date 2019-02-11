//
//  AppDelegate.m
//  RouterTest
//
//  Created by Chengguangfa on 2019/2/11.
//  Copyright © 2019年 com.medosport.mo. All rights reserved.
//

#import "AppDelegate.h"
#import <JLRoutes/JLRoutes.h>
#import "FirstViewController.h"
#import "SecondViewController.h"
@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"RouterRegistList" ofType:@"plist"];
    
    self.maps = [NSArray arrayWithContentsOfFile:filePath];
    
    NSLog(@"first == %@",NSStringFromClass([FirstViewController class]));
    NSLog(@"second == %@",NSStringFromClass([SecondViewController class]));
    [[JLRoutes globalRoutes] addRoute:@"/:action" handler:^BOOL(NSDictionary<NSString *,id> * _Nonnull parameters) {
       
        NSString *action = parameters[@"action"];
        NSString *controllerName = nil;
        
        BOOL isReady = NO;
        
        for (NSDictionary *dict in self.maps) {
            
            if ([action isEqualToString:dict[@"action"]]) {
                controllerName = dict[@"className"];
                isReady = YES;
                break;
            }
            
        }
        
        if (!isReady) {
            return NO;
        }
//
        Class controller = NSClassFromString(controllerName);
        id ctr  = [[controller alloc] init];
        if ([ctr isKindOfClass:[UIViewController class]]) {
          
            [[self topViewController] presentViewController:ctr animated:YES completion:nil];
        }
        
        
        return YES;
    }];
    
    

    
    return YES;
}

-(BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options
{
    
    
    return [JLRoutes routeURL:url];
}


-(UIViewController *)topViewController{
    
    
    return [self topViewControlelrWithRootViewController:[UIApplication sharedApplication].keyWindow.rootViewController];
}

-(UIViewController *)topViewControlelrWithRootViewController:(UIViewController *)rootController{
    
    if ([rootController isKindOfClass:[UITabBarController class]]) {
        UITabBarController *tabController = (UITabBarController *)rootController;
        return [self topViewControlelrWithRootViewController:tabController.selectedViewController];
    }
    else if([rootController isKindOfClass:[UINavigationController class]]){
        UINavigationController *navigationController = (UINavigationController *)rootController;
        return [self topViewControlelrWithRootViewController:navigationController.visibleViewController];
    }
    else if (rootController.presentedViewController)
    {
        UIViewController *presentViewController = (UIViewController *)rootController.presentedViewController;
        return [self topViewControlelrWithRootViewController:presentViewController];
    }
    else
    {
        return rootController;
    }
    
}


@end
