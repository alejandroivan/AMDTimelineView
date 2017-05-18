//
//  AMDTimelineView.m
//  AMDTimelineView
//
//  Copyright © 2016 Alejandro Melo Domínguez. All rights reserved.
//

#import "AMDTimelineView.h"
#import "AMDTimelineViewSideDate.h"

#ifndef TIMER_UPDATE_TIME
#define TIMER_UPDATE_TIME 0.2f // Seconds
#endif



@interface AMDTimelineView () // Internal properties and overriding "readonly"

@property (assign, nonatomic) double currentOffset;                             // Cummulative offset, which then is translated to an epoch and, from that, to an actual date.

@property (assign, nonatomic) CGFloat sideDateInternalOffset;                   // Offset from a timeline date indicator to its original position. If above a limit (the max distance), starts from 0 again.

@property (assign, nonatomic) CGFloat sideMarkerInternalOffset;                 // Offset from a sideMarker default position when dragging. If above the sideMarker distance, it starts from 0 again.
@property (assign, nonatomic) CGFloat sideMarkerDefaultDistance;                // Default distance between side markers. Calculated on the fly, 1 pixel = 1 second with minutes zoom scale.

@property (strong, nonatomic) UIPanGestureRecognizer *panGestureRecognizer;     // Calculates dates and offsets based on the user dragging the timeline.
@property (strong, nonatomic) UIPinchGestureRecognizer *pinchGestureRecognizer; // Calculates drawing scale based on the current zoom level or scale.

@property (strong, nonatomic) NSDateFormatter *dateFormatter;                   // Shared instance of a date formatter across all methods.
@property (strong, nonatomic) NSString *leftDateString;                         // Container for the date string at the left side of the timeline.
@property (strong, nonatomic) NSString *rightDateString;                        // Container for the date string at the right side of the timeline.

@property (strong, nonatomic) NSDate *initialDate;                              // Constant initial date for the timeline.
@property (assign, nonatomic) NSTimeInterval initialDateTimeInterval;           // Constant time interval for the initial date.

@property (assign, nonatomic) BOOL dragging;                                    // If YES, the timeline is currently being dragged.
@property (assign, nonatomic) BOOL zooming;                                     // If YES, the timeline is currently being zoomed.

@property (strong, nonatomic) NSTimer *timer;                                   // Timer for showing the current date.
@property (strong, nonatomic) NSTimer *internalTimer;                           // Internal timer for updating maximum, minimum and selected date accordingly.
#define AMD_INTERNAL_TIMER_UPDATE_TIME 0.2f                                     // Time (in seconds) to update using the internal timer.


@property (assign, nonatomic) CGFloat zoomLevel;                                // Bypassing "readonly"
@property (strong, nonatomic) NSDate *selectedDate;                             // Bypassing "readonly"

@property (strong, nonatomic) NSMutableArray *sideDates;

@end



@implementation AMDTimelineView {
    // Temporary variables for calculating intermediate stuff
    double _lastRedrawOffset;
    CGContextRef _ctx;
}


#pragma mark - Initialization

#pragma mark Initializer overrides
- (instancetype)initWithFrame:(CGRect)frame {
    if ( self = [super initWithFrame:frame] ) {
        [self setupDefaultValues];
        [self setupHelperProperties];
        [self setupTimer];
    }
    
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if ( self = [super initWithCoder:aDecoder] ) {
        [self setupDefaultValues];
        [self setupHelperProperties];
        [self setupTimer];
    }
    
    return self;
}

