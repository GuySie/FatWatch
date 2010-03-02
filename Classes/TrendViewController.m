//
//  TrendViewController.m
//  EatWatch
//
//  Created by Benjamin Ragheb on 3/29/08.
//  Copyright 2008 Benjamin Ragheb. All rights reserved.
//

#import "TrendViewController.h"
#import "EWDatabase.h"
#import "EWTrendButton.h"
#import "EWGoal.h"
#import "TrendSpan.h"
#import "EWWeightChangeFormatter.h"
#import "EWWeightFormatter.h"
#import "BRColorPalette.h"
#import "GraphView.h"
#import "GraphDrawingOperation.h"
#import "EnergyViewController.h"
#import "EWDBMonth.h"


static const NSTimeInterval kSecondsPerDay = 60 * 60 * 24;
static NSString * const kTrendSpanLengthKey = @"TrendSpanLength";


@interface TrendViewController ()
- (void)updateControls;
@end


@implementation TrendViewController


@synthesize graphView;
@synthesize changeGroupView;
@synthesize weightChangeButton;
@synthesize energyChangeButton;
@synthesize goalGroupView;
@synthesize relativeEnergyButton;
@synthesize relativeWeightButton;
@synthesize dateButton;
@synthesize planButton;
@synthesize flagGroupView;
@synthesize flag0Label;
@synthesize flag1Label;
@synthesize flag2Label;
@synthesize flag3Label;
@synthesize messageGroupView;


- (id)init {
	if (self = [super initWithNibName:@"TrendView" bundle:nil]) {
		self.title = NSLocalizedString(@"Trends", @"Trends view title");
		self.tabBarItem.image = [UIImage imageNamed:@"TabIconTrend.png"];
		
		UIImage *previousImage = [UIImage imageNamed:@"TriangleLeft.png"];
		UIBarButtonItem *previousItem = [[UIBarButtonItem alloc] initWithImage:previousImage style:UIBarButtonItemStyleBordered target:self action:@selector(previousSpan:)];
		self.navigationItem.leftBarButtonItem = previousItem;
		[previousItem release];

		UIImage *nextImage = [UIImage imageNamed:@"TriangleRight.png"];
		UIBarButtonItem *nextItem = [[UIBarButtonItem alloc] initWithImage:nextImage style:UIBarButtonItemStyleBordered target:self action:@selector(nextSpan:)];
		self.navigationItem.rightBarButtonItem = nextItem;
		[nextItem release];
	}
	return self;
}


- (void)databaseDidChange:(NSNotification *)notice {
	[spanArray release];
	spanArray = nil;
}


- (void)viewDidLoad {
	goalGroupView.backgroundColor = self.view.backgroundColor;
	
	graphView.backgroundColor = [UIColor whiteColor];
	graphView.drawBorder = YES;
	graphView.viewController = self;
	
	weightChangeButton.enabled = NO;
	relativeWeightButton.enabled = NO;
	planButton.enabled = NO;
	
	energyChangeButton.showsDisclosureIndicator = YES;
	relativeEnergyButton.showsDisclosureIndicator = YES;
	
	UIFont *boldFont = [UIFont boldSystemFontOfSize:17];
	[weightChangeButton setFont:boldFont forPart:1];
	[energyChangeButton setFont:boldFont forPart:1];
	[relativeWeightButton setFont:boldFont forPart:0];
	[dateButton setFont:boldFont forPart:1];
	[planButton setFont:boldFont forPart:0];
	[relativeEnergyButton setFont:boldFont forPart:0];
	[relativeEnergyButton setFont:boldFont forPart:1];

	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center addObserver:self 
			   selector:@selector(databaseDidChange:) 
				   name:EWDatabaseDidChangeNotification 
				 object:nil];
	[center addObserver:self
			   selector:@selector(databaseDidChange:)
				   name:EWBMIStatusDidChangeNotification
				 object:nil];
	[center addObserver:self
			   selector:@selector(databaseDidChange:)
				   name:EWGoalDidChangeNotification 
				 object:nil];
	
	[self.view addSubview:messageGroupView];
	messageGroupView.hidden = YES;
	CGRect frame = messageGroupView.frame;
	frame.origin.x = 0;
	frame.origin.y = CGRectGetMinY(changeGroupView.frame);
	messageGroupView.frame = frame;
}


