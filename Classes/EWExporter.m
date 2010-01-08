//
//  EWExporter.m
//  EatWatch
//
//  Created by Benjamin Ragheb on 12/18/09.
//  Copyright 2009 Benjamin Ragheb. All rights reserved.
//

#import "EWExporter.h"
#import "EWDatabase.h"
#import "EWDBMonth.h"


@implementation EWExporter


@synthesize beginDate;
@synthesize endDate;


#pragma mark Public API


- (void)addField:(EWExporterField)field name:(NSString *)name formatter:(NSFormatter *)formatter {
	NSAssert(fieldCount < EWExporterFieldCount, @"too many fields!");
	NSAssert(fieldNames[field] == nil, @"duplicate field");
	NSAssert(fieldFormatters[field] == nil, @"duplicate formatter");
	NSAssert(name != nil, @"must have a name");
	NSAssert(field < EWExporterFieldCount, @"invalid field ID");
	
	fieldOrder[fieldCount] = field;
	fieldCount += 1;
	
	fieldNames[field] = [name copy];
	fieldFormatters[field] = [formatter retain];
}


- (NSArray *)orderedFieldNames {
	NSMutableArray *names = [NSMutableArray array];
	int i;
	for (i = 0; i < fieldCount; i++) {
		EWExporterField f = fieldOrder[i];
		[names addObject:fieldNames[f]];
	}
	return names;
}


- (void)performExport {
	EWDatabase *db = [EWDatabase sharedDatabase];

	EWMonth beginMonth, endMonth;
	EWDay beginDay, endDay;
	
	if (beginDate) {
		EWMonthDay beginMD = EWMonthDayFromDate(beginDate);
		beginMonth = EWMonthDayGetMonth(beginMD);
		beginDay = EWMonthDayGetDay(beginMD);
	} else {
		beginMonth = db.earliestMonth;
		beginDay = 1;
	}

	if (endDate) {
		EWMonthDay endMD = EWMonthDayFromDate(endDate);
		endMonth = EWMonthDayGetMonth(endMD);
		endDay = EWMonthDayGetDay(endMD);
	} else {
		endMonth = db.latestMonth;
		endDay = 31;
	}
	
	EWDBMonth *dbm = [db getDBMonth:beginMonth];
	
	while (dbm && dbm.month <= endMonth) {
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		EWDay firstDay = (dbm.month == beginMonth) ? beginDay : 1;
		EWDay lastDay = (dbm.month == endMonth) ? endDay : 31;
		EWDay day;
		
		for (day = firstDay; day <= lastDay; day++) {
			if (! [dbm hasDataOnDay:day]) continue;
			
			const EWDBDay *dd = [dbm getDBDayOnDay:day];
			
			[self beginRecord];
			
			int i;
			for (i = 0; i < fieldCount; i++) {
				EWExporterField f = fieldOrder[i];
				id value;
				
				switch (f) {
					case EWExporterFieldDate:
						value = [dbm dateOnDay:day];
						break;
					case EWExporterFieldWeight:
						value = [NSNumber numberWithFloat:dd->scaleWeight];
						break;
					case EWExporterFieldTrendWeight:
						value = [NSNumber numberWithFloat:dd->trendWeight];
						break;
					case EWExporterFieldFat:
						value = [NSNumber numberWithFloat:dd->scaleFat];
						break;
					case EWExporterFieldFlag0:
						value = [NSNumber numberWithUnsignedChar:dd->flags[0]];
						break;
					case EWExporterFieldFlag1:
						value = [NSNumber numberWithUnsignedChar:dd->flags[1]];
						break;
					case EWExporterFieldFlag2:
						value = [NSNumber numberWithUnsignedChar:dd->flags[2]];
						break;
					case EWExporterFieldFlag3:
						value = [NSNumber numberWithUnsignedChar:dd->flags[3]];
						break;
					case EWExporterFieldNote:
						value = dd->note;
						break;
					default:
						value = nil;
						break;
				}
				
				[self exportField:f value:value];
			}
			
			[self endRecord];
		}
		
		dbm = dbm.next;
		[pool release];
	}
}


#pragma mark Optional Overrides


- (void)beginRecord {
}


- (void)exportField:(EWExporterField)field value:(id)value {
	NSFormatter *formatter = fieldFormatters[field];
	NSString *string;
	if (formatter) {
		string = [formatter stringForObjectValue:value];
	} else {
		string = [value description];
	}
	[self exportField:field formattedValue:string];
}


- (void)endRecord {
}


#pragma mark Mandatory Overrides


- (NSString *)fileExtension {
	NSAssert(NO, @"must override");
	return nil;
}


- (NSString *)contentType {
	NSAssert(NO, @"must override");
	return nil;
}


- (void)exportField:(EWExporterField)field formattedValue:(NSString *)string {
	NSAssert(NO, @"must override");
}


- (NSData *)exportedData {
	NSAssert(NO, @"must override");
	return nil;
}


#pragma mark Cleanup


- (void)dealloc {
	int i;
	for (i = 0; i < EWExporterFieldCount; i++) {
		[fieldNames[i] release];
		[fieldFormatters[i] release];
	}
	[beginDate release];
	[endDate release];
	[super dealloc];
}

@end