#pragma mark Default values
- (void)setupDefaultValues {
    
    // Dates
    self.minimumDate                                        = [NSDate dateWithTimeIntervalSince1970:[[NSDate date] timeIntervalSince1970] - 60*60*24*7*4*12*10]; // 10 years before current date
    self.maximumDate                                        = [NSDate date]; // Date of today
    self.selectedDate                                       = [NSDate date];
    self.initialDate                                        = [NSDate date];
    self.initialDateTimeInterval                            = [self.initialDate timeIntervalSince1970];
    
    // Colors
    self.backgroundColor                                    = [UIColor redColor];
    self.sideDatesForegroundColor                           = [UIColor darkGrayColor];
    self.sideDatesBackgroundColor                           = [UIColor colorWithRed:0.9f green:0.9f blue:0.9f alpha:0.7f];
    self.selectedDateForegroundColor                        = [UIColor whiteColor];
    self.selectedDateBackgroundColor                        = [UIColor darkGrayColor];
    self.centerMarkerColor                                  = [UIColor yellowColor];
    self.sideMarkerColor                                    = [UIColor darkGrayColor];
    self.horizontalLineColor                                = [UIColor blackColor];
    
    // Fonts
    self.selectedDateFont                                   = [UIFont fontWithName:@"HelveticaNeue"
                                                                              size:10.0f];
    self.sideDatesFont                                      = [UIFont fontWithName:@"HelveticaNeue"
                                                                              size:8.0f];
    
    // Zoom
    self.minimumZoomScale                                   = AMDTimelineViewZoomScaleWeeks;
    self.maximumZoomScale                                   = AMDTimelineViewZoomScaleMinutes;
    self.zoomLevel                                          = AMDTimelineViewZoomScaleMinutes;
    
    // Center marker
    self.centerMarkerWidth                                  = 4.0f;
    self.centerMarkerHeight                                 = 100.0f;
    self.centerMarkerVerticalDistanceFromBottom             = 20.0f;
    
    // Side markers
    self.sideMarkerWidth                                    = 2.0f;
    self.sideMarkerHeight                                   = 20.0f;
    self.sideMarkerVerticalDistanceFromHorizontalLine       = 0.0f;
    
    // Horizontal line
    self.horizontalLineHeight                               = 2.0f;
    self.horizontalLineVerticalDistanceFromCenterMarkerTop  = 8.0f;
    
    [self setContentMode:UIViewContentModeRedraw]; // Forces redrawing the control when something changes.
    
    
    self.dateFormatter.dateFormat   = @"ss"; // Get current seconds to set the initial offset for side markers
    CGFloat seconds                 = [[self.dateFormatter stringFromDate:self.initialDate] doubleValue];
    
    self.sideMarkerInternalOffset   = -seconds;
    self.currentOffset              = self.sideMarkerInternalOffset;
}

- (void)setupHelperProperties {
    
    // Pan gesture recognizer (drag)
    self.panGestureRecognizer                           = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                                                  action:@selector(timelineDragDetectedWithGestureRecognizer:)];
    self.panGestureRecognizer.enabled                   = YES;
    self.panGestureRecognizer.minimumNumberOfTouches    = 1;
    self.panGestureRecognizer.maximumNumberOfTouches    = 1;
    
    // Pinch gesture recognizer (zoom)
    self.pinchGestureRecognizer                         = [[UIPinchGestureRecognizer alloc] initWithTarget:self
                                                                                                    action:@selector(timelineZoomDetectedWithGestureRecognizer:)];
    self.pinchGestureRecognizer.enabled                 = YES;
    
    // Add gesture recognizers to view
    [self addGestureRecognizer:self.panGestureRecognizer];
    [self addGestureRecognizer:self.pinchGestureRecognizer];
}

- (void)setupTimer {
    self.internalTimer = [NSTimer scheduledTimerWithTimeInterval:AMD_INTERNAL_TIMER_UPDATE_TIME
                                                          target:self
                                                        selector:@selector(timerTick:)
                                                        userInfo:nil
                                                         repeats:YES];
}










#pragma mark - Timer updates
#pragma mark Internal timer
- (void)timerTick:(NSTimer *)timer {
    self.minimumDate = [self.minimumDate dateByAddingTimeInterval:AMD_INTERNAL_TIMER_UPDATE_TIME];
    self.maximumDate = [self.maximumDate dateByAddingTimeInterval:AMD_INTERNAL_TIMER_UPDATE_TIME];
    
    NSTimeInterval currentDateTI    = [self.selectedDate timeIntervalSince1970];
    NSTimeInterval minimumDateTI    = [self.minimumDate timeIntervalSince1970];
    NSTimeInterval maximumDateTI    = [self.maximumDate timeIntervalSince1970];
    
    currentDateTI                   = MAX(
                                          minimumDateTI,
                                          MIN(
                                              maximumDateTI,
                                              currentDateTI
                                              )
                                          );
    
    self.selectedDate               = [NSDate dateWithTimeIntervalSince1970:currentDateTI];
    
    [self setNeedsDisplay];
}







#pragma mark Public timer

- (BOOL)timerActive {
    return [self.timer isValid];
}

- (void)startTimer {
    self.timer = [NSTimer scheduledTimerWithTimeInterval:TIMER_UPDATE_TIME
                                                  target:self
                                                selector:@selector(userTimerTick:)
                                                userInfo:nil
                                                 repeats:YES];
}

