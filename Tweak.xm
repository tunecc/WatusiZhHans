#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <dispatch/dispatch.h>
#import <objc/runtime.h>

static NSString *const kWZHLanguageSettingsKey = @"wTweakLanguage";
static NSString *const kWZHChineseLanguageItem = @"简体中文";
static NSString *const kWZHChineseLanguageValue = @"zh-Hans";

static BOOL gWZHInstalledLanguageHook = NO;
static NSUInteger gWZHHookRetryCount = 0;

static id (*gOrigFRSListCellCellWithTitleSettingsKeyItemsValuesChangeBlock)(id, SEL, id, id, id, id, id);

static BOOL WZHArrayContainsAllStrings(NSArray *array, NSArray<NSString *> *requiredItems) {
	NSSet *set = [NSSet setWithArray:array];
	for (NSString *item in requiredItems) {
		if (![set containsObject:item]) {
			return NO;
		}
	}
	return YES;
}

static BOOL WZHShouldPatchLanguageMenu(NSString *settingsKey, NSArray *items, NSArray *values) {
	if (![settingsKey isKindOfClass:[NSString class]] || ![settingsKey isEqualToString:kWZHLanguageSettingsKey]) {
		return NO;
	}

	if (![items isKindOfClass:[NSArray class]] || ![values isKindOfClass:[NSArray class]]) {
		return NO;
	}

	if (items.count != 10 || values.count != 10) {
		return NO;
	}

	if ([items containsObject:kWZHChineseLanguageItem] || [values containsObject:kWZHChineseLanguageValue]) {
		return NO;
	}

	return WZHArrayContainsAllStrings(items, @[
		@"English",
		@"Deutsch",
		@"Italiano",
		@"Français",
		@"Español",
		@"Português",
		@"Türkçe"
	]) && WZHArrayContainsAllStrings(values, @[
		@"en",
		@"fr",
		@"es",
		@"de",
		@"it",
		@"pt_br",
		@"tr",
		@"he"
	]);
}

static NSArray *WZHArrayByAppendingObject(NSArray *array, id object) {
	NSMutableArray *mutableArray = [array mutableCopy];
	[mutableArray addObject:object];
	return [mutableArray copy];
}

static id WZHFRSListCellCellWithTitleSettingsKeyItemsValuesChangeBlock(id self, SEL _cmd, id title, id settingsKey, id items, id values, id changeBlock) {
	if (WZHShouldPatchLanguageMenu(settingsKey, items, values)) {
		items = WZHArrayByAppendingObject(items, kWZHChineseLanguageItem);
		values = WZHArrayByAppendingObject(values, kWZHChineseLanguageValue);
	}

	return gOrigFRSListCellCellWithTitleSettingsKeyItemsValuesChangeBlock(self, _cmd, title, settingsKey, items, values, changeBlock);
}

static void WZHAttemptInstallLanguageHook(void) {
	if (gWZHInstalledLanguageHook) {
		return;
	}

	Class listCellClass = objc_getClass("FRSListCell");
	if (!listCellClass) {
		return;
	}

	SEL selector = sel_getUid("cellWithTitle:settingsKey:items:values:changeBlock:");
	Method method = class_getClassMethod(listCellClass, selector);
	if (!method) {
		return;
	}

	gOrigFRSListCellCellWithTitleSettingsKeyItemsValuesChangeBlock = (id (*)(id, SEL, id, id, id, id, id))method_getImplementation(method);
	method_setImplementation(method, (IMP)WZHFRSListCellCellWithTitleSettingsKeyItemsValuesChangeBlock);
	gWZHInstalledLanguageHook = YES;
}

static void WZHScheduleLanguageHookRetry(void) {
	if (gWZHInstalledLanguageHook || gWZHHookRetryCount >= 40) {
		return;
	}

	gWZHHookRetryCount += 1;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		WZHAttemptInstallLanguageHook();
		WZHScheduleLanguageHookRetry();
	});
}

%ctor {
	@autoreleasepool {
		WZHAttemptInstallLanguageHook();
		WZHScheduleLanguageHookRetry();

		[[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
														  object:nil
														   queue:[NSOperationQueue mainQueue]
													  usingBlock:^(__unused NSNotification *note) {
			WZHAttemptInstallLanguageHook();
			WZHScheduleLanguageHookRetry();
		}];
	}
}
