#import "MJAutoLaunch.h"
#import "MJDocsManager.h"

extern Boolean AXIsProcessTrustedWithOptions(CFDictionaryRef options) __attribute__((weak_import));
extern CFStringRef kAXTrustedCheckOptionPrompt __attribute__((weak_import));

@interface MJGeneralTabController : NSObject

@property (weak) IBOutlet NSButton* openAtLoginCheckbox;
@property (weak) IBOutlet NSButton* showDockIconCheckbox;
@property (weak) IBOutlet NSButton* checkForUpdatesCheckbox;

@property BOOL isAccessibilityEnabled;

@end

#define MJCheckForUpdatesKey @"_checkforupdates"

@implementation MJGeneralTabController

- (IBAction) openDocsInDash:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[MJDocsManager docsFile]];
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"dash://mjolnir:"]];
}

- (void) accessibilityChanged:(NSNotification*)note {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self cacheIsAccessibilityEnabled];
    });
}

- (void) cacheIsAccessibilityEnabled {
    if (AXIsProcessTrustedWithOptions != NULL)
        self.isAccessibilityEnabled = AXIsProcessTrustedWithOptions(NULL);
    else
        self.isAccessibilityEnabled = AXAPIEnabled();
}

- (NSString*) maybeEnableAccessibilityString {
    if (self.isAccessibilityEnabled)
        return @"Accessibility is enabled. You're all set!";
    else
        return @"Enable Accessibility for best results.";
}

- (NSImage*) isAccessibilityEnabledImage {
    if (self.isAccessibilityEnabled)
        return [NSImage imageNamed:NSImageNameStatusAvailable];
    else
        return [NSImage imageNamed:NSImageNameStatusPartiallyAvailable];
}

+ (NSSet*) keyPathsForValuesAffectingMaybeEnableAccessibilityString {
    return [NSSet setWithArray:@[@"isAccessibilityEnabled"]];
}

+ (NSSet*) keyPathsForValuesAffectingIsAccessibilityEnabledImage {
    return [NSSet setWithArray:@[@"isAccessibilityEnabled"]];
}

- (IBAction) openAccessibility:(id)sender {
    if (AXIsProcessTrustedWithOptions != NULL) {
        AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)@{(__bridge id)kAXTrustedCheckOptionPrompt: @YES});
    }
    else {
        static NSString* script = @"tell application \"System Preferences\"\nactivate\nset current pane to pane \"com.apple.preference.universalaccess\"\nend tell";
        [[[NSAppleScript alloc] initWithSource:script] executeAndReturnError:nil];
    }
}

- (void) awakeFromNib {
    dispatch_async(dispatch_get_main_queue(), ^{
        // I think this is what was sometimes slowing launch down (spinning-rainbow for a few seconds).
        [self cacheIsAccessibilityEnabled];
    });
    
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(accessibilityChanged:) name:@"com.apple.accessibility.api" object:nil];
    
    [self.openAtLoginCheckbox setState:MJAutoLaunchGet() ? NSOnState : NSOffState];
    [self.showDockIconCheckbox setState:[[NSApplication sharedApplication] activationPolicy] == NSApplicationActivationPolicyRegular ? NSOnState : NSOffState];
    [self.checkForUpdatesCheckbox setState:[[NSUserDefaults standardUserDefaults] boolForKey:MJCheckForUpdatesKey] ? NSOnState : NSOffState];
}

- (IBAction) toggleOpensAtLogin:(NSButton*)sender {
    MJAutoLaunchSet([sender state] == NSOnState);
}

- (IBAction) toggleShowDockIcon:(NSButton*)sender {
    NSDisableScreenUpdates();
    
    [[NSApplication sharedApplication] setActivationPolicy:[sender state] == NSOnState ? NSApplicationActivationPolicyRegular : NSApplicationActivationPolicyAccessory];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSApplication sharedApplication] unhide:self];
        [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
        
        NSEnableScreenUpdates();
    });
}

- (IBAction) toggleCheckForUpdates:(NSButton*)sender {
    [[NSUserDefaults standardUserDefaults] setBool:[sender state] == NSOnState forKey:MJCheckForUpdatesKey];
}

- (IBAction) reloadConfig:(id)sender {
    // TODO
}

@end