- (void)stopTimer {
    [self.timer invalidate];
    self.timer = nil;
}

- (void)userTimerTick:(NSTimer *)timer {
    NSTimeInterval selectedDateTI   = [self.selectedDate timeIntervalSince1970] + TIMER_UPDATE_TIME;
    self.selectedDate               = [NSDate dateWithTimeIntervalSince1970:selectedDateTI];
    
    CGFloat maxSideDateDistance     = CGRectGetWidth(self.bounds) / 4;
    self.sideDateInternalOffset     = self.sideDateInternalOffset - TIMER_UPDATE_TIME * [self pixelMultiplierForZoomScale:self.zoomLevel];
    
    if ( ABS(self.sideDateInternalOffset) > maxSideDateDistance ) {
        NSNumber *dist              = @( self.sideDateInternalOffset );
        self.sideDateInternalOffset = [dist doubleValue] - [dist integerValue];
    }
    
    [self setNeedsDisplay];
}














#pragma mark - Gesture recognizer actions

#pragma mark Dragging
- (void)timelineDragDetectedWithGestureRecognizer:(UIPanGestureRecognizer *)recognizer {
    if ( self.zooming ) {
        // Avoid dragging the timeline when zooming.
        return;
    }
    
    [self stopTimer];
    
    CGPoint translation = [recognizer translationInView:self];
    [recognizer setTranslation:CGPointZero
                        inView:self];
    
    
    // Calculate the selected date
    NSTimeInterval timeIntervalDiff = -translation.x * [self pixelMultiplierForZoomScale:self.zoomLevel];
    NSDate *selDateTemp             = [self.selectedDate dateByAddingTimeInterval:timeIntervalDiff];
    self.selectedDate               = selDateTemp;
    
    if ( [selDateTemp timeIntervalSince1970] > [self.maximumDate timeIntervalSince1970] || [selDateTemp timeIntervalSince1970] < [self.minimumDate timeIntervalSince1970] ) {
        return;
    }
    
    // Update offsets
    self.currentOffset += translation.x * [self pixelMultiplierForZoomScale:self.zoomLevel];
    
    // Restrict self.sideMarkerInternalOffset to the maximum acceptable offset (1 point = 1 second)
    CGFloat maxSideMarkerDistance   = 60.0f / MAX( 1, self.maximumZoomScale - self.zoomLevel );
    CGFloat maxSideDateDistance     = CGRectGetWidth(self.bounds) / 4;
    
    // Avoid scrolling if a limit date was reached
    self.sideMarkerInternalOffset   += translation.x;
    self.sideDateInternalOffset     += translation.x;
    
    
    
    if ( ABS(self.sideMarkerInternalOffset) > maxSideMarkerDistance ) {
        NSUInteger multiplier           = ABS(self.sideMarkerInternalOffset) / maxSideMarkerDistance;
        CGFloat sign                    = self.sideMarkerInternalOffset < 0 ? -1 : 1;
        self.sideMarkerInternalOffset   = sign * ( ABS(self.sideMarkerInternalOffset) - multiplier * maxSideMarkerDistance ) ;
    }
    
    
    if ( ABS(self.sideDateInternalOffset) > maxSideDateDistance ) {
        NSUInteger multiplier       = ABS(self.sideDateInternalOffset) / maxSideDateDistance;
        CGFloat sign                = self.sideDateInternalOffset < 0 ? -1 : 1;
        self.sideDateInternalOffset = sign * ( ABS(self.sideDateInternalOffset) - multiplier * maxSideDateDistance ) ;
        [self reinitSideDates];
    }
    
    
    // Gesture recognizer states
    switch ( recognizer.state ) {
        case UIGestureRecognizerStateBegan:
            self.dragging = YES;
            
            if ( [self.delegate respondsToSelector:@selector(timeline:didStartDraggingFromDate:)] ) {
                [self.delegate timeline:self
               didStartDraggingFromDate:self.selectedDate];
            }
            
            break;
            
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateFailed:
        case UIGestureRecognizerStateCancelled:
            self.dragging = NO;
            
            // Inform the delegate that a date was picked
            if ( [self.delegate respondsToSelector:@selector(timeline:didStopDraggingAtDate:)] ) {
                [self.delegate timeline:self
                  didStopDraggingAtDate:self.selectedDate];
            }
            
            break;
            
        default:
            break;
    }
    
    // Redibujar timeline
    [self setNeedsDisplay];
}


