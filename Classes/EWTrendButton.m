/*
 * EWTrendButton.m
 * Created by Benjamin Ragheb on 12/24/09.
 * Copyright 2015 Heroic Software Inc
 *
 * This file is part of FatWatch.
 *
 * FatWatch is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * FatWatch is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with FatWatch.  If not, see <http://www.gnu.org/licenses/>.
 */

#import "EWTrendButton.h"
#import "BRRoundRectView.h"


void BRDrawDisclosureIndicator(CGContextRef ctxt, CGFloat x, CGFloat y) {
	// (x,y) is the tip of the arrow
	static const CGFloat R = 4.5f;
	static const CGFloat W = 3;
	CGContextSaveGState(ctxt);
	CGContextMoveToPoint(ctxt, x-R, y-R);
	CGContextAddLineToPoint(ctxt, x, y);
	CGContextAddLineToPoint(ctxt, x-R, y+R);
	CGContextSetLineCap(ctxt, kCGLineCapSquare);
	CGContextSetLineJoin(ctxt, kCGLineJoinMiter);
	CGContextSetLineWidth(ctxt, W);
	CGContextStrokePath(ctxt);
	CGContextRestoreGState(ctxt);
}


@implementation EWTrendButton
{
	NSMutableArray *partArray;
	CGSize marginSize;
	EWTrendButtonAccessoryType accessoryType;
}


@synthesize accessoryType;


- (void)awakeFromNib {
	//[self addTarget:self action:@selector(touchEventAction) forControlEvents:UIControlEventAllTouchEvents];
	marginSize = CGSizeMake(10, 4);
}


- (void)setHighlighted:(BOOL)flag {
	[super setHighlighted:flag];
	[self setNeedsDisplay];
}


- (NSMutableDictionary *)infoForPart:(NSUInteger)part {
	if (part < [partArray count]) {
		return partArray[part];
	}
	NSMutableDictionary *info = nil;
	UIColor *color = [UIColor blackColor];
	UIFont *font = [UIFont systemFontOfSize:17];
	if (partArray == nil) {
		partArray = [[NSMutableArray alloc] init];
	}
	while (part >= [partArray count]) {
		info = [[NSMutableDictionary alloc] init];
		info[@"font"] = font;
		info[@"color"] = color;
		[partArray addObject:info];
	}
	return info;
}


#pragma mark Public API


- (void)setText:(NSString *)text forPart:(int)part {
	[self infoForPart:part][@"text"] = text;
	[self setNeedsDisplay];
}


- (void)setTextColor:(UIColor *)color forPart:(int)part {
	[self infoForPart:part][@"color"] = color;
	[self setNeedsDisplay];
}


- (void)setFont:(UIFont *)font forPart:(int)part {
	[self infoForPart:part][@"font"] = font;
	[self setNeedsDisplay];
}


#pragma mark UIView


- (void)drawRect:(CGRect)rect {
	const CGFloat minFontSize = 6.0f;
	
	if (self.highlighted) {
		[[UIColor colorWithRed:0.2f green:0.2f blue:1 alpha:1] setFill];
		UIRectFill(self.bounds);
		[[UIColor whiteColor] setFill]; // for text
	}
	
	CGFloat remainingWidth = CGRectGetWidth(self.bounds) - (2*marginSize.width);
	
	if (self.enabled && accessoryType != EWTrendButtonAccessoryNone) {
		CGContextRef ctxt = UIGraphicsGetCurrentContext();
		
		if (self.highlighted) {
			CGContextSetRGBStrokeColor(ctxt, 1, 1, 1, 1);
			CGContextSetRGBFillColor(ctxt, 1, 1, 1, 1);
		} else {
			CGContextSetRGBStrokeColor(ctxt, 0.5f, 0.5f, 0.5f, 1);
			CGContextSetRGBFillColor(ctxt, 0.5f, 0.5f, 0.5f, 1);
		}
		
		CGFloat x = CGRectGetMaxX(self.bounds) - marginSize.width;
		CGFloat y = CGRectGetMidY(self.bounds);
		if (accessoryType == EWTrendButtonAccessoryDisclosureIndicator) {
			BRDrawDisclosureIndicator(ctxt, x, y);
		}
		else if (accessoryType == EWTrendButtonAccessoryToggle) {
			CGRect box = CGRectMake(x - 5.5f, y - 6, 7, 13);
			CGPathRef path = BRPathCreateRoundRect(box, 1);
			CGContextAddPath(ctxt, path);
			CGContextStrokePath(ctxt);
			CGPathRelease(path);
			
			box.size.height = 8;
			if (self.selected) box.origin.y = y - 1;
			
			CGContextAddRect(ctxt, CGRectInset(box, 1.5f, 1.5f));
			CGContextFillPath(ctxt);
		}	
		remainingWidth -= 12;
	}
	
	CGPoint p = CGPointMake(marginSize.width, marginSize.height);
	for (NSDictionary *info in partArray) {
		NSString *text = info[@"text"];
		
		if (text == nil) continue;

		if (! self.highlighted) {
			[info[@"color"] setFill];
		}

		UIFont *font = info[@"font"];
		CGFloat usedFontSize;
		CGSize size = [text sizeWithFont:font
							 minFontSize:minFontSize
						  actualFontSize:&usedFontSize
								forWidth:remainingWidth
						   lineBreakMode:NSLineBreakByClipping];
		
		[text drawAtPoint:p
				 forWidth:size.width
				 withFont:font
				 fontSize:usedFontSize
			lineBreakMode:NSLineBreakByClipping
	   baselineAdjustment:UIBaselineAdjustmentAlignBaselines];
		
		remainingWidth -= size.width;
		p.x += size.width;
	}
}


@end
