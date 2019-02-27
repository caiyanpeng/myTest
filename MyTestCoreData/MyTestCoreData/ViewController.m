//
//  ViewController.m
//  MyTestCoreData
//
//  Created by Chengguangfa on 2019/2/27.
//  Copyright © 2019年 com.medosport.mo. All rights reserved.
//

#import "ViewController.h"
#import "ClassRoom+CoreDataClass.h"
#import "Student+CoreDataClass.h"
#import "CYPCoreDataManager.h"
@interface ViewController ()<UITableViewDelegate, UITableViewDataSource>
@property (strong, nonatomic) UITableView  *tableView;
@property (strong, nonatomic) NSArray<Student *>  *results;
@property (assign, nonatomic) int64_t  count;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 80, self.view.bounds.size.width, self.view.bounds.size.height - 80)];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
    CGFloat btnW = self.view.bounds.size.width / 4;
    
    UIButton *btn  = [[UIButton alloc] initWithFrame:CGRectMake(0, 30, btnW, 50)];
    [btn setTitle:@"插入" forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [btn addTarget:self action:@selector(insertItems) forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:btn];
    
    UIButton *delete  = [[UIButton alloc] initWithFrame:CGRectMake(self.view.bounds.size.width * 0.5 - btnW * 0.5, 30, btnW, 50)];
    [delete setTitle:@"删除" forState:UIControlStateNormal];
    [delete setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [delete addTarget:self action:@selector(deleteItems) forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:delete];
    
    
    UIButton *change  = [[UIButton alloc] initWithFrame:CGRectMake(self.view.bounds.size.width - btnW, 30, btnW, 50)];
    [change setTitle:@"修改" forState:UIControlStateNormal];
    [change setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [change addTarget:self action:@selector(updateItems) forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:change];
    
    _count = 1;
    
    [self queryItems];
}
//插入数据
-(void)insertItems{
    Student *newClass = [NSEntityDescription insertNewObjectForEntityForName:@"Student" inManagedObjectContext:[CYPCoreDataManager shareCoreData].managedObjectContext];
    newClass.age = 101;
    newClass.classRoom = _count++;
    
    [[CYPCoreDataManager shareCoreData] save];
    
    [self queryItems];
    
    
    
}
//删除数据
-(void)deleteItems{
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Student"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"age = 101"];
    request.predicate = predicate;
    
    NSArray <Student *> *items = [[CYPCoreDataManager shareCoreData].managedObjectContext executeFetchRequest:request error:NULL];
    
    [items enumerateObjectsUsingBlock:^(Student * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [[CYPCoreDataManager shareCoreData].managedObjectContext deleteObject:obj];
    }];
    
    if ([CYPCoreDataManager shareCoreData].managedObjectContext.hasChanges) {
        [[CYPCoreDataManager shareCoreData] save];
    }

    [self queryItems];
}
//更新数据
-(void)updateItems{
    
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Student"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"age = 101"];
    request.predicate = predicate;
    
    NSArray <Student *> *items = [[CYPCoreDataManager shareCoreData].managedObjectContext executeFetchRequest:request error:NULL];
    
    [items enumerateObjectsUsingBlock:^(Student * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        obj.age = 100;
    }];
    
    if ([CYPCoreDataManager shareCoreData].managedObjectContext.hasChanges) {
        [[CYPCoreDataManager shareCoreData] save];
    }
    [self queryItems];
}
-(void)queryItems{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Student"];
    NSArray<Student *> * results = [[CYPCoreDataManager shareCoreData].managedObjectContext executeFetchRequest:request error:nil];
    
    self.results = results;
    
    [self.tableView reloadData];
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.results.count;
}
-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cid = @"cellID";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cid];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cid];
    }
    
    Student *room = self.results[indexPath.row];
    
    cell.textLabel.text = [NSString stringWithFormat:@"年龄：%lld",room.age];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"班级是：%lld",room.classRoom];
    return cell;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 40;
}

@end