#pragma mark Zooming
- (void)timelineZoomDetectedWithGestureRecognizer:(UIPinchGestureRecognizer *)recognizer {
    if ( self.dragging ) {
        // Avoid zooming the timeline when dragging.
        return;
    }
    
    CGFloat zoomSpeed   = 0.05f;
    CGFloat scale       = ABS( recognizer.scale );
    CGFloat sign        = recognizer.velocity < 0 ? -1 : 1;
    CGFloat speed       = sign > 0 ? zoomSpeed : zoomSpeed;
    
    CGFloat delta       = sign * scale * speed;
    
    self.zoomLevel      = MIN(
                              self.maximumZoomScale,
                              MAX(
                                  self.minimumZoomScale,
                                  self.zoomLevel + delta
                                  )
                              );
    
    switch ( recognizer.state ) {
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
        case UIGestureRecognizerStateEnded: {
            self.zoomLevel                  = [self zoomScaleFromZoomLevel:self.zoomLevel];
            self.sideMarkerInternalOffset   /= [self zoomScaleFromZoomLevel:self.zoomLevel];
            
            [self.sideDates removeAllObjects];
            [self reinitSideDates];
            
            if ( [self.delegate respondsToSelector:@selector(timeline:didChangeZoomScale:)] ) {
                [self.delegate timeline:self
                     didChangeZoomScale:self.zoomLevel];
            }
            
            break;
        }
            
        default:
            break;
    }
    
    [self setNeedsDisplay];
}





























#pragma mark - Drawing

// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
    CGContextRef ctx    = UIGraphicsGetCurrentContext();
    _ctx                = ctx; // Keep a strong reference to the graphics context to avoid possible dealloc issues
    
    // Call in order: from the lowest element until the top one
    [self drawBackgroundColor:ctx];
    [self drawHorizontalLine:ctx];
    [self drawDateString:ctx];
    [self drawCentralMarker:ctx];
    [self drawSideDatesStrings:ctx];
}










- (void)drawBackgroundColor:(CGContextRef)ctx {
    CGContextSetFillColorWithColor(ctx, self.backgroundColor.CGColor);
    CGContextFillRect(ctx, self.bounds);
}










- (void)drawHorizontalLine:(CGContextRef)ctx {
    CGFloat distanceFromTop = CGRectGetMaxY(self.bounds) - self.centerMarkerVerticalDistanceFromBottom - self.centerMarkerHeight - self.horizontalLineVerticalDistanceFromCenterMarkerTop;
    CGPoint startPoint      = CGPointMake(CGRectGetMinX(self.bounds), distanceFromTop);
    CGPoint endPoint        = CGPointMake(startPoint.x + CGRectGetMaxX(self.bounds), distanceFromTop);
    
    CGContextMoveToPoint(ctx, startPoint.x, startPoint.y);
    CGContextSetStrokeColorWithColor(ctx, self.horizontalLineColor.CGColor);
    CGContextSetLineWidth(ctx, self.horizontalLineHeight);
    CGContextAddLineToPoint(ctx, endPoint.x, endPoint.y);
    CGContextStrokePath(ctx);
}











- (void)drawDateString:(CGContextRef)ctx {
    
    // CONTAINER
    
    CGFloat margin          = 2.0f;  // Margin from the elements nearby (sides of the container, bottom of the container and the bottom of the center marker)
    CGRect containerFrame   = CGRectMake(margin,
                                         CGRectGetMaxY(self.bounds) - self.centerMarkerVerticalDistanceFromBottom + margin,
                                         CGRectGetMaxX(self.bounds) - 2 * margin,
                                         self.centerMarkerVerticalDistanceFromBottom - 2 * margin);
    
    
    CGContextSetFillColorWithColor(ctx, self.selectedDateBackgroundColor.CGColor);
    CGContextFillRect(ctx, containerFrame);
    
    
    // STRING (horizontally and vertically centered inside the container)
    
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.alignment                = NSTextAlignmentCenter;
    
    self.dateFormatter.dateFormat           = @"dd/MM/yyyy HH:mm:ss";
    NSString *dateString                    = [self.dateFormatter stringFromDate:self.selectedDate];
    NSDictionary *attributes                = @{
                                                NSFontAttributeName             : self.selectedDateFont,
                                                NSParagraphStyleAttributeName   : paragraphStyle,
                                                NSForegroundColorAttributeName  : self.selectedDateForegroundColor,
                                                };
    CGSize textSize                         = [dateString sizeWithAttributes:attributes];
    CGFloat offset                          = ( CGRectGetHeight(containerFrame) - textSize.height ) / 2;
    CGRect textFrame                        = CGRectMake(CGRectGetMinX(containerFrame),
                                                         CGRectGetMinY(containerFrame) + offset,
                                                         CGRectGetWidth(containerFrame),
                                                         CGRectGetHeight(containerFrame) - 2 * offset);
    
    [dateString drawInRect:textFrame
            withAttributes:attributes];
}









