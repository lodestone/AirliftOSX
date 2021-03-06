// Copyright 2014 display: none;. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "ALPreferenceViewController.h"
#import "ALAppDelegate.h"

@implementation ALPreferenceViewController

@synthesize versionString, configuredHost, configuredPassword;

static NSString* const ALKeychainServiceName = @"airlift";

- (id)initWithCoder:(NSCoder*)aDecoder {
	self = [super initWithCoder:aDecoder];

	if (self != nil) {
		NSString* host =
		    [[NSUserDefaults standardUserDefaults] stringForKey:ALHostKey];
		NSString* password =
		    [ALPreferenceViewController retrievePasswordForHost:host];

		// force the window to load so that our text field references are
		// loaded, allowing text to be put in them
		[[self view] window];

		if (host == nil || [host length] == 0 || password == nil
		    || [password length] == 0) {
			[[ALAppDelegate sharedAppDelegate] didClickPreferences:self];
		} else {
			[self setConfiguredHost:host];
			[self setConfiguredPassword:password];
		}

		NSDictionary* infoPlist = [[NSBundle mainBundle] infoDictionary];
		NSString* shortVersion =
		    [infoPlist valueForKeyPath:@"CFBundleShortVersionString"];
		NSString* version = [infoPlist valueForKeyPath:@"CFBundleVersion"];
		self.versionString =
		    [NSString stringWithFormat:@"Airlift %@ (%@)", shortVersion, version];
	}

	return self;
}

#pragma mark - Actions

- (IBAction)didEnterHostname:(id)sender {
	NSString* host = [sender stringValue];

	if ([host length] > 0) {
		if ([host rangeOfString:@"://"].location == NSNotFound) {
			host = [@"http://" stringByAppendingString:host];
			[self setConfiguredHost:host];
		}
	}
	// TODO: look up the corresponding password and set it if it's not empty?
	// this could get messy though as people change stuff and then lots of
	// incomplete hosts get associated with lots of incomplete passwords
	[[NSUserDefaults standardUserDefaults] setObject:host forKey:ALHostKey];
}

- (IBAction)didEnterPassword:(id)sender {
	NSString* password = [sender stringValue];

	if ([configuredHost length] > 0) {
		[ALPreferenceViewController updatePassword:password
		                                   forHost:configuredHost];
	}
	// TODO: if host is empty, prompt user to fill it out
}

#pragma mark - Keychain API

+ (void)updatePassword:(NSString*)newPassword forHost:(NSString*)host {
	UInt32 hostLength = (UInt32)host.length;
	const char* hostChars = [host cStringUsingEncoding:NSUTF8StringEncoding];
	UInt32 serviceLength = (UInt32)ALKeychainServiceName.length;
	const char* serviceChars =
	    [ALKeychainServiceName cStringUsingEncoding:NSUTF8StringEncoding];
	UInt32 passwordLength = (UInt32)newPassword.length;
	const char* passwordChars =
	    [newPassword cStringUsingEncoding:NSUTF8StringEncoding];

	SecKeychainItemRef item;

	OSStatus status = SecKeychainFindGenericPassword(
	    NULL, serviceLength, serviceChars, hostLength, hostChars, NULL, NULL,
	    &item);

	if (status == 0) {
		status = SecKeychainItemModifyContent(item, NULL, passwordLength,
		                                      passwordChars);
	} else {
		status = SecKeychainAddGenericPassword(
		    NULL, serviceLength, serviceChars, hostLength, hostChars,
		    passwordLength, passwordChars, &item);
	}

	if (status != 0) {
		NSRunAlertPanel(@"Keychain error", @"Error updating password: %@",
		                @"OK", nil, nil, [self messageForStatusCode:status]);
	}
}

+ (NSString*)retrievePasswordForHost:(NSString*)host {
	if (host.length == 0) {
		return @"";
	}

	UInt32 hostLength = (UInt32)host.length;
	const char* hostChars = [host cStringUsingEncoding:NSUTF8StringEncoding];
	UInt32 serviceLength = (UInt32)ALKeychainServiceName.length;
	const char* serviceChars =
	    [ALKeychainServiceName cStringUsingEncoding:NSUTF8StringEncoding];
	void* passwordData;
	UInt32 passwordLength;

	OSStatus status = SecKeychainFindGenericPassword(
	    NULL, serviceLength, serviceChars, hostLength, hostChars,
	    &passwordLength, &passwordData, NULL);
	NSString* password = @"";

	switch (status) {
	case 0: {
		password = [[NSString alloc] initWithBytes:passwordData
		                                    length:passwordLength
		                                  encoding:NSUTF8StringEncoding];
		break;
	}
	case errSecItemNotFound:
		break;
	default:
		NSRunAlertPanel(@"Keychain error",
		                @"Error retrieving keychain item: %@", @"OK", nil, nil,
		                [self messageForStatusCode:status]);
		break;
	}

	return password;
}

+ (NSString*)messageForStatusCode:(OSStatus)status {
	CFStringRef str = SecCopyErrorMessageString(status, NULL);
	if (str == NULL) {
		return NULL;
	}

	CFIndex length = CFStringGetLength(str);
	CFIndex maxSize
	    = CFStringGetMaximumSizeForEncoding(length, kCFStringEncodingUTF8);
	char* buffer = (char*)malloc(maxSize);

	if (CFStringGetCString(str, buffer, maxSize, kCFStringEncodingUTF8)) {
		return
		    [NSString stringWithCString:buffer encoding:NSUTF8StringEncoding];
	}

	return @"";
}

@end
