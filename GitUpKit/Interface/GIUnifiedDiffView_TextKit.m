//
//  GIUnifiedDiffView_TextKit.m
//  GitUpKit
//
//  Created by Zachary Waldowski on 7/6/19.
//

#import "GIUnifiedDiffView_TextKit.h"
#import "GIAppKit.h"

@class GIUnifiedDiffLayoutManager;

@protocol GIUnifiedDiffLayoutManagerDelegate <NSLayoutManagerDelegate>
@optional
- (void)layoutManager:(GIUnifiedDiffLayoutManager *)layoutManager textContainer:(NSTextContainer *)textContainer didChangeGeometryFromSize:(NSSize)oldSize;
@end

@interface GIUnifiedDiffLayoutManager: NSLayoutManager
@property (weak) id<GIUnifiedDiffLayoutManagerDelegate> delegate;
@end

@implementation GIUnifiedDiffLayoutManager {
  NSSize _compatibilityLastContainerSize;
}

@dynamic delegate;

- (void)textContainerChangedGeometry:(NSTextContainer *)container {
  [super textContainerChangedGeometry:container];

  if (@available(macOS 10.11, *)) {
  } else {
    if ([self.delegate respondsToSelector:@selector(layoutManager:textContainer:didChangeGeometryFromSize:)]) {
      [self.delegate layoutManager:self textContainer:container didChangeGeometryFromSize:_compatibilityLastContainerSize];
    }
    _compatibilityLastContainerSize = container.containerSize;
  }
}

@end

@interface GIUnifiedDiffView_TextKit () <NSTextViewDelegate, GIUnifiedDiffLayoutManagerDelegate>
@property (nonatomic, unsafe_unretained) GITextView* textView;
@end

@implementation GIUnifiedDiffView_TextKit

- (void)didFinishInitializing {
  [super didFinishInitializing];

  GIUnifiedDiffLayoutManager* layoutManager = [[GIUnifiedDiffLayoutManager alloc] init];
  layoutManager.allowsNonContiguousLayout = YES;
  layoutManager.delegate = self;

  GITextView *textView = [[GITextView alloc] initWithFrame:self.bounds];
//  textView.textContainer.widthTracksTextView = NO;
  [textView.textContainer replaceLayoutManager:layoutManager];
//  textView.verticallyResizable = NO;
//  textView.autoresizingMask = NSViewWidthSizable;
  textView.editable = NO;
  textView.delegate = self;
  textView.font = [NSFont userFixedPitchFontOfSize:10];
  textView.backgroundColor = self.backgroundColor;
  textView.string = @"Lorem ipsum dolor sit amet, consectetur adipiscing elit. Pellentesque posuere ex non purus fringilla, vel posuere lorem maximus. In eu neque nec velit elementum luctus nec cursus sem. Ut vitae purus sed lectus varius ullamcorper. Cras lorem nibh, porta commodo aliquam in, commodo in sapien. Etiam commodo at est ac sodales. Vestibulum at metus vel dui laoreet malesuada id eu massa. Etiam lectus neque, convallis eget efficitur in, lacinia hendrerit odio.\n\nSuspendisse iaculis dapibus sollicitudin. Ut pretium molestie risus, imperdiet porttitor erat malesuada eu. Nulla quis facilisis enim. Duis gravida vehicula mi, nec dapibus quam. In id purus consequat, dignissim justo in, venenatis massa. Aenean vitae nulla eleifend, lobortis nulla in, dictum libero. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Mauris ultricies tortor non mi porttitor, sit amet posuere mauris pharetra. Mauris a luctus felis, vitae aliquet elit. Quisque et erat viverra, tincidunt dui ut, interdum velit. Vivamus tincidunt metus nisl, in dictum velit euismod eget.\n\nAliquam erat volutpat. In hac habitasse platea dictumst. Nunc auctor maximus lorem id dictum. Aenean in cursus nunc, quis luctus arcu. In id euismod sem. Pellentesque tellus erat, rhoncus at magna nec, rhoncus porttitor nulla. Sed venenatis, ligula a blandit lacinia, mauris enim maximus lacus, eget aliquet lorem augue a arcu. In lorem nulla, condimentum id congue quis, interdum vel mauris. Nulla id magna imperdiet, feugiat purus pellentesque, pulvinar elit. Nulla vitae massa vel nunc efficitur molestie.\n\nIn hac habitasse platea dictumst. Morbi sagittis accumsan lorem, in consequat ligula efficitur et. Etiam purus massa, hendrerit nec blandit a, sagittis sit amet augue. Curabitur sit amet lorem libero. Donec vitae velit iaculis, placerat leo sit amet, molestie enim. Donec elit quam, molestie non mattis sit amet, pellentesque ut turpis. Duis convallis odio leo, sit amet pretium dui suscipit ac. Duis arcu mi, congue in dolor sed, porttitor ornare enim. Curabitur dolor est, tempor in nibh egestas, tristique finibus massa. In at sapien feugiat nibh cursus feugiat. Nam imperdiet tristique nibh at sollicitudin. Sed feugiat auctor augue, eget cursus sapien vestibulum et.\n\nPellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Mauris vitae sem lacinia, hendrerit ipsum nec, feugiat arcu. Nam dictum blandit hendrerit. In sed rutrum nulla. Aenean nunc tortor, vestibulum feugiat eros id, lacinia vulputate sapien. Nulla fermentum interdum tincidunt. Nulla eget nisi et erat varius sodales consequat quis eros. Pellentesque fringilla ultricies posuere. Sed tincidunt consectetur diam, sit amet ornare ante placerat vel.";
  [self addSubview:textView];
  self.textView = textView;

  textView.postsFrameChangedNotifications = YES;
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_testFrameDidChange:) name:NSViewFrameDidChangeNotification object:textView];