static NSInteger numberOfSideDates = 6;

- (void)reinitSideDates {
    CGFloat distance        = CGRectGetWidth(self.bounds) / 4;
    CGFloat initialDistance = - ( ( numberOfSideDates + 1 ) / 2 ) * distance;
    
    
    // Set the side dates every time the view is shown or zoomed
    if ( ! self.sideDates || self.sideDates.count == 0 ) {
        
        _lastRedrawOffset           = self.currentOffset;
        self.sideDateInternalOffset = 0.0f;
        self.sideDates              = [[NSMutableArray alloc] init];
        
        double pos                  = initialDistance;
        
        for ( NSUInteger i = 0; i < numberOfSideDates + 1; i++ ) {
            double secondsOffset                = pos * [self pixelMultiplierForZoomScale:self.zoomLevel];

            NSCalendar *currentCalendar         = [NSCalendar currentCalendar];
            NSDateComponents *components        = [[NSDateComponents alloc] init];
            
            [components setSecond:[@(secondsOffset) integerValue]];
            
            NSDate *offsetDate                  = [currentCalendar dateByAddingComponents:components
                                                                                   toDate:self.selectedDate
                                                                                  options:kNilOptions];
            
            AMDTimelineViewSideDate *sideDate   = [[AMDTimelineViewSideDate alloc] init];
            sideDate.initialPosition            = pos;
            sideDate.date                       = offsetDate;
            
            [self.sideDates addObject:sideDate];
            pos += distance;
        }
        
    }
    
    
    // If dragged, change the position of the dates
    else if ( self.currentOffset > _lastRedrawOffset ) { // The right date disappears and goes to the left side
        _lastRedrawOffset                   = self.currentOffset;
        AMDTimelineViewSideDate *lastDate   = [self.sideDates lastObject];
        
        [self.sideDates removeLastObject];
        [self.sideDates insertObject:lastDate
                             atIndex:0];
        
        // Recalculate initial positions
        
        double pos = initialDistance;
        
        for ( NSUInteger i = 0, total = self.sideDates.count; i < total; i++ ) {
            
            AMDTimelineViewSideDate *sideDate   = self.sideDates[i];
            sideDate.initialPosition            = pos;
            
            if ( i == 0 ) {
                double secondsOffset                = pos * [self pixelMultiplierForZoomScale:self.zoomLevel];
                
                NSCalendar *currentCalendar         = [NSCalendar currentCalendar];
                NSDateComponents *components        = [[NSDateComponents alloc] init];
                
                [components setSecond:[@(secondsOffset) integerValue]];
                
                NSDate *offsetDate                  = [currentCalendar dateByAddingComponents:components
                                                                                       toDate:self.selectedDate
                                                                                      options:kNilOptions];
                
                sideDate.date = offsetDate; // If i = 0, then it's the date that was moved from the right... update the stored date
            }
            
            pos += distance;
        }
        
    }
    
    
    else { // The left date disappears and goes to the right side
        AMDTimelineViewSideDate *firstDate = [self.sideDates firstObject];

        [self.sideDates removeObjectAtIndex:0];
        [self.sideDates addObject:firstDate]; // The initial date goes to the end of the list
        
        // Recalculate initial positions
        
        double pos = initialDistance;
        for ( NSUInteger i = 0, total = self.sideDates.count; i < total; i++ ) {
            
            AMDTimelineViewSideDate *sideDate   = self.sideDates[i];
            sideDate.initialPosition            = pos;
            
            if ( i == self.sideDates.count-1 ) { // If i = total - 1, then it's the side date that was moved from the beginning of the array... update it's stored date
                double secondsOffset                = pos * [self pixelMultiplierForZoomScale:self.zoomLevel];
                
                NSCalendar *currentCalendar         = [NSCalendar currentCalendar];
                NSDateComponents *components        = [[NSDateComponents alloc] init];
                
                [components setSecond:[@(secondsOffset) integerValue]];
                
                NSDate *offsetDate                  = [currentCalendar dateByAddingComponents:components
                                                                                       toDate:self.selectedDate
                                                                                      options:kNilOptions];
                
                sideDate.date                       = offsetDate;
            }
            
            pos += distance;
        }
        
    }
    
}



