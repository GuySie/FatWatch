//
//  EWGoal.m
//  EatWatch
//
//  Created by Benjamin Ragheb on 8/19/08.
//  Copyright 2008 Benjamin Ragheb. All rights reserved.
//

#import "EWGoal.h"
#import "Database.h"
#import "MonthData.h"
#import "WeightFormatters.h"


static NSString *kGoalStartDateKey = @"GoalStartDate";
static NSString *kGoalWeightKey = @"GoalWeight";
static NSString *kGoalWeightChangePerDayKey = @"GoalWeightChangePerDay";


@implementation EWGoal


+ (BOOL)isBMIEnabled {
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	return [defs boolForKey:@"BMIEnabled"];
}


+ (void)setBMIEnabled:(BOOL)flag {
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	[defs setBool:flag forKey:@"BMIEnabled"];
}


+ (void)setHeight:(float)meters {
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	[defs setFloat:meters forKey:@"BMIHeight"];
}


+ (float)height {
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	return [defs floatForKey:@"BMIHeight"];
}


+ (void)deleteGoal {
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	[defs removeObjectForKey:kGoalStartDateKey];
	[defs removeObjectForKey:kGoalWeightKey];
	[defs removeObjectForKey:kGoalWeightChangePerDayKey];
}


+ (void)fixHeightIfNeeded {
	static NSString *kHeightFixAppliedKey = @"EWFixedBug0000017";
	NSUserDefaults *uds = [NSUserDefaults standardUserDefaults];
	
	if ([uds boolForKey:kHeightFixAppliedKey]) return;
	
	// To fix a stupid bug where all height values were offset by 1 cm,
	// causing weird results when measuring in inches.
	if ([WeightFormatters heightIncrement] > 0.01f) {
		float height = [EWGoal height];
		float error = fmodf(height, 0.0254f);
		if (fabsf(error - 0.01f) < 0.0001f) {
			[EWGoal setHeight:(height - 0.01f)];
			NSLog(@"Bug 0000017: Height adjusted from %f to %f", height, [EWGoal height]);
		}
	}

	[uds setBool:YES forKey:kHeightFixAppliedKey];
}


+ (EWGoal *)sharedGoal {
	static EWGoal *goal = nil;
	
	if (goal == nil) {
		[self fixHeightIfNeeded];
		goal = [[EWGoal alloc] init];
	}
	
	return goal;
}


- (BOOL)isDefined {
	BOOL b;
	
	@synchronized (self) {
		b = [[NSUserDefaults standardUserDefaults] objectForKey:kGoalWeightKey] != nil;
	}
	return b;
}


- (BOOL)isAttained {
	BOOL b;
	
	@synchronized (self) {
		float s = self.startWeight;
		float e = self.endWeight;
		float w = [self weightOnDate:[NSDate date]];
		b = (s >= e && e >= w) || (s <= e && e <= w);
	}
	return b;
}


- (NSDate *)startDate {
	NSDate *d;
	
	@synchronized (self) {
		NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
		NSNumber *number = [defs objectForKey:kGoalStartDateKey];
		if (number) {
			d = [NSDate dateWithTimeIntervalSinceReferenceDate:[number doubleValue]];
		} else {
			NSDate *date = [NSDate date];
			self.startDate = date;
			d = date;
		}
	}
	return d;
}


- (void)setStartDate:(NSDate *)date {
	@synchronized (self) {
		[self willChangeValueForKey:@"startDate"];
		[self willChangeValueForKey:@"startWeight"];
		[self willChangeValueForKey:@"endDate"];
		[[NSUserDefaults standardUserDefaults] setDouble:[date timeIntervalSinceReferenceDate] forKey:kGoalStartDateKey];
		[self didChangeValueForKey:@"startDate"];
		[self didChangeValueForKey:@"startWeight"];
		[self didChangeValueForKey:@"endDate"];
	}
}


- (EWMonthDay)startMonthDay {
	return EWMonthDayFromDate(self.startDate);
}


- (float)endWeight {
	float w;
	
	@synchronized (self) {
		w = [[NSUserDefaults standardUserDefaults] floatForKey:kGoalWeightKey];
	}
	return w;
}


