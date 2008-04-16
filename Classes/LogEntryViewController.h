//
//  LogEntryViewController.h
//  EatWatch
//
//  Created by Benjamin Ragheb on 3/30/08.
//  Copyright 2008 Benjamin Ragheb. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "EWDate.h"

@class MonthData;

@interface LogEntryViewController : UIViewController <UIPickerViewDelegate, UITextFieldDelegate> {
	MonthData *monthData;
	EWDay day;
	UIPickerView *weightPickerView;
	UISwitch *flagSwitch;
	UITextField *noteField;
	NSDateFormatter *titleFormatter;
	float scaleIncrement;
}
@property (nonatomic,retain) MonthData *monthData;
@property (nonatomic) EWDay day;
@property (nonatomic,retain) UIPickerView *weightPickerView;
@property (nonatomic,retain) UISwitch *flagSwitch;
@property (nonatomic,retain) UITextField *noteField;
@end
