//
//  CYPCoreDataManager.h
//  MyTestCoreData
//
//  Created by Chengguangfa on 2019/2/27.
//  Copyright © 2019年 com.medosport.mo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
@interface CYPCoreDataManager : NSObject
//单例对象
+(instancetype)shareCoreData;
//管理上下文
@property (strong, nonatomic) NSManagedObjectContext  *managedObjectContext;
//模型对象
@property (strong, nonatomic) NSManagedObjectModel  *managerObject;
//储存调度器
@property (strong, nonatomic) NSPersistentStoreCoordinator  *persistentStoreCoordinator;
//保存
-(void)save;
@end


