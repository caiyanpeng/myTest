//
//  ClassRoom+CoreDataProperties.h
//  MyTestCoreData
//
//  Created by Chengguangfa on 2019/2/27.
//  Copyright © 2019年 com.medosport.mo. All rights reserved.
//
//

#import "ClassRoom+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface ClassRoom (CoreDataProperties)

+ (NSFetchRequest<ClassRoom *> *)fetchRequest;

@property (nonatomic) int64_t number;
@property (nonatomic) int64_t container;

@end

NS_ASSUME_NONNULL_END