static CGFloat sideDateWidth = 80.0f;

- (void)drawSideDatesStrings:(CGContextRef)ctx {
    if ( ! self.sideDates || self.sideDates.count == 0 ) {
        [self reinitSideDates];
    }
    
    
    
    for ( NSUInteger i = 0, total = self.sideDates.count; i < total; i++ ) {
        AMDTimelineViewSideDate *sideDate   = self.sideDates[i];
        CGFloat finalCenter                 = sideDate.initialPosition + self.sideDateInternalOffset + CGRectGetMidX(self.bounds);
        CGFloat alphaBorder                 = sideDateWidth * 2;
        
        if ( finalCenter <  CGRectGetMidX(self.bounds) - alphaBorder || finalCenter > CGRectGetMidX(self.bounds) + alphaBorder ) {
            [self drawDate:sideDate.date
                centeredIn:finalCenter
                     alpha:1.0f
                   context:ctx];
        }
        else {
            CGFloat alpha = ABS(CGRectGetMidX(self.bounds) - finalCenter) / alphaBorder;
            
            [self drawDate:sideDate.date
                centeredIn:finalCenter
                     alpha:alpha
                   context:ctx];
            
        }
    }
}

- (void)drawDate:(NSDate *)date centeredIn:(double)horizontalCenter alpha:(CGFloat)alpha context:(CGContextRef)ctx {
    
    CGFloat sideMarkerTop                   = CGRectGetMaxY(self.bounds) - ( self.centerMarkerVerticalDistanceFromBottom + self.centerMarkerHeight + self.horizontalLineVerticalDistanceFromCenterMarkerTop );
    CGFloat sideMarkerHeightMultiplier      = self.centerMarkerHeight / 4 * 2/3;
    CGFloat sideMarkerBottom                = sideMarkerTop + sideMarkerHeightMultiplier * self.zoomLevel;
    
    CGFloat margin                          = 4.0f;
    CGFloat width                           = sideDateWidth;
    CGFloat top                             = sideMarkerBottom + margin;
    CGFloat left                            = horizontalCenter - width / 2;
    
    self.dateFormatter.dateFormat           = [self dateFormatForScale:self.zoomLevel];
    NSString *sideDateString                = [self.dateFormatter stringFromDate:date];
    
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.alignment                = NSTextAlignmentCenter;
    NSDictionary *attributes                = @{
                                                NSFontAttributeName             : self.sideDatesFont,
                                                NSParagraphStyleAttributeName   : paragraphStyle,
                                                NSForegroundColorAttributeName  : [self.sideDatesForegroundColor colorWithAlphaComponent:alpha]
                                                };
    
    CGRect dateContainer                    = CGRectMake(left, // + CGRectGetWidth(self.bounds) / 2,
                                                         top,
                                                         width,
                                                         30.0f);
    
    CGSize textSize                         = [sideDateString sizeWithAttributes:attributes];
    CGFloat offset                          = ( CGRectGetHeight(dateContainer) - textSize.height ) / 2;
    CGRect textFrame                        = CGRectMake(CGRectGetMinX(dateContainer),
                                                         CGRectGetMinY(dateContainer) + offset,
                                                         CGRectGetWidth(dateContainer),
                                                         CGRectGetHeight(dateContainer) - 2 * offset);
    
    CGFloat deltaY                          = CGRectGetMidY(textFrame) - CGRectGetMinY(textFrame);
    
    [self drawSideMarkerFromBottomPoint:CGPointMake(CGRectGetMidX(textFrame),
                                                    CGRectGetMidY(textFrame) - 2 * deltaY)
                                  alpha:alpha
                                context:ctx];
    
    [sideDateString drawInRect:textFrame
                withAttributes:attributes];
}