- (void)viewWillAppear:(BOOL)animated {
	if (spanArray == nil) {
		spanArray = [[TrendSpan computeTrendSpans] copy];
		int length = [[NSUserDefaults standardUserDefaults] integerForKey:kTrendSpanLengthKey];
		if (length > 0) {
			for (int i = 0; i < [spanArray count]; i++) {
				// Allow length to be off by a few days
				if (ABS([[spanArray objectAtIndex:i] length] - length) < 7) {
					spanIndex = i;
				}
			}
		}
	}
	[self updateControls];
}


- (void)viewDidUnload {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void)updateRelativeWeightButton {
	EWGoal *goal = [EWGoal sharedGoal];
	
	if ([goal isAttained]) {
		[relativeWeightButton setText:@"goal attained" forPart:0];
		[relativeWeightButton setText:@"" forPart:1];
		[relativeWeightButton setTextColor:[BRColorPalette colorNamed:@"GoodText"] 
								   forPart:0];
	} else {
		float weightToGo = goal.endWeight - goal.currentWeight;
		EWWeightFormatter *wf = [EWWeightFormatter weightFormatterWithStyle:
								 EWWeightFormatterStyleDisplay];
		[relativeWeightButton setText:[wf stringForFloat:fabsf(weightToGo)] 
							  forPart:0];
		[relativeWeightButton setText:((weightToGo > 0) ?
									   @" to gain" :
									   @" to lose")
							  forPart:1];
		[relativeWeightButton setTextColor:[UIColor blackColor] forPart:0];
	}
}


- (NSString *)stringFromDayCount:(int)dayCount {
	if (dayCount > 365) {
		int yearCount = roundf((float)dayCount / 365.25f);
		if (yearCount == 1) {
			return @"about a year";
		} else {
			return [NSString stringWithFormat:@"about %d years", yearCount];
		}
	} else if (dayCount == 1) {
		return @"1 day";
	} else {
		return [NSString stringWithFormat:@"%d days", dayCount];
	}
}


- (void)updateDateButtonWithDate:(NSDate *)date {
	if (date) {
		int dayCount = floor([date timeIntervalSinceNow] / kSecondsPerDay);
		if (dayCount > 365) {
			[dateButton setText:@"goal in " forPart:0];
			[dateButton setText:[self stringFromDayCount:dayCount] forPart:1];
			dateButton.enabled = NO;
		} else if (showAbsoluteDate) {
			NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
			[formatter setDateStyle:NSDateFormatterLongStyle];
			[formatter setTimeStyle:NSDateFormatterNoStyle];
			[dateButton setText:@"goal on " forPart:0];
			[dateButton setText:[formatter stringFromDate:date] forPart:1];
			[formatter release];
			dateButton.enabled = YES;
		} else {
			[dateButton setText:@"goal " forPart:0];
			if (dayCount == 0) {
				[dateButton setText:@"today" forPart:1];
			} else if (dayCount == 1) {
				[dateButton setText:@"tomorrow" forPart:1];
			} else {
				[dateButton setText:[NSString stringWithFormat:@"in %d days", dayCount] forPart:1];
			}
			dateButton.enabled = YES;
		}
		[dateButton setTextColor:[UIColor blackColor] forPart:1];
	} else {
		[dateButton setText:@"" forPart:0];
		[dateButton setText:@"moving away from goal" forPart:1];
		[dateButton setTextColor:[BRColorPalette colorNamed:@"BadText"] forPart:1];
		dateButton.enabled = NO;
	}
}