//  textView.textContainerInset = CGSizeZero;
//  textView.textContainer.lineFragmentPadding = 0;
}

//- (void)layout {
//    self.textView.frame = self.bounds;
//}

- (void)_testFrameDidChange:(NSNotification *)note {
//  if (!NSEqualPoints(self.textView.frame.origin, NSZeroPoint)) {
//    NSLog(@"!");
//  }
  self.textView.frameOrigin = NSZeroPoint;
  id<GIDiffViewDelegate> delegate = self.delegate;
  if ([delegate respondsToSelector:@selector(diffView:didChangeContentHeight:)] && self.textView.frame.size.height != self.bounds.size.height) {
    [delegate diffView:self didChangeContentHeight:self.textView.frame.size.height];
  }
//  [self.delegate ]
//  NSLog(@"!, %@ %@", @(__FUNCTION__), note);
//  if (self.textView.frame.origin.y > 800) {
//    NSLog(@"!", note);
//  }
}

- (void)drawRect:(NSRect)dirtyRect {}

- (BOOL)isEmpty {
  [self doesNotRecognizeSelector:_cmd];
  return NO;
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize {
  self.textView.frame = NSMakeRect(0, 0, self.bounds.size.width, self.textView.frame.size.height);
//
//  [self.textView setFrameOrigin:NSZeroPoint];
//  self.textView.frame = self.bounds;
}

- (CGFloat)updateLayoutForWidth:(CGFloat)width {
//  self.textView.frame = NSMakeRect(0, 0, width, self.textView.frame.size.height);
//
//  NSLog(@"!, %@ %@", @(__FUNCTION__), self.textView);
  CGRect rect = [self.textView.layoutManager usedRectForTextContainer:self.textView.textContainer];
  CGFloat height = NSHeight(rect);
  if (self.textView.frame.size.height == 0) {
    NSLog(@"! zero height");
  }
  return height;

  //self.textView.frame = NSMakeRect(0, 0, width, self.textView.frame.size.height);
//  NSLog(@"!, %@ %@", @(__FUNCTION__), self.textView);
//  if (self.textView.frame.size.height == 0) {
//    NSLog(@"!");
//  }
//  return self.textView.frame.size.height;

//  int ___39-[UITextView _intrinsicSizeWithinSize:]_block_invoke.698(int arg0, int arg1, int arg2) {
//    r14 = arg0;
//    rbx = [arg1 retain];
//    r15 = [arg2 retain];
//    if ([rbx allowsNonContiguousLayout] != 0x0) {
//      [rbx ensureLayoutForTextContainer:r15];
//    }
//    [rbx glyphRangeForTextContainer:r15];
//    if (rbx != 0x0) {
//      [&var_40 usedRectForTextContainer:rbx, r15];
//    }
//    else {
//      var_30 = intrinsic_movaps(var_30, 0x0);
//      intrinsic_movaps(var_40, 0x0);
//    }
//    rax = *(r14 + 0x20);
//    rax = *(rax + 0x8);
//    *(rax + 0x28) = var_28;
//    *(rax + 0x20) = var_30;
//    [r15 release];
//    rax = [rbx release];
//    return rax;
//  }

//  [self.textView.layoutManager ensureLayoutForTextContainer:self.textView.textContainer];
//  CGFloat height = [self.textView.layoutManager usedRectForTextContainer:self.textView.textContainer].size.height;
//  NSLog(@"%@ %f", self.textView.debugDescription, height);
//  return height;

//  // If actual layout happened during the last call then the view will have been resized as a result.  However, it's conceivable that all the layout was already done and yet somehow this view got to be the wrong size.  So, we'll set the size, but we don't worry about the container origin (which NSLayoutManagers keep per container and which are used by the view to do proper coordinate transformations).  It will already have been set correctly.  Thus we do the simplistic size calculation here.
//  containerBoundsUsageRect.size = [layout usedRectForTextContainer:TVIVARS(self)->textContainer].size;
//  containerBoundsUsageRect.size.width += (TVIVARS(self)->textContainerInset.width * 2.0);
//  containerBoundsUsageRect.size.height += (TVIVARS(self)->textContainerInset.height * 2.0);
//  containerBoundsUsageRect = [self backingAlignedRect:containerBoundsUsageRect options:NSAlignAllEdgesOutward];



//  NSLayoutManager *layout = _getLayoutManager(self);
//  NSRect containerBoundsUsageRect = NSZeroRect;
//  if (layout) {
//    // Ensure the layout is done for this container
//    (void)[layout glyphRangeForTextContainer:TVIVARS(self)->textContainer];
//
//    // If actual layout happened during the last call then the view will have been resized as a result.  However, it's conceivable that all the layout was already done and yet somehow this view got to be the wrong size.  So, we'll set the size, but we don't worry about the container origin (which NSLayoutManagers keep per container and which are used by the view to do proper coordinate transformations).  It will already have been set correctly.  Thus we do the simplistic size calculation here.
//    containerBoundsUsageRect.size = [layout usedRectForTextContainer:TVIVARS(self)->textContainer].size;
//    containerBoundsUsageRect.size.width += (TVIVARS(self)->textContainerInset.width * 2.0);
//    containerBoundsUsageRect.size.height += (TVIVARS(self)->textContainerInset.height * 2.0);
//    containerBoundsUsageRect = [self backingAlignedRect:containerBoundsUsageRect options:NSAlignAllEdgesOutward];
//
//    [self setConstrainedFrameSize:[self convertSize:containerBoundsUsageRect.size toView:[self superview]]];
//  }

  //[var_30 ensureLayoutForBoundingRect:*(rax + rcx) inTextContainer:rcx];

//  self.textView.minSize = NSMakeSize(width, self.textView.minSize.height);
//  self.textView.maxSize = NSMakeSize(width, self.textView.maxSize.height);
//  self.textView.frameSize = NSMakeSize(width, self.frame.size.height);


//  [self.textView setFrameSize:NSMakeSize(width, NSHeight(self.frame))];
//  [self.textView sizeToFit];
//  [self.textView setFrameOrigin:NSZeroPoint];
//  return NSHeight(self.textView.frame);
//  NSSize size = self.textView.textContainer.containerSize;
//  size.width = width;
//  self.textView.textContainer.containerSize = size;
//
//  return 800;
  return 800;
}

- (BOOL)hasSelection {
  return NO;
}

- (BOOL)hasSelectedText {
  return NO;
}

- (BOOL)hasSelectedLines {
  return NO;
}

- (void)clearSelection {
}

- (void)getSelectedText:(NSString**)text oldLines:(NSIndexSet**)oldLines newLines:(NSIndexSet**)newLines {
}

- (void)layoutManager:(GIUnifiedDiffLayoutManager *)layoutManager textContainer:(NSTextContainer *)textContainer didChangeGeometryFromSize:(NSSize)oldSize {
  NSLog(@"! %@ old %@ new %@", @(__FUNCTION__), NSStringFromSize(oldSize), NSStringFromSize(textContainer.containerSize));
}

@end

@interface GIUnifiedDiffView_TextKit2 () <GIUnifiedDiffLayoutManagerDelegate>
@end

@implementation GIUnifiedDiffView_TextKit2

@synthesize patch = _patch;

- (void)didFinishInitializing {
//  self.textContainer.widthTracksTextView = NO;

  GIUnifiedDiffLayoutManager* layoutManager = [[GIUnifiedDiffLayoutManager alloc] init];
  layoutManager.allowsNonContiguousLayout = YES;
  layoutManager.delegate = self;
  [self.textContainer replaceLayoutManager:layoutManager];

  self.editable = NO;
  self.font = [NSFont userFixedPitchFontOfSize:10];
  self.backgroundColor = NSColor.textBackgroundColor;
  self.textColor = NSColor.textColor;
  self.string = @"Lorem ipsum dolor sit amet, consectetur adipiscing elit. Pellentesque posuere ex non purus fringilla, vel posuere lorem maximus. In eu neque nec velit elementum luctus nec cursus sem. Ut vitae purus sed lectus varius ullamcorper. Cras lorem nibh, porta commodo aliquam in, commodo in sapien. Etiam commodo at est ac sodales. Vestibulum at metus vel dui laoreet malesuada id eu massa. Etiam lectus neque, convallis eget efficitur in, lacinia hendrerit odio.\n\nSuspendisse iaculis dapibus sollicitudin. Ut pretium molestie risus, imperdiet porttitor erat malesuada eu. Nulla quis facilisis enim. Duis gravida vehicula mi, nec dapibus quam. In id purus consequat, dignissim justo in, venenatis massa. Aenean vitae nulla eleifend, lobortis nulla in, dictum libero. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Mauris ultricies tortor non mi porttitor, sit amet posuere mauris pharetra. Mauris a luctus felis, vitae aliquet elit. Quisque et erat viverra, tincidunt dui ut, interdum velit. Vivamus tincidunt metus nisl, in dictum velit euismod eget.\n\nAliquam erat volutpat. In hac habitasse platea dictumst. Nunc auctor maximus lorem id dictum. Aenean in cursus nunc, quis luctus arcu. In id euismod sem. Pellentesque tellus erat, rhoncus at magna nec, rhoncus porttitor nulla. Sed venenatis, ligula a blandit lacinia, mauris enim maximus lacus, eget aliquet lorem augue a arcu. In lorem nulla, condimentum id congue quis, interdum vel mauris. Nulla id magna imperdiet, feugiat purus pellentesque, pulvinar elit. Nulla vitae massa vel nunc efficitur molestie.\n\nIn hac habitasse platea dictumst. Morbi sagittis accumsan lorem, in consequat ligula efficitur et. Etiam purus massa, hendrerit nec blandit a, sagittis sit amet augue. Curabitur sit amet lorem libero. Donec vitae velit iaculis, placerat leo sit amet, molestie enim. Donec elit quam, molestie non mattis sit amet, pellentesque ut turpis. Duis convallis odio leo, sit amet pretium dui suscipit ac. Duis arcu mi, congue in dolor sed, porttitor ornare enim. Curabitur dolor est, tempor in nibh egestas, tristique finibus massa. In at sapien feugiat nibh cursus feugiat. Nam imperdiet tristique nibh at sollicitudin. Sed feugiat auctor augue, eget cursus sapien vestibulum et.\n\nPellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Mauris vitae sem lacinia, hendrerit ipsum nec, feugiat arcu. Nam dictum blandit hendrerit. In sed rutrum nulla. Aenean nunc tortor, vestibulum feugiat eros id, lacinia vulputate sapien. Nulla fermentum interdum tincidunt. Nulla eget nisi et erat varius sodales consequat quis eros. Pellentesque fringilla ultricies posuere. Sed tincidunt consectetur diam, sit amet ornare ante placerat vel.";

  self.postsFrameChangedNotifications = YES;
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_testFrameDidChange:) name:NSViewFrameDidChangeNotification object:self];

}