- (void)updateSideDatesOffsets:(CGContextRef)ctx {
    for ( NSUInteger i = 0, total = self.sideDates.count; i < total; i++ ) {
        
        AMDTimelineViewSideDate *sideDate   = self.sideDates[i];
        CGFloat finalCenter                 = sideDate.initialPosition + self.sideDateInternalOffset + CGRectGetMidX(self.bounds);
        CGFloat alphaBorder                 = sideDateWidth * 2;
        
        if ( finalCenter <  CGRectGetMidX(self.bounds) - alphaBorder || finalCenter > CGRectGetMidX(self.bounds) + alphaBorder ) {
            [self drawDate:sideDate.date
                centeredIn:finalCenter
                     alpha:1.0f
                   context:ctx];
        }
        else {
            CGFloat alpha = ABS(CGRectGetMidX(self.bounds) - finalCenter) / alphaBorder;
            
            [self drawDate:sideDate.date
                centeredIn:finalCenter
                     alpha:alpha
                   context:ctx];
            
        }
        
    }
}

- (void)drawSideMarkerFromBottomPoint:(CGPoint)bottomPoint alpha:(CGFloat)alpha context:(CGContextRef)ctx {
    
    CGFloat sideMarkerTop   = CGRectGetMaxY(self.bounds) - ( self.centerMarkerVerticalDistanceFromBottom + self.centerMarkerHeight + self.horizontalLineVerticalDistanceFromCenterMarkerTop );
    CGPoint topPoint        = CGPointMake(bottomPoint.x,
                                          sideMarkerTop);
    
    
    
    CGContextSetStrokeColorWithColor(ctx, [[self.sideMarkerColor colorWithAlphaComponent:alpha] CGColor]);
    CGContextSetLineWidth(ctx, self.sideMarkerWidth);
    
    CGContextMoveToPoint(ctx, topPoint.x, topPoint.y);
    CGContextAddLineToPoint(ctx, bottomPoint.x, bottomPoint.y);
    
    CGContextStrokePath(ctx);
}










- (void)drawCentralMarker:(CGContextRef)ctx {
    
    // Below part (rectangle)
    
    CGPoint startPoint  = CGPointMake(CGRectGetWidth(self.bounds) / 2,
                                      CGRectGetHeight(self.bounds) - self.centerMarkerVerticalDistanceFromBottom); // Bottom point
    CGPoint endPoint    = CGPointMake(startPoint.x,
                                      startPoint.y - self.centerMarkerHeight);  // Top point
    
    CGContextMoveToPoint(ctx, startPoint.x, startPoint.y);
    CGContextSetStrokeColorWithColor(ctx, self.centerMarkerColor.CGColor);
    CGContextSetLineWidth(ctx, self.centerMarkerWidth);
    CGContextAddLineToPoint(ctx, endPoint.x, endPoint.y);
    CGContextStrokePath(ctx);
    
    
    // Top part (triangle)
    CGRect triangleContainer = CGRectMake(endPoint.x - self.centerMarkerWidth / 2,
                                          endPoint.y - self.horizontalLineVerticalDistanceFromCenterMarkerTop,
                                          self.centerMarkerWidth,
                                          self.horizontalLineVerticalDistanceFromCenterMarkerTop);
    
    CGContextSetFillColorWithColor(ctx, self.centerMarkerColor.CGColor);
    CGContextSetLineWidth(ctx, CGFLOAT_MIN);
    
    CGContextMoveToPoint(ctx, CGRectGetMinX(triangleContainer), CGRectGetMaxY(triangleContainer)); // Bottom-left
    CGContextAddLineToPoint(ctx, CGRectGetMidX(triangleContainer), CGRectGetMinY(triangleContainer)); // Middle-top
    CGContextAddLineToPoint(ctx, CGRectGetMaxX(triangleContainer), CGRectGetMaxY(triangleContainer)); // Bottom-right
    
    CGContextClosePath(ctx); // Join final points of lines
    CGContextFillPath(ctx);
}































#pragma mark -
#pragma mark -



#pragma mark - Custom setters/getters

#pragma mark Setters
- (NSDateFormatter *)dateFormatter {
    if ( ! _dateFormatter ) {
        _dateFormatter = [[NSDateFormatter alloc] init];
    }
    
    return _dateFormatter;
}

- (void)setSelectedDate:(NSDate *)selectedDate {
    NSTimeInterval argumentDateTI   = [selectedDate timeIntervalSince1970];
    NSTimeInterval maximumDateTI    = self.maximumDate ? [self.maximumDate timeIntervalSince1970] : argumentDateTI;
    NSTimeInterval minimumDateTI    = self.minimumDate ? [self.minimumDate timeIntervalSince1970] : argumentDateTI;
    NSTimeInterval selectedDateTI   = MAX( minimumDateTI, MIN( argumentDateTI, maximumDateTI ) );
    
    _selectedDate   = [NSDate dateWithTimeIntervalSince1970:selectedDateTI];
}