- (void)updatePlanButtonWithDate:(NSDate *)date {
	planButton.hidden = (date == nil);
	if (date == nil) return;
	NSTimeInterval t = [date timeIntervalSinceDate:[[EWGoal sharedGoal] endDate]];
	int dayCount = floor(t / kSecondsPerDay);
	if (dayCount > 0) {
		[planButton setText:[self stringFromDayCount:dayCount] forPart:0];
		[planButton setText:@" later than plan" forPart:1];
		[planButton setTextColor:[BRColorPalette colorNamed:@"WarningText"] forPart:0];
	} else if (dayCount < 0) {
		[planButton setText:[self stringFromDayCount:-dayCount] forPart:0];
		[planButton setText:@" earlier than plan" forPart:1];
		[planButton setTextColor:[BRColorPalette colorNamed:@"GoodText"] forPart:0];
	} else {
		[planButton setText:@"on schedule" forPart:0];
		[planButton setText:@" according to plan" forPart:1];
		[planButton setTextColor:[BRColorPalette colorNamed:@"GoodText"] forPart:0];
	}
}


- (void)updateRelativeEnergyButtonWithRate:(float)rate {
	float plan = [[EWGoal sharedGoal] weightChangePerDay];
/*
 plan		rate	R-P
 ***		***		 ~0		following plan						G
 -10		-20		-10		burning 10 cal/day more than plan	G
 -30		-20		+10		burn 10 cal/day more to make goal	W
 -30		+20		+50		burn 50 cal/day more to meet goal	B \
 -10		+20		+30		burn 30 cal/day more to meet goal	B /
 +10		-20		-30		eat 30 cal/day more to make goal	B \
 +30		-20		-50		eat 50 cal/day more to make goal	B /
 +30		+20		-10		eat 10 cal/day more to make goal	W
 +10		+20		+10		eating 10 cal/day more than plan	G
 */
	
	float gap = rate - plan;

#if TARGET_IPHONE_SIMULATOR
	NSLog(@"PLAN=%f RATE=%f GAP=%f", plan, rate, gap);
#endif
	
	if (fabsf(gap) < 0.001) { // remember, this is lbs/day
		// I love it when a plan comes together.
		[relativeEnergyButton setText:@"" forPart:0];
		[relativeEnergyButton setText:@"following plan" forPart:1];
		[relativeEnergyButton setText:@"" forPart:2];
		[relativeEnergyButton setTextColor:[BRColorPalette colorNamed:@"GoodText"] forPart:1];
		relativeEnergyButton.showsDisclosureIndicator = NO;
		relativeEnergyButton.enabled = NO;
		return;
	}
	
	UIColor *energyColor;
	
	NSString *kTextBurning = NSLocalizedString(@"burning ", nil);
	NSString *kTextEating = NSLocalizedString(@"eating ", nil);
	NSString *kTextPlanDescriptive = NSLocalizedString(@" beyond plan", nil);
	NSString *kTextCut = NSLocalizedString(@"cut ", nil);
	NSString *kTextAdd = NSLocalizedString(@"add ", nil);
	NSString *kTextPlanImperative = NSLocalizedString(@" to match plan", nil);
	
	if (plan < 0) {
		if (rate < 0) {
			if (gap < 0) {
				[relativeEnergyButton setText:kTextBurning forPart:0];
				energyColor = [BRColorPalette colorNamed:@"GoodText"];
				[relativeEnergyButton setText:kTextPlanDescriptive forPart:2];
			} else {
				[relativeEnergyButton setText:kTextCut forPart:0];
				energyColor = [BRColorPalette colorNamed:@"WarningText"];
				[relativeEnergyButton setText:kTextPlanImperative forPart:2];
			}
		} else {
			[relativeEnergyButton setText:kTextCut forPart:0];
			energyColor = [BRColorPalette colorNamed:@"BadText"];
			[relativeEnergyButton setText:kTextPlanImperative forPart:2];
		}
	} else {
		if (rate < 0) {
			[relativeEnergyButton setText:kTextAdd forPart:0];
			energyColor = [BRColorPalette colorNamed:@"BadText"];
			[relativeEnergyButton setText:kTextPlanImperative forPart:2];
		} else {
			if (gap < 0) {
				[relativeEnergyButton setText:kTextAdd forPart:0];
				energyColor = [BRColorPalette colorNamed:@"WarningText"];
				[relativeEnergyButton setText:kTextPlanImperative forPart:2];
			} else {
				[relativeEnergyButton setText:kTextEating forPart:0];
				energyColor = [BRColorPalette colorNamed:@"GoodText"];
				[relativeEnergyButton setText:kTextPlanDescriptive forPart:2];
			}
		}
	}
	
	NSNumberFormatter *wf = [[EWWeightChangeFormatter alloc] initWithStyle:
							 EWWeightChangeFormatterStyleEnergyPerDay];
	[wf setPositivePrefix:@""];
	[relativeEnergyButton setText:[wf stringForFloat:fabsf(gap)] forPart:1];
	[relativeEnergyButton setTextColor:energyColor forPart:1];
	[wf release];
	relativeEnergyButton.showsDisclosureIndicator = YES;
	relativeEnergyButton.enabled = YES;
}


