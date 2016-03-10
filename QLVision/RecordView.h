//
//  RecordView.h
//  QLVision
//
//  Created by LIU Can on 16/3/9.
//  Copyright © 2016年 CuiYu. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface RecordView : UIView
//中心颜色
@property (strong, nonatomic)UIColor *centerColor;
//圆环背景色
@property (strong, nonatomic)UIColor *arcBackColor;
//圆环色
@property (strong, nonatomic)UIColor *arcFinishColor;
@property (strong, nonatomic)UIColor *arcUnfinishColor;


//百分比数值（0-1）
@property (assign, nonatomic)float percent;

//圆环宽度
@property (assign, nonatomic)float width;

- (void)startAnim;
- (void)stopAnim;
@end
