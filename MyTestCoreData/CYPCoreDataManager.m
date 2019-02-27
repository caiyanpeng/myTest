//
//  CYPCoreDataManager.m
//  MyTestCoreData
//
//  Created by Chengguangfa on 2019/2/27.
//  Copyright © 2019年 com.medosport.mo. All rights reserved.
//

#import "CYPCoreDataManager.h"
static CYPCoreDataManager *instance;
@implementation CYPCoreDataManager
+(instancetype)shareCoreData
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[CYPCoreDataManager alloc] init];
    });
    
    return instance;
}

-(NSURL *)getDocumentUrlPath
{
    return [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].lastObject;
}

-(NSManagedObjectContext *)managedObjectContext
{
    if (!_managedObjectContext) {
        _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [_managedObjectContext setPersistentStoreCoordinator:self.persistentStoreCoordinator];
    }
    return _managedObjectContext;
}

-(NSManagedObjectModel *)managerObject
{
    if (!_managerObject) {
        _managerObject = [NSManagedObjectModel mergedModelFromBundles:nil];
    }
    return _managerObject;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (!_persistentStoreCoordinator) {
        _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.managerObject];
        NSURL *url = [[self getDocumentUrlPath] URLByAppendingPathComponent:@"sqlit.db" isDirectory:YES];
        //添加存储器
        /**
         * type:一般使用数据库存储方式NSSQLiteStoreType
         * configuration:配置信息  一般无需配置
         * URL:要保存的文件路径
         * options:参数信息 一般无需设置
         */
        
        [_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:url options:nil error:nil];
        
    }
    return _persistentStoreCoordinator;
}

-(void)save
{
    [self.managedObjectContext save:nil];
}
@end
