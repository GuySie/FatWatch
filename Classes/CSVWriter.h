//
//  CSVWriter.h
//  EatWatch
//
//  Created by Benjamin Ragheb on 5/17/08.
//  Copyright 2008 Benjamin Ragheb. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface CSVWriter : NSObject {
	NSMutableData *data;
	NSInteger columnIndex;
	NSCharacterSet *quotedCharSet;
}
- (void)addString:(NSString *)value;
- (void)addFloat:(float)value;
- (void)addBoolean:(BOOL)value;
- (void)endRow;
- (NSData *)data;
@end