/*
 * LogViewController.m
 * Created by Benjamin Ragheb on 3/29/08.
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

#import "EWDBMonth.h"
#import "EWDatabase.h"
#import "EWDate.h"
#import "LogDatePickerController.h"
#import "LogEntryViewController.h"
#import "LogInfoPickerController.h"
#import "LogTableViewCell.h"
#import "LogViewController.h"


static NSString * const kBadgeValueNoDataToday = @"!";
static NSString	* const kCellFlashAnimationID = @"LogCellFlash";
static NSString * const kHideBadgeKey = @"LogViewControllerHideBadge";


@interface LogViewController ()
- (void)databaseDidChange:(NSNotification *)notice;
@end


@implementation LogViewController
{
	EWDatabase *database;
	NSDateFormatter *sectionTitleFormatter;
	EWMonth earliestMonth, latestMonth;
	NSIndexPath *lastIndexPath;
	EWMonthDay scrollDestination;
	LogInfoPickerController *infoPickerController;
	LogDatePickerController *datePickerController;
}

@synthesize database;
@synthesize infoPickerController;
@synthesize datePickerController;


- (void)awakeFromNib {
	[super awakeFromNib];
	sectionTitleFormatter = [[NSDateFormatter alloc] init];
	sectionTitleFormatter.formatterBehavior = NSDateFormatterBehavior10_4;
	sectionTitleFormatter.dateFormat = NSLocalizedString(@"MMMM y", @"Month Year date format");
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(databaseDidChange:) 
												 name:EWDatabaseDidChangeNotification 
											   object:nil];
	[self databaseDidChange:nil];
}


- (void)setButton:(UIButton *)button backgroundImageNamed:(NSString *)name forState:(UIControlState)state {
	UIImage *base = [UIImage imageNamed:name];
	UIImage *image = [base stretchableImageWithLeftCapWidth:5 topCapHeight:6];
	[button setBackgroundImage:image forState:state];
}


- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void)databaseDidChange:(NSNotification *)notice {
	EWMonthDay today = EWMonthDayToday();

	if ([database hasDataForToday]) {
		self.tabBarItem.badgeValue = nil;
	} else {
		BOOL showBadge = ![[NSUserDefaults standardUserDefaults] boolForKey:kHideBadgeKey];
		if (showBadge) self.tabBarItem.badgeValue = kBadgeValueNoDataToday;
	}
	
	if ((database.earliestMonth != earliestMonth) || (latestMonth == 0)) {
		earliestMonth = database.earliestMonth;
		latestMonth = MAX(database.latestMonth, EWMonthDayGetMonth(today));

		NSUInteger row, section;
		section = latestMonth - earliestMonth;
		if (latestMonth == EWMonthDayGetMonth(today)) {
			row = EWMonthDayGetDay(today) - 1;
		} else {
			row = EWDaysInMonth(latestMonth) - 1;
		}
		lastIndexPath = [NSIndexPath indexPathForRow:row inSection:section];
		
		[self.tableView reloadData];
	}
}


- (EWMonth)monthForSection:(NSInteger)section {
	return earliestMonth + (EWMonth)section;
}


- (NSIndexPath *)indexPathForMonthDay:(EWMonthDay)monthday {
	EWMonth month = EWMonthDayGetMonth(monthday);
	EWDay day = EWMonthDayGetDay(monthday);
	NSUInteger section = MIN((month - earliestMonth), [self numberOfSectionsInTableView:self.tableView] - 1);
	NSUInteger row = MIN(day, [self tableView:self.tableView numberOfRowsInSection:section]) - 1;
	return [NSIndexPath indexPathForRow:row inSection:section];
}


- (EWMonthDay)monthDayForIndexPath:(NSIndexPath *)indexPath {
	return EWMonthDayMake([self monthForSection:indexPath.section],
						  (EWDay)(indexPath.row + 1));
}


- (NSIndexPath *)indexPathForMiddle {
	NSArray *indexPathArray = [self.tableView indexPathsForVisibleRows];
	if ([indexPathArray count] > 0) {
		NSUInteger middleIndex = [indexPathArray count] / 2;
		return indexPathArray[middleIndex];
	} else {
		return nil;
	}
}


- (NSDate *)currentDate {
	NSIndexPath	*indexPath = [self indexPathForMiddle];
	return EWDateFromMonthAndDay([self monthForSection:indexPath.section], 
								 (EWDay)(indexPath.row + 1));
}


- (void)deselectSelectedRow {
	NSIndexPath *tableSelection = [self.tableView indexPathForSelectedRow];
	if (tableSelection) {
		[self.tableView deselectRowAtIndexPath:tableSelection animated:YES];
	}
}


// Called by the date picker popup
- (void)scrollToDate:(NSDate *)date {
	EWMonthDay md = EWMonthDayFromDate(date);
	if (earliestMonth > EWMonthDayGetMonth(md)) {
		[database getDBMonth:EWMonthDayGetMonth(md)];
		[self databaseDidChange:nil];
	}
	
	/* We want to flash the row that the user picked. In most cases, we will
	 call selectRowAtIndexPath: to take care of the scrolling and the
	 highlighting, and undo the change in scrollViewDidEndScrollingAnimation:.
	 However, if the table does not scroll (because the user picked a date in 
	 the middle of the view), the delegate method will not be called, and the
	 cell will remain highlighted. To avoid this problem, we animate the 
	 highlight ourselves in this situation.
	 */

	NSIndexPath *middlePath = [self indexPathForMiddle];
	NSIndexPath *targetPath = [self indexPathForMonthDay:md];
	
	if ([targetPath isEqual:middlePath]) {
		UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:targetPath];
        [UIView animateWithDuration:0.2 animations:^(void) {
            [cell setHighlighted:YES];
        } completion:^(BOOL finished) {
            [cell setHighlighted:NO animated:YES];
        }];
	} else {
		[self.tableView selectRowAtIndexPath:targetPath
                                    animated:YES
                              scrollPosition:UITableViewScrollPositionMiddle];
	}
}
													  

#pragma mark UIScrollViewDelegate


- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
	// Deselect in response to a scrollToDate: selection.
	[self deselectSelectedRow];
}


#pragma mark UIViewController


- (void)viewDidLoad {
	[super viewDidLoad];
    
    [[UINib nibWithNibName:@"LogViewController" bundle:nil] instantiateWithOwner:self options:nil];

    self.tableView.rowHeight = 51;
    self.tableView.tableHeaderView = self.tableHeaderView;
    self.tableView.tableFooterView = self.tableFooterView;
    self.navigationItem.rightBarButtonItem = self.goToBarButtonItem;

    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1) {
        UIButton *button = self.auxDisplayButton6;
        self.navigationItem.titleView = button;
        self.infoPickerController.infoTypeButton = button;
        [self setButton:button backgroundImageNamed:@"NavButton0"
               forState:UIControlStateNormal];
        [self setButton:button backgroundImageNamed:@"NavButton1"
               forState:UIControlStateHighlighted];
    } else {
        self.navigationItem.titleView = self.auxDisplayButton7;
        self.infoPickerController.infoTypeButton = self.auxDisplayButton7;
    }
    self.auxDisplayButton6 = nil;
    self.auxDisplayButton7 = nil;

	self.view.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
								  UIViewAutoresizingFlexibleHeight);

	[infoPickerController setSuperview:self.tabBarController.view];
	[datePickerController setSuperview:self.tabBarController.view];

	scrollDestination = EWMonthDayToday();
}


- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	if (scrollDestination != 0) {
		// If we do this in viewWillAppear:, we are sometimes off by 20px,
		// because the view is resized between 'WillAppear and 'DidAppear:.
		[self.tableView reloadData];
		NSIndexPath *path = [self indexPathForMonthDay:scrollDestination];
		[self.tableView scrollToRowAtIndexPath:path
                              atScrollPosition:UITableViewScrollPositionBottom
                                      animated:NO];
		scrollDestination = 0;
	}
	[self deselectSelectedRow];
}


#pragma mark Tab Bar Double Tap


- (void)tabBarItemDoubleTapped {
	[self.tableView scrollToRowAtIndexPath:lastIndexPath
                          atScrollPosition:UITableViewScrollPositionBottom
                                  animated:YES];
}


#pragma mark UITableViewDataSource (Required)


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return (latestMonth - earliestMonth + 1);
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == [lastIndexPath section]) {
		return [lastIndexPath row] + 1;
	} else {
		EWMonth month = [self monthForSection:section];
		return EWDaysInMonth(month);
	}
}


#pragma mark UITableViewDataSource (Optional)


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	EWMonth month = [self monthForSection:section];
	NSDate *theDate = EWDateFromMonthAndDay(month, 1);
	return [sectionTitleFormatter stringFromDate:theDate];
}


#pragma mark UITableViewDelegate (Required)


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	LogTableViewCell *cell = nil;
	
	id availableCell = [tableView dequeueReusableCellWithIdentifier:kLogCellReuseIdentifier];
	if (availableCell != nil) {
		cell = (LogTableViewCell *)availableCell;
	} else {
		cell = [[LogTableViewCell alloc] init];
		cell.tableView = tableView;
	}
	
	EWDBMonth *monthData = [database getDBMonth:[self monthForSection:indexPath.section]];
	EWDay day = (EWDay)(1 + indexPath.row);
	[cell updateWithMonthData:monthData day:day];
	
	return cell;
}


#pragma mark UITableViewDelegate (Optional)


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	EWMonth month = [self monthForSection:indexPath.section];
	EWDBMonth *monthData = [database getDBMonth:month];
	EWDay day = (EWDay)(1 + indexPath.row);
	LogEntryViewController *controller = [LogEntryViewController sharedController];
	[controller configureForDay:day dbMonth:monthData];
	[self presentViewController:controller animated:YES completion:nil];
}


@end
