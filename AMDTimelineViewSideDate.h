//
//  AMDTimelineViewSideDate.h
//  AMDTimelineView
//
//  Copyright © 2016 Alejandro Melo Domínguez. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CGBase.h>

@interface AMDTimelineViewSideDate : NSObject
@property (strong, nonatomic) NSDate *date;
@property (assign, nonatomic) CGFloat initialPosition;
@end
