//
//  AMDTimelineViewDelegate.h
//  AMDTimelineView
//
//  Copyright © 2016 Alejandro Melo Domínguez. All rights reserved.
//

#ifndef AMDTimelineViewDelegate_h
#define AMDTimelineViewDelegate_h

#import "AMDTimelineViewZoomScale.h"

@class AMDTimelineView;
@protocol AMDTimelineViewDelegate <NSObject>

- (void)timeline:(AMDTimelineView *)timeline didChangeDate:(NSDate *)newDate;
- (void)timeline:(AMDTimelineView *)timeline didChangeZoomScale:(AMDTimelineViewZoomScale)newZoomScale;

@end

#endif /* AMDTimelineViewDelegate_h */