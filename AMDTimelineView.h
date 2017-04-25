//
//  AMDTimelineView.h
//  AMDTimelineView
//
//  Copyright © 2016 Alejandro Melo Domínguez. All rights reserved.
//


#import <UIKit/UIKit.h>
#import "AMDTimelineViewDelegate.h"
#import "AMDTimelineViewZoomScale.h"


IB_DESIGNABLE
@interface AMDTimelineView : UIView











#pragma mark - Colors
#pragma mark Background
@property (strong, nonatomic) IBInspectable UIColor *backgroundColor;

#pragma mark Dates
@property (strong, nonatomic) IBInspectable UIColor *sideDatesForegroundColor;
@property (strong, nonatomic) IBInspectable UIColor *sideDatesBackgroundColor;
@property (strong, nonatomic) IBInspectable UIColor *selectedDateForegroundColor;
@property (strong, nonatomic) IBInspectable UIColor *selectedDateBackgroundColor;

#pragma mark Markers
@property (strong, nonatomic) IBInspectable UIColor *centerMarkerColor;
@property (strong, nonatomic) IBInspectable UIColor *sideMarkerColor;

#pragma mark Other elements
@property (strong, nonatomic) IBInspectable UIColor *horizontalLineColor;










#pragma mark - Fonts
@property (strong, nonatomic) IBInspectable UIFont *selectedDateFont;
@property (strong, nonatomic) IBInspectable UIFont *sideDatesFont;










#pragma mark - Delegate
@property (weak, nonatomic) id<AMDTimelineViewDelegate> delegate;










#pragma mark - Timers

#define TIMER_UPDATE_TIME   0.2f    // Default is 0.2 seconds

- (BOOL)timerActive;    // Determines if the timer is active (YES) or not (NO).
- (void)startTimer;     // Starts a timer that moves the center marker with the pass of time. It stops automatically when dragging the timeline.
- (void)stopTimer;      // Stop the current timer.









#pragma mark - Dates
@property (strong, nonatomic, readonly) NSDate *selectedDate;   // Current date selected by the user in the timeline.
@property (strong, nonatomic) NSDate *minimumDate;              // Minimum selectable date in the timeline.
@property (strong, nonatomic) NSDate *maximumDate;              // Maximum selectable date in the timeline.

- (void)goToDate:(NSDate *)date;










#pragma mark - Zoom
#pragma mark Levels
/*
 DEFINITIONS
 ===========
 
 Zoom Level:
    A CGFloat that represents the zoom level of the timeline. Fluctuates between self.minimumZoomScale and self.maximumZoomScale
    
 Zoom scale:
    Similar to zoom levels, but they're integer numbers. When the user stops zooming the timeline, it should be scaled to
    an actual zoom scale to make calculations of time based on the current scale and NOT the current zoom level.
    The timeline delegate object will get zoom scales and not zoom levels.
 
    See AMDTimelineViewZoomScale.h for defined zoom scales and their values.
 */
@property (assign, nonatomic) AMDTimelineViewZoomScale minimumZoomScale;
@property (assign, nonatomic) AMDTimelineViewZoomScale maximumZoomScale;
@property (assign, nonatomic, readonly) CGFloat zoomLevel;










#pragma mark - Sizes
/*
 These values are used with the starting zoom scale and could change to adapt the current zoom level.
 */

#pragma mark Center marker
@property (assign, nonatomic) IBInspectable CGFloat centerMarkerWidth;
@property (assign, nonatomic) IBInspectable CGFloat centerMarkerHeight;
@property (assign, nonatomic) IBInspectable CGFloat centerMarkerVerticalDistanceFromBottom;

#pragma mark Side marker
@property (assign, nonatomic) IBInspectable CGFloat sideMarkerWidth;
@property (assign, nonatomic) IBInspectable CGFloat sideMarkerHeight;
@property (assign, nonatomic) IBInspectable CGFloat sideMarkerVerticalDistanceFromHorizontalLine;

#pragma mark Horizontal line
@property (assign, nonatomic) IBInspectable CGFloat horizontalLineVerticalDistanceFromCenterMarkerTop;
@property (assign, nonatomic) IBInspectable CGFloat horizontalLineHeight;











@end