- (void)updateGraph {
	TrendSpan *span = [spanArray objectAtIndex:spanIndex];
	
	GraphViewParameters *gp = span.graphParameters;
	
	if (!gp->shouldDrawNoDataWarning) {
		gp->shouldDrawNoDataWarning = YES;
		[GraphDrawingOperation prepareGraphViewInfo:gp 
											forSize:graphView.bounds.size
									   numberOfDays:span.length];
	}
	
	graphView.beginMonthDay = EWMonthDayNext(span.beginMonthDay);
	graphView.endMonthDay = span.endMonthDay;
	graphView.p = gp;
	graphView.image = span.graphImageRef;
	[graphView setNeedsDisplay];
	
	if (span.graphImageRef == nil && span.graphOperation == nil) {
		GraphDrawingOperation *op = [[GraphDrawingOperation alloc] init];
		op.delegate = self;
		op.index = spanIndex;
		op.p = graphView.p;
		op.bounds = graphView.bounds;
		op.beginMonthDay = graphView.beginMonthDay;
		op.endMonthDay = graphView.endMonthDay;
		op.showGoalLine = YES;
		op.showTrajectoryLine = YES;
		span.graphOperation = op;
		[op enqueue];
		[op release];
	}
}


- (void)drawingOperationComplete:(GraphDrawingOperation *)operation {
	TrendSpan *span = [spanArray objectAtIndex:operation.index];
	
	if (span.graphOperation == operation && ![operation isCancelled]) {
		span.graphImageRef = operation.imageRef;
		if (operation.index == spanIndex) {
			[graphView setImage:span.graphImageRef];
			[graphView setNeedsDisplay];
		}
		span.graphOperation = nil;
	}
}


