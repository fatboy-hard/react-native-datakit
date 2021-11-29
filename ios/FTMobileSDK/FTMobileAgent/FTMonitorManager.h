//
//  FTMonitorManager.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/4/14.
//  Copyright © 2020 hll. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FTMobileConfig.h"
#import "FTConstants.h"
#import "FTRUMManger.h"
NS_ASSUME_NONNULL_BEGIN
// 用于 开启各项数据的采集 
@interface FTMonitorManager : NSObject
@property (nonatomic, strong) NSSet *netContentType;
@property (nonatomic, weak) id<FTRUMSessionResourceDelegate,FTRUMWebViewJSBridgeDataDelegate,FTRUMSessionViewDelegate> sessionSourceDelegate;
@property (nonatomic, weak) id<FTRUMSessionErrorDelegate> sessionErrorDelegate;
@property (nonatomic, weak) id<FTRUMSessionActionDelegate> sessionActionDelegate;
@property (nonatomic, weak) UIViewController *currentController;
@property (nonatomic, assign) BOOL running; //正在运行
/**
 * 获取 FTMonitorManager 单例
 * @return 返回的单例
*/
+ (instancetype)sharedInstance;

-(void)setMobileConfig:(FTMobileConfig *)config;
-(void)setTraceConfig:(FTTraceConfig *)traceConfig;
-(void)setRumConfig:(FTRumConfig *)rumConfig delegate:(FTRUMManger *)delegate;
- (BOOL)traceUrl:(NSURL *)url;
- (void)traceUrl:(NSURL *)url completionHandler:(void (^)(NSDictionary *traceHeader))completionHandler;

- (void)trackClickWithView:(UIView *)view;
- (void)trackViewDidDisappear:(UIViewController *)viewController;
- (void)trackViewDidAppear:(UIViewController *)viewController;
- (void)resetInstance;
@end

NS_ASSUME_NONNULL_END
