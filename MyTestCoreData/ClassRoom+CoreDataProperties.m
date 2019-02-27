//
//  ClassRoom+CoreDataProperties.m
//  MyTestCoreData
//
//  Created by Chengguangfa on 2019/2/27.
//  Copyright © 2019年 com.medosport.mo. All rights reserved.
//
//

#import "ClassRoom+CoreDataProperties.h"

@implementation ClassRoom (CoreDataProperties)

+ (NSFetchRequest<ClassRoom *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"ClassRoom"];
}

@dynamic number;
@dynamic container;

@end
