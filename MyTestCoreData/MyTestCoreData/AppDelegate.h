//
//  AppDelegate.h
//  MyTestCoreData
//
//  Created by Chengguangfa on 2019/2/27.
//  Copyright © 2019年 com.medosport.mo. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (readonly, strong) NSPersistentContainer *persistentContainer;

- (void)saveContext;


@end

