//
//  ViewController.m
//  PeripheralMode
//
//  Created by Chengguangfa on 2019/1/17.
//  Copyright © 2019年 com.medosport.mo. All rights reserved.
//

#import "ViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>
//生成相应的参数
static NSString *const kPeripheralNameUUID = @"9FA480E0-4967-4542-9390-D343DC5D04AE";

static NSString *const kService1UUID = @"FFE0";
static NSString *const kCharacteristicNotifyUUID = @"FFE1";
static NSString *const kCharacteristicReadWriteUUID = @"FFE2";

static NSString *const kService2UUID = @"FFE0";
static NSString *const kCharacteristicReadUUID = @"FFE1";



@interface ViewController ()<CBPeripheralManagerDelegate>
@property (strong, nonatomic) IBOutlet UIImageView *imageV;
@property (strong, nonatomic) IBOutlet UITextView *textView;
@property (strong, nonatomic) CBPeripheralManager  *peripheralManager;
@property (assign, nonatomic) int  serviceCount;
@property (strong, nonatomic) NSTimer  *timer;
@property (assign, nonatomic) int  state;
@property (assign, nonatomic) NSInteger  size;
@property (strong, nonatomic) NSMutableData  *imageData;
@end

@implementation ViewController
- (IBAction)start:(id)sender {
    [self configuration];
}
- (IBAction)close:(id)sender {
    [self.peripheralManager stopAdvertising];
    self.serviceCount = 0;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
    self.serviceCount = 0;
    self.state = 0;
    self.imageData = [NSMutableData dataWithCapacity:0];
}

-(void)configuration{
    [self setText:@"参数配置中..."];
//    CBUUID *userDescription = [CBUUID UUIDWithString:kPeripheralNameUUID];
    //生成可通知的charactistic
    CBMutableCharacteristic *notifyCharactistic=[[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:kCharacteristicNotifyUUID] properties:CBCharacteristicPropertyNotify value:nil permissions:CBAttributePermissionsReadable];
    //生成可读写写的charactistic
    CBMutableCharacteristic *readWriteCharactictis = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:kCharacteristicReadWriteUUID] properties:CBCharacteristicPropertyWrite|CBCharacteristicPropertyRead value:nil permissions:CBAttributePermissionsWriteable|CBAttributePermissionsReadable];
    
    
    CBMutableCharacteristic *readCharacterrictis =[[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:kCharacteristicReadUUID] properties:CBCharacteristicPropertyRead value:nil permissions:CBAttributePermissionsReadable];
    CBMutableDescriptor *descriptor = [[CBMutableDescriptor alloc] initWithType:[CBUUID UUIDWithString:CBUUIDCharacteristicUserDescriptionString] value:@"name"];
    readCharacterrictis.descriptors = @[descriptor];
    
    
    //生成service
    CBMutableService *service1 = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:kService1UUID] primary:YES];
    service1.characteristics = @[notifyCharactistic,readWriteCharactictis];
    
    CBMutableService *service2 = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:kService2UUID] primary:YES];
    service2.characteristics = @[readCharacterrictis];
    
    [self.peripheralManager addService:service1];
    [self.peripheralManager addService:service2];
    
}

-(void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error
{
    if (error == nil) {
        self.serviceCount++;
        [self setText:[NSString stringWithFormat:@"添加%d个服务",self.serviceCount]];
    }
    
    if (self.serviceCount == 2) {
        [self setText:@"添加服务完成"];
        [self setText:@"开始广播"];
        //开启广播
        [self.peripheralManager startAdvertising:@{
                                                   CBAdvertisementDataServiceUUIDsKey:@[[CBUUID UUIDWithString:kService1UUID],[CBUUID UUIDWithString:kService2UUID]],
                                                   CBAdvertisementDataLocalNameKey:@"iPhone"
                                                   }];
    }
    
}

//发送数据，发送当前时间的秒数
-(BOOL)sendData:(NSTimer *)t {
    CBMutableCharacteristic *characteristic = t.userInfo;
    NSDateFormatter *dft = [[NSDateFormatter alloc]init];
    [dft setDateFormat:@"ss"];
    NSLog(@"%@",[dft stringFromDate:[NSDate date]]);
//    [self setText:[NSString stringWithFormat:@"当前时间戳: %@",[dft stringFromDate:[NSDate date]]]];
    //执行回应Central通知数据
    return  [self.peripheralManager updateValue:[[dft stringFromDate:[NSDate date]] dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:(CBMutableCharacteristic *)characteristic onSubscribedCentrals:nil];
}


-(void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error
{
    [self setText:@"广播中..."];
  
}

-(void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
        [self setText:[NSString stringWithFormat:@"订阅了%@的数据",characteristic.UUID]];
      self.timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(sendData:) userInfo:characteristic  repeats:YES];
    
}

-(void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic
{
     [self setText:[NSString stringWithFormat:@"取消订阅了%@的数据",characteristic.UUID]];
}
//读消息
-(void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveReadRequest:(CBATTRequest *)request
{
    if (request.characteristic.properties & CBCharacteristicPropertyRead) {
        NSData *data = request.characteristic.value;
        [request setValue:data];
        [self.peripheralManager respondToRequest:request withResult:CBATTErrorSuccess];
    }
    else
    {
        [self.peripheralManager respondToRequest:request withResult:CBATTErrorReadNotPermitted];
    }
}
//写消息
-(void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray<CBATTRequest *> *)requests
{
    CBATTRequest *request = requests.firstObject;
    
    if (request.characteristic.properties & CBCharacteristicPropertyWrite) {
        //需要转化成CBMutableCharacteristic 才能读写
        CBMutableCharacteristic *c = (CBMutableCharacteristic *)request.characteristic;
        c.value = request.value;
        [self.peripheralManager respondToRequest:request withResult:CBATTErrorSuccess];
        
        
        switch (self.state) {
            case 0:
                {
                    NSString *size = [[NSString  alloc] initWithData:request.value encoding:NSUTF8StringEncoding];
                    self.size = [size integerValue];
                    self.state = 1;
                }
                break;
            case 1:
            {
                NSData *imageD = request.value;
                [self.imageData appendData:imageD];
                [self setText:[NSString stringWithFormat:@"收到多少%zdb的文件",imageD.length]];
                if (self.imageData.length < self.size) {
               
                }
                else
                {
                    self.imageV.image = [UIImage imageWithData:self.imageData];
                    [self setText:@"收到了图片"];
                }
                
            }
                break;
                
                
            default:
                break;
        }
        
        
        
        
       
        
    }
    else
    {
        [self.peripheralManager respondToRequest:request withResult:CBATTErrorWriteNotPermitted];
    }
    
}
//状态改变
-(void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    switch (peripheral.state) {
        case CBManagerStatePoweredOn:
            NSLog(@"打开状态");
            [self setText:@"当前状态:打开状态"];
            break;
        case CBManagerStatePoweredOff:
            NSLog(@"关闭状态");
            [self setText:@"当前状态:关闭状态"];
            break;
        case CBManagerStateUnsupported:
            NSLog(@"不支持");
             [self setText:@"当前状态:不支持状态"];
            break;
            
        default:
            break;
    }
    
}

-(void)setText:(NSString *)text
{
    NSString *previous = self.textView.text;
    
    NSString *now = [NSString stringWithFormat:@"%@\n%@",previous,text];
    self.textView.text = now;
    //滑动
    [self.textView scrollRectToVisible:CGRectMake(0, self.textView.contentSize.height-20, self.textView.contentSize.width, 20) animated:YES];
}

@end
