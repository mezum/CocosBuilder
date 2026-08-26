/*
 * CocosBuilder: http://www.cocosbuilder.com
 *
 * Copyright (c) 2012 Zynga Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#import "SequencerOutlineView.h"
#import "SequencerHandler.h"
#import "SequencerSequence.h"

@implementation SequencerClipView

- (NSRect) constrainBoundsRect:(NSRect)proposedBounds
{
    NSRect bounds = [super constrainBoundsRect:proposedBounds];
    bounds.origin.x = 0;
    return bounds;
}

@end

@implementation SequencerOutlineView

- (void) awakeFromNib
{
    [super awakeFromNib];
    
    [self setGridStyleMask:NSTableViewSolidHorizontalGridLineMask];
    [self setGridColor:[NSColor gridColor]];
}

// Disable draggging of rows for expander and sequencer column
- (void)mouseDown:(NSEvent *)theEvent
{
    NSPoint mouseLocationInWindow = [theEvent locationInWindow];
    
    // Translate the mouse co-ordinates so they are relative to the tableview's...
    NSPoint mouseLocationInTable = [self convertPoint:
                                    mouseLocationInWindow fromView: NULL];
    
    SequencerHandler* sh = (SequencerHandler*) [self dataSource];
    
    NSInteger column = [self columnAtPoint:mouseLocationInTable];
    
    if (column == [self columnWithIdentifier:@"sequencer"])
    {
        // Events in the sequencer are handled by the SequencerOutlineView which
        // is placed on top of the outline view
        return;
    }
    else if (column == [self columnWithIdentifier:@"expander"])
    {
        sh.dragAndDropEnabled = NO;
        [sh toggleSeqExpanderForRow:(int)[self rowAtPoint:mouseLocationInTable]];
        return;
    }
    else
    {
        sh.dragAndDropEnabled = YES;
    }
    
    [super mouseDown: theEvent];
}

- (void)drawGridInClipRect:(NSRect)clipRect
{
    NSRect lastRowRect = [self rectOfRow:[self numberOfRows]-1];
    NSRect myClipRect = NSMakeRect(0, 0, lastRowRect.size.width, NSMaxY(lastRowRect));
    NSRect finalClipRect = NSIntersectionRect(clipRect, myClipRect);
    [super drawGridInClipRect:finalClipRect];
}

- (void) drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
    
    SequencerHandler* sh = [SequencerHandler sharedHandler];
    SequencerSequence* seq = sh.currentSequence;
    
    // Where the dope sheet column actually starts; the hierarchy column can be
    // resized, so this is not a fixed offset.
    NSInteger dopeColumn = [self columnWithIdentifier:@"sequencer"];
    CGFloat dopeEdge = (dopeColumn < 0) ? 0 : [self rectOfColumn:dopeColumn].origin.x;
    if (!imgEndmarker) imgEndmarker = [[NSImage imageNamed:@"seq-endmarker.png"] retain];
    if (!imgStartmarker) imgStartmarker = [[NSImage imageNamed:@"seq-startmarker.png"] retain];
    
    // The markers shade what is out of reach, which is the padding beyond the
    // few frames of slack the timeline scrolls past its ends - not the slack
    // itself. The rows run through that, so the dope sheet stays continuous all
    // the way to both edges.
    float slack = [sh timelineScrollSlack];
    float height = self.bounds.size.height;
    
    [[NSGraphicsContext currentContext] saveGraphicsState];
    NSRectClip(NSMakeRect(dopeEdge, 0, self.bounds.size.width - dopeEdge, height));
    
    float xEndPos = [seq timeToPosition:seq.timelineLength + slack];
    [imgEndmarker drawInRect:NSMakeRect(dopeEdge+xEndPos, 0, 32, height) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1];
    
    float xStartPos = [seq timeToPosition:-slack];
    [imgStartmarker drawInRect:NSMakeRect(dopeEdge+xStartPos-(TIMELINE_PAD_PIXELS+1), 0, TIMELINE_PAD_PIXELS+1, height) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1];
    
    [[NSGraphicsContext currentContext] restoreGraphicsState];
}

- (void) dealloc
{
    [imgEndmarker release];
    [imgStartmarker release];
    [super dealloc];
}

@end
