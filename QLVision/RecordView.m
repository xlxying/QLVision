//
//  RecordView.m
//  QLVision
//
//  Created by LIU Can on 16/3/9.
//  Copyright © 2016年 CuiYu. All rights reserved.
//

#import "RecordView.h"
@interface RecordView (){
    int _timeTick;
    BOOL _isRun;
    NSTimer *_timer;
}
@end

@implementation RecordView
-(void)dealloc{
    if (_timer) {
        [_timer invalidate];
        _timer = nil;
    }
}
- (id)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        _percent = 0;
        _width = 8;
        _timeTick = 0;
        _isRun = NO;
        
    }
    
    return self;
}

- (void)setPercent:(float)percent{
    _percent = percent;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect{
//    [self addArcBackColor];
    [self drawArc];
    [self addCenterBack];
//    [self addCenterLabel];
}

- (void)addArcBackColor{
    CGColorRef color = (_arcBackColor == nil) ? [UIColor lightGrayColor].CGColor : _arcBackColor.CGColor;
    
    CGContextRef contextRef = UIGraphicsGetCurrentContext();
    CGSize viewSize = self.bounds.size;
    CGPoint center = CGPointMake(viewSize.width / 2, viewSize.height / 2);
    
    // Draw the slices.
    CGFloat radius = viewSize.width / 2;
    CGContextBeginPath(contextRef);
    CGContextMoveToPoint(contextRef, center.x, center.y);
    CGContextAddArc(contextRef, center.x, center.y, radius,-M_PI/2,2*M_PI-M_PI/2, 0);
    CGContextSetFillColorWithColor(contextRef, color);
    CGContextFillPath(contextRef);
}

- (void)drawArc{
    if (_percent == 0 || _percent > 1) {
        return;
    }
    
    if (_percent == 1) {
        CGColorRef color = (_arcFinishColor == nil) ? [UIColor greenColor].CGColor : _arcFinishColor.CGColor;
        
        CGContextRef contextRef = UIGraphicsGetCurrentContext();
        CGSize viewSize = self.bounds.size;
        CGPoint center = CGPointMake(viewSize.width / 2, viewSize.height / 2);
        // Draw the slices.
        CGFloat radius = viewSize.width / 2-2;
//        CGContextBeginPath(contextRef);
        CGContextSetStrokeColorWithColor(contextRef, color);
        CGContextSetLineWidth(contextRef, 4.0);
        CGContextMoveToPoint(contextRef, center.x, 2);
        CGContextAddArc(contextRef, center.x, center.y, radius,-M_PI/2,2*M_PI-M_PI/2, 0);
        CGContextDrawPath(contextRef, kCGPathStroke);
//        CGContextSetFillColorWithColor(contextRef, color);
//        CGContextFillPath(contextRef);
    }else{
        
        float endAngle = 2*M_PI*_percent-M_PI/2;
        
        CGColorRef color = (_arcUnfinishColor == nil) ? [UIColor blueColor].CGColor : _arcUnfinishColor.CGColor;
        CGContextRef contextRef = UIGraphicsGetCurrentContext();
        CGSize viewSize = self.bounds.size;
        CGPoint center = CGPointMake(viewSize.width / 2, viewSize.height / 2);
        // Draw the slices.
        CGFloat radius = viewSize.width / 2-2;
//        CGContextBeginPath(contextRef);
        CGContextSetStrokeColorWithColor(contextRef, color);
        CGContextSetLineWidth(contextRef, 4.0);
        CGContextMoveToPoint(contextRef, center.x, 2);
        CGContextAddArc(contextRef, center.x, center.y, radius,-M_PI/2,endAngle, 0);
        CGContextDrawPath(contextRef, kCGPathStroke);
//        CGContextSetFillColorWithColor(contextRef, color);
//        CGContextFillPath(contextRef);
    }
    
}

-(void)addCenterBack{
    float width = (_width == 0) ? 8 : _width;
    
    CGColorRef color = (_centerColor == nil) ? [UIColor whiteColor].CGColor : _centerColor.CGColor;
    CGContextRef contextRef = UIGraphicsGetCurrentContext();
    CGSize viewSize = self.bounds.size;
    CGPoint center = CGPointMake(viewSize.width / 2, viewSize.height / 2);
    // Draw the slices.
    CGFloat radius = viewSize.width / 2 - width;
    CGContextBeginPath(contextRef);
    CGContextMoveToPoint(contextRef, center.x, center.y);
    CGContextAddArc(contextRef, center.x, center.y, radius,0,2*M_PI, 0);
    CGContextSetFillColorWithColor(contextRef, color);
    CGContextFillPath(contextRef);
}

- (void)addCenterLabel{
    NSString *percent = @"";
    
    float fontSize = 14;
    UIColor *arcColor = [UIColor blueColor];
    if (_percent == 1) {
        percent = @"100%";
        fontSize = 14;
        arcColor = (_arcFinishColor == nil) ? [UIColor greenColor] : _arcFinishColor;
        
    }else if(_percent < 1 && _percent >= 0){
        
        fontSize = 13;
        arcColor = (_arcUnfinishColor == nil) ? [UIColor blueColor] : _arcUnfinishColor;
        percent = [NSString stringWithFormat:@"%0.2f%%",_percent*100];
    }
    
    CGSize viewSize = self.bounds.size;
    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.alignment = NSTextAlignmentCenter;
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:[UIFont boldSystemFontOfSize:fontSize],NSFontAttributeName,arcColor,NSForegroundColorAttributeName,[UIColor clearColor],NSBackgroundColorAttributeName,paragraph,NSParagraphStyleAttributeName,nil];
    
    [percent drawInRect:CGRectMake(5, (viewSize.height-fontSize)/2, viewSize.width-10, fontSize)withAttributes:attributes];
}

- (void)startAnim{
    
    _timeTick = 601;//60秒倒计时
    _timer=[NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(timeFireMethod) userInfo:nil repeats:YES];
    _isRun = YES;
}

- (void)stopAnim{
    _isRun = NO;
}

-(void)timeFireMethod
{
    
    _timeTick--;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setPercent:(601.0-_timeTick)/601.0];
    });
    if(_timeTick==0||_isRun==NO){
        [_timer invalidate];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setPercent:1.0];
        });
    }
    
}
@end
