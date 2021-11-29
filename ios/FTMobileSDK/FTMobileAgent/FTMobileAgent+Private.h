//
//  FTMobileAgent+Private.h
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2020/5/14.
//  Copyright © 2020 hll. All rights reserved.
//

#ifndef FTMobileAgent_Private_h
#define FTMobileAgent_Private_h


#import "FTMobileAgent.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@class FTRecordModel,FTUploadTool,FTPresetProperty,FTRUMManger;


@interface FTMobileAgent (Private)
@property (nonatomic, strong) FTUploadTool *upTool;
@property (nonatomic, strong) FTPresetProperty *presetProperty;
@property (nonatomic, strong) FTRUMManger *rumManger;


- (void)rumWrite:(NSString *)type terminal:(NSString *)terminal tags:(NSDictionary *)tags fields:(NSDictionary *)fields;

- (void)rumWrite:(NSString *)type terminal:(NSString *)terminal tags:(NSDictionary *)tags fields:(NSDictionary *)fields tm:(long long)tm;

/**
 * networkTrace 写入
 */
-(void)tracing:(NSString *)content tags:(NSDictionary *)tags field:(NSDictionary *)field tm:(long long)tm;


-(void)resetInstance;


@end
#endif /* FTMobileAgent_Private_h */
