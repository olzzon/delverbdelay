#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;

        // Create a simple window
        NSRect frame = NSMakeRect(100, 100, 400, 300);
        NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                       styleMask:(NSWindowStyleMaskTitled |
                                                                  NSWindowStyleMaskClosable |
                                                                  NSWindowStyleMaskMiniaturizable)
                                                         backing:NSBackingStoreBuffered
                                                           defer:NO];
        [window setTitle:@"DeliVerb"];

        // Add a label
        NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 130, 360, 40)];
        label.stringValue = @"DeliVerb Audio Unit Host\n\nThe AU extension is registered with the system.";
        label.editable = NO;
        label.bordered = NO;
        label.backgroundColor = [NSColor clearColor];
        label.alignment = NSTextAlignmentCenter;
        [window.contentView addSubview:label];

        [window makeKeyAndOrderFront:nil];
        [app activateIgnoringOtherApps:YES];

        [app run];
    }
    return 0;
}