- (void)_testFrameDidChange:(NSNotification*)note {
  if (!NSEqualPoints(self.frame.origin, NSZeroPoint)) {
    NSLog(@"!");
  }
  id<GIDiffViewDelegate> delegate = self.delegate;
  if ([delegate respondsToSelector:@selector(diffView:didChangeContentHeight:)] && self.frame.size.height != self.bounds.size.height) {
    [delegate diffView:self didChangeContentHeight:self.frame.size.height];
  }
}

- (instancetype)initWithFrame:(NSRect)frameRect {
  if ((self = [super initWithFrame:frameRect])) {
    [self didFinishInitializing];
  }
  return self;
}

- (instancetype)initWithCoder:(NSCoder*)coder {
  if ((self = [super initWithCoder:coder])) {
    [self didFinishInitializing];
  }
  return self;
}

- (void)didUpdatePatch {
  [self clearSelection];
}

- (void)setPatch:(GCDiffPatch*)patch {
  if (patch != _patch) {
    _patch = patch;
    [self didUpdatePatch];
  }
}

- (BOOL)isEmpty {
  return NO;
}

- (CGFloat)updateLayoutForWidth:(CGFloat)width {
  return self.frame.size.height;
}

- (BOOL)hasSelection {
  return NO;
}

- (BOOL)hasSelectedText {
  return NO;
}

- (BOOL)hasSelectedLines {
  return NO;
}

- (void)clearSelection {
}

- (void)getSelectedText:(NSString**)text oldLines:(NSIndexSet**)oldLines newLines:(NSIndexSet**)newLines {
}

- (BOOL)validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)item {
  return NO;
}

- (void)layoutManager:(GIUnifiedDiffLayoutManager *)layoutManager textContainer:(NSTextContainer *)textContainer didChangeGeometryFromSize:(NSSize)oldSize {
  NSLog(@"! %@ {old %@} {new %@}", @(__FUNCTION__), NSStringFromSize(oldSize), NSStringFromSize(textContainer.containerSize));
}

@end