- (void)setEndWeight:(float)weight {
	@synchronized (self) {
		[self willChangeValueForKey:@"endWeight"];
		[self willChangeValueForKey:@"endWeightNumber"];
		[self willChangeValueForKey:@"endDate"];
		[self willChangeValueForKey:@"endBMI"];
		[self willChangeValueForKey:@"endBMINumber"];
		[[NSUserDefaults standardUserDefaults] setFloat:weight forKey:kGoalWeightKey];
		// make sure sign matches
		float weightChange = weight - self.startWeight;
		float delta = self.weightChangePerDay;
		if ((weightChange > 0 && delta < 0) || (weightChange < 0 && delta > 0)) {
			self.weightChangePerDay = -delta;
		}
		[self didChangeValueForKey:@"endWeight"];
		[self didChangeValueForKey:@"endWeightNumber"];
		[self didChangeValueForKey:@"endDate"];
		[self didChangeValueForKey:@"endBMI"];
		[self didChangeValueForKey:@"endBMINumber"];
	}
}


- (NSNumber *)endWeightNumber {
	float w = self.endWeight;
	if (w > 0) {
		return [NSNumber numberWithFloat:w];
	} else {
		return nil;
	}
}


- (void)setEndWeightNumber:(NSNumber *)number {
	self.endWeight = [number floatValue];
}


- (float)endBMI {
	return [WeightFormatters bodyMassIndexForWeight:[self endWeight]];
}


- (void)setEndBMI:(float)bmi {
	float w = [WeightFormatters weightForBodyMassIndex:bmi];
	[self setEndWeight:w];
}


- (NSNumber *)endBMINumber {
	float b = self.endBMI;
	if (b > 0) {
		return [NSNumber numberWithFloat:b];
	} else {
		return nil;
	}
}


- (void)setEndBMINumber:(NSNumber *)number {
	self.endBMI = [number floatValue];
}


- (float)weightChangePerDay {
	float delta;
	
	@synchronized (self) {
		NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
		NSNumber *number = [defs objectForKey:kGoalWeightChangePerDayKey];
		if (number) {
			delta = [number floatValue];
		} else {
			delta = [WeightFormatters defaultWeightChange];
			self.weightChangePerDay = delta;
		}
	}
	return delta;
}


- (void)setWeightChangePerDay:(float)delta {
	@synchronized (self) {
		[self willChangeValueForKey:@"weightChangePerDay"];
		[self willChangeValueForKey:@"endDate"];
		// make sure sign matches
		float weightChange = self.endWeight - self.startWeight;
		if ((weightChange > 0 && delta < 0) || (weightChange < 0 && delta > 0)) {
			delta = -delta;
		}
		[[NSUserDefaults standardUserDefaults] setFloat:delta forKey:kGoalWeightChangePerDayKey];
		[self didChangeValueForKey:@"weightChangePerDay"];
		[self didChangeValueForKey:@"endDate"];
	}
}


- (float)weightOnDate:(NSDate *)date {
	EWMonthDay startMonthDay = EWMonthDayFromDate(date);
	MonthData *md = [[Database sharedDatabase] dataForMonth:EWMonthDayGetMonth(startMonthDay)];
	float w;

	w = [md trendWeightOnDay:EWMonthDayGetDay(startMonthDay)];
	if (w > 0) return w;
	
	w = [md inputTrendOnDay:EWMonthDayGetDay(startMonthDay)];
	if (w > 0) return w;
	
	// there is no weight earlier than this day, so search the future
	MonthData *searchData = md;
	while (searchData != nil) {
		EWDay searchDay = [searchData firstDayWithWeight];
		if (searchDay > 0) {
			return [searchData scaleWeightOnDay:searchDay];
		}
		searchData = searchData.nextMonthData;
	}
	
	// we shouldn't get here because this method shouldn't be called if the 
	// database is empty
	return 0;
}


- (float)startWeight {
	float w;
	
	@synchronized (self) {
		w = [self weightOnDate:self.startDate];
	}
	return w;
}


- (float)startBMI {
	return [WeightFormatters bodyMassIndexForWeight:[self startWeight]];
}


- (NSDate *)endDateWithWeightChangePerDay:(float)weightChangePerDay {
	NSTimeInterval seconds;
	
	@synchronized (self) {
		float totalWeightChange = (self.endWeight - self.startWeight);
		seconds = totalWeightChange / weightChangePerDay * SecondsPerDay;
	}
	return [self.startDate addTimeInterval:seconds];
}


- (NSDate *)endDate {
	NSDate *d;

	@synchronized (self) {
		d = [self endDateWithWeightChangePerDay:self.weightChangePerDay];
	}
	return d;
}


- (void)setEndDate:(NSDate *)date {
	@synchronized (self) {
		float weightChange = self.endWeight - self.startWeight;
		NSTimeInterval timeChange = [date timeIntervalSinceDate:self.startDate];
		self.weightChangePerDay = (weightChange / (timeChange / SecondsPerDay));
	}
}


@end