- (void)setMinimumDate:(NSDate *)minimumDate {
    NSTimeInterval argumentDateTI   = [minimumDate timeIntervalSince1970];
    NSTimeInterval selectedDateTI   = self.selectedDate ? [self.selectedDate timeIntervalSince1970] : argumentDateTI;
    NSTimeInterval minimumDateTI    = MIN( argumentDateTI, selectedDateTI );
    
    _minimumDate = [NSDate dateWithTimeIntervalSince1970:minimumDateTI];
}

- (void)setMaximumDate:(NSDate *)maximumDate {
    NSTimeInterval argumentDateTI   = [maximumDate timeIntervalSince1970];
    NSTimeInterval selectedDateTI   = self.selectedDate ? [self.selectedDate timeIntervalSince1970] : argumentDateTI;
    NSTimeInterval maximumDateTI    = MAX( argumentDateTI, selectedDateTI );
    
    _maximumDate = [NSDate dateWithTimeIntervalSince1970:maximumDateTI];
}


- (void)goToDate:(NSDate *)date {
    [self goToDate:date
    informDelegate:YES];
}

- (void)goToDate:(NSDate *)date informDelegate:(BOOL)informDelegate {
    self.selectedDate   = date;
    self.sideDates      = nil; // Force redrawing of side dates
    [self setNeedsDisplay];
    
    if ( informDelegate && [self.delegate respondsToSelector:@selector(timeline:didStopDraggingAtDate:)] ) {
        [self.delegate timeline:self
          didStopDraggingAtDate:date];
    }
}







#pragma mark - Scale multipliers
- (NSString *)dateFormatForScale:(AMDTimelineViewZoomScale)scale {
    switch ( scale ) {
        case AMDTimelineViewZoomScaleMinutes:
            return @"HH:mm:ss";
            
        default:
            return @"dd/MM/yyyy\nHH:mm:ss";
    }
}

- (CGFloat)multiplierForScreen {
    return [[UIScreen mainScreen] scale];
}

- (double)pixelMultiplierForZoomScale:(AMDTimelineViewZoomScale)zoomScale {
    double multiplier;
    
    switch ( zoomScale ) {
        case AMDTimelineViewZoomScaleMinutes:
        default:
            multiplier = 1.0f;
            break;
            
        case AMDTimelineViewZoomScaleHours:
            multiplier = 60.0f * 60.0f;
            break;
            
        case AMDTimelineViewZoomScaleDays:
            multiplier = 60.0f * 60.0f * 24.0f;
            break;
            
        case AMDTimelineViewZoomScaleWeeks:
            multiplier = 60.0f * 60.0f * 24.0f * 7.0f;
            break;
    }
    
    return multiplier;
}

- (double)secondsPerPixelWithZoomScale:(double)zoomScale {
    double secondsPerPixel;
    
    NSUInteger zoom = zoomScale;
    CGFloat scale   = [@(zoomScale) doubleValue] - [@(zoomScale) integerValue];
    
    if ( scale > 0.7f ) {
        zoom++;
    }
    
    switch ( zoom ) {
        case AMDTimelineViewZoomScaleMinutes:
        default:
            secondsPerPixel = 1.0f;
            break;
            
        case AMDTimelineViewZoomScaleHours:
            secondsPerPixel = 1 / ( 60.0f );
            break;
            
        case AMDTimelineViewZoomScaleDays:
            secondsPerPixel = 1 / ( 60.0f * 60.0f );
            break;
            
        case AMDTimelineViewZoomScaleWeeks:
            secondsPerPixel = 1 / ( 60.0f * 60.0f * 24 );
            break;
    }
    
    return secondsPerPixel;
}

- (AMDTimelineViewZoomScale)zoomScaleFromZoomLevel:(CGFloat)zoomLevel {
    NSNumber *zoom                  = [NSNumber numberWithFloat:zoomLevel];
    CGFloat remainder               = [zoom doubleValue] - [zoom integerValue];
    AMDTimelineViewZoomScale scale  = [zoom integerValue];
    
    if ( remainder > 0.7f ) {
        scale++;
    }
    
    return scale;
}

@end
