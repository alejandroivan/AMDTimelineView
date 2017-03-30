//
//  AMDTimelineViewSideDate.m
//  AMDTimelineView
//
//  Copyright © 2016 Alejandro Melo Domínguez. All rights reserved.
//


#import "AMDTimelineViewSideDate.h"

@implementation AMDTimelineViewSideDate

- (NSString *)description {
    return [NSString stringWithFormat:@"DATE: %@ - INITIAL POSITION: %f", self.date, self.initialPosition];
}

@end