- (void)updateControlsWithSpan:(TrendSpan *)span {
	[[NSUserDefaults standardUserDefaults] setInteger:span.length forKey:kTrendSpanLengthKey];
	
	UINavigationItem *navItem = self.navigationItem;
	navItem.title = span.title;
	navItem.leftBarButtonItem.enabled = (spanIndex > 0);
	navItem.rightBarButtonItem.enabled = (spanIndex + 1 < [spanArray count]);

	[self updateGraph];
	
	changeGroupView.hidden = NO;

	if (span.weightPerDay > 0) {
		[weightChangeButton setText:@"gaining " forPart:0];
		[energyChangeButton setText:@"eating " forPart:0];
		[energyChangeButton setText:@" more than you burn" forPart:2];
	} else {
		[weightChangeButton setText:@"losing " forPart:0];
		[energyChangeButton setText:@"burning " forPart:0];
		[energyChangeButton setText:@" more than you eat" forPart:2];
	}

	NSNumber *change = [NSNumber numberWithFloat:fabsf(span.weightPerDay)];

	NSNumberFormatter *wf = [[EWWeightChangeFormatter alloc] initWithStyle:EWWeightChangeFormatterStyleWeightPerWeek];
	[wf setPositivePrefix:@""];
	[weightChangeButton setText:[wf stringForObjectValue:change] forPart:1];
	[wf release];
	
	NSNumberFormatter *ef = [[EWWeightChangeFormatter alloc] initWithStyle:EWWeightChangeFormatterStyleEnergyPerDay];
	[ef setPositivePrefix:@""];
	[energyChangeButton setText:[ef stringForObjectValue:change] forPart:1];
	[ef release];
	
	EWGoal *goal = [EWGoal sharedGoal];
	if (goal.defined) {
		goalGroupView.hidden = NO;
		[self updateRelativeWeightButton];
		if (goal.attained) {
			dateButton.hidden = YES;
			planButton.hidden = YES;
			relativeEnergyButton.hidden = YES;
		} else {
			dateButton.hidden = NO;
			planButton.hidden = NO;
			relativeEnergyButton.hidden = NO;
			[self updateDateButtonWithDate:span.endDate];
			[self updatePlanButtonWithDate:span.endDate];
			[self updateRelativeEnergyButtonWithRate:span.weightPerDay];
		}
	} else {
		goalGroupView.hidden = YES;
	}
	
	flagGroupView.hidden = NO;
	NSNumberFormatter *pf = [[NSNumberFormatter alloc] init];
	[pf setNumberStyle:NSNumberFormatterPercentStyle];
	flag0Label.text = [pf stringForFloat:span.flagFrequencies[0]];
	flag1Label.text = [pf stringForFloat:span.flagFrequencies[1]];
	flag2Label.text = [pf stringForFloat:span.flagFrequencies[2]];
	flag3Label.text = [pf stringForFloat:span.flagFrequencies[3]];
	[pf release];
}


- (void)updateControls {
	if (spanIndex < [spanArray count]) {
		[self updateControlsWithSpan:[spanArray objectAtIndex:spanIndex]];
		messageGroupView.hidden = YES;
	} else {
		UINavigationItem *navItem = self.navigationItem;
		navItem.title = @"Not Enough Data";
		navItem.leftBarButtonItem.enabled = NO;
		navItem.rightBarButtonItem.enabled = NO;
		changeGroupView.hidden = YES;
		goalGroupView.hidden = YES;
		flagGroupView.hidden = YES;
		messageGroupView.hidden = NO;
	}
}


#pragma mark Actions


- (void)previousSpan:(id)sender {
	if (spanIndex > 0) {
		spanIndex -= 1;
		[self updateControls];
	}
}


- (void)nextSpan:(id)sender {
	if (spanIndex + 1 < [spanArray count]) {
		spanIndex += 1;
		[self updateControls];
	}
}


- (IBAction)showEnergyEquivalents:(id)sender {
	TrendSpan *span = [spanArray objectAtIndex:spanIndex];
	float rate = span.weightPerDay;
	
	if (sender == relativeEnergyButton) {
		float plan = [[EWGoal sharedGoal] weightChangePerDay];
		rate = fabsf(rate - plan);
	} else {
		rate = fabsf(rate);
	}

	float weight = [[EWDatabase sharedDatabase] latestWeight];
	EnergyViewController *ctrlr = [[EnergyViewController alloc] initWithWeight:weight
															   andChangePerDay:rate];
	[self.navigationController pushViewController:ctrlr animated:YES];
	[ctrlr release];
}


- (IBAction)toggleDateFormat:(id)sender {
	showAbsoluteDate = !showAbsoluteDate;
	[self updateControls];
}


#pragma mark Cleanup


- (void)dealloc {
	[weightChangeButton release];
	[energyChangeButton release];
	[goalGroupView release];
	[relativeEnergyButton release];
	[relativeWeightButton release];
	[dateButton release];
	[planButton release];
	[flag0Label release];
	[flag1Label release];
	[flag2Label release];
	[flag3Label release];
	[super dealloc];
}


@end
