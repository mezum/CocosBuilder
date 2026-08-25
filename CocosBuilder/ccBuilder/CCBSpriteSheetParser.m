/*
 * CocosBuilder: http://www.cocosbuilder.com
 *
 * Copyright (c) 2011 Viktor Lidholt
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

#import "CCBSpriteSheetParser.h"

static NSInteger strSort(id num1, id num2, void *context)
{
    return [(NSString*)num1 compare:num2 options:NSNumericSearch];
}

@implementation CCBSpriteSheetParser

- (void)dealloc
{
    [super dealloc];
}

+ (BOOL) isSpriteSheetFile:(NSString*) file
{
    NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithContentsOfFile:file];
    
    NSNumber* docVersion = [[dict objectForKey:@"metadata"] objectForKey:@"format"];
    if (!docVersion) return NO;
    
    if ([docVersion intValue] >= 0 && [docVersion intValue] <= 3)
    {
        if ([dict objectForKey:@"frames"]) return YES;
    }
    return NO;
}

+ (NSMutableArray*) findSpriteSheetsAtPath:(NSString*)assetsPath
{
    NSMutableArray* array = [NSMutableArray array];
    
    NSArray* dir = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:assetsPath error:NULL];
    for (int i = 0; i < [dir count]; i++)
    {
        NSString* file = [dir objectAtIndex:i];
        
        NSString* pathExt = [file pathExtension];
        NSString* absFile = [NSString stringWithFormat:@"%@%@",assetsPath, file];
        BOOL isHDFile = [[file stringByDeletingPathExtension] hasSuffix:@"-hd"];
        
        if ([pathExt isEqualToString:@"plist"] && [CCBSpriteSheetParser isSpriteSheetFile:absFile])
        {
            if (!isHDFile)
            {
                [array addObject:file];
                [[CCSpriteFrameCache sharedSpriteFrameCache] addSpriteFramesWithFile:absFile];
            }
        }
    }
    return array;
}

+ (NSMutableArray*) listFramesInSheet:(NSString *)absoluteFile
{
    NSMutableArray* frames = [NSMutableArray array];
    
    if ([CCBSpriteSheetParser isSpriteSheetFile:absoluteFile])
    {
        NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithContentsOfFile:absoluteFile];
        
        NSDictionary* dictFrames = [dict objectForKey:@"frames"];
        for (NSString* frameKey in dictFrames)
        {
            [frames addObject:frameKey];
        }
    }
    
    [frames sortUsingFunction:strSort context:NULL];
    
    return frames;
}

+ (NSImage*) imageNamed:(NSString*)spriteFile fromSheet:(NSString*)spriteSheetFile
{

    NSString* assetsPath = [spriteSheetFile stringByDeletingLastPathComponent];
    
    NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithContentsOfFile:spriteSheetFile];
    
    NSString* imgFile = [[dict objectForKey:@"metadata"] objectForKey:@"textureFileName"];
    
    NSString* absImgFile = [NSString stringWithFormat:@"%@/%@", assetsPath,imgFile];
    
    NSImage* tex;
            
    NSImageRep* imgRep = [NSImageRep imageRepWithContentsOfFile:absImgFile];
    
    if (![imgRep isKindOfClass:[NSBitmapImageRep class]]) return NULL;
    NSBitmapImageRep* bitmapRep = (NSBitmapImageRep*) imgRep;
            
    tex = [[NSImage alloc] initWithSize:NSMakeSize([bitmapRep pixelsWide], [bitmapRep pixelsHigh])];
    [tex addRepresentation:bitmapRep];
    [tex autorelease];
    
    NSDictionary* dictFrames = [dict objectForKey:@"frames"];
    NSDictionary* frameInfo = [dictFrames objectForKey:spriteFile];
    if (!frameInfo)
    {
        return NULL;
    }
    
    NSRect rect = NSRectFromString([frameInfo objectForKey:@"frame"]);
    BOOL rotated = [[frameInfo objectForKey:@"rotated"] boolValue];
    
    // The frame is listed at the sprite's own size; on the sheet a rotated one
    // occupies a rect with its width and height swapped.
    NSSize frameSize = rect.size;
    if (rotated)
    {
        rect.size = NSMakeSize(rect.size.height, rect.size.width);
    }
    
    // The sheet lists frames with the origin in the top left corner, which is
    // also how CGImage addresses pixels, so the rect crops directly. (NSImage's
    // -drawAtPoint:fromRect: measures from the bottom left instead, and the
    // -setFlipped: that used to compensate for it has been a no-op since 10.8.)
    CGImageRef cropped = CGImageCreateWithImageInRect([bitmapRep CGImage], NSRectToCGRect(rect));
    if (!cropped)
    {
        return NULL;
    }
    
    NSImage* imgFrame;
    if (rotated)
    {
        // cocos2d maps the stored frame's top left corner onto the sprite's
        // bottom left one (see -[CCSprite setTextureCoords:]), so turning it a
        // quarter turn counter clockwise puts it upright again. Draw into a
        // bitmap of a known size rather than -lockFocus, which would give the
        // main screen's backing scale instead of one pixel per pixel.
        NSBitmapImageRep* uprightRep = [[[NSBitmapImageRep alloc]
                                         initWithBitmapDataPlanes:NULL
                                         pixelsWide:frameSize.width
                                         pixelsHigh:frameSize.height
                                         bitsPerSample:8
                                         samplesPerPixel:4
                                         hasAlpha:YES
                                         isPlanar:NO
                                         colorSpaceName:NSDeviceRGBColorSpace
                                         bytesPerRow:0
                                         bitsPerPixel:0] autorelease];
        
        NSGraphicsContext* gc = [NSGraphicsContext graphicsContextWithBitmapImageRep:uprightRep];
        [NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext setCurrentContext:gc];
        
        CGContextRef ctx = [gc CGContext];
        CGContextTranslateCTM(ctx, frameSize.width, 0);
        CGContextRotateCTM(ctx, M_PI_2);
        CGContextDrawImage(ctx, CGRectMake(0, 0, rect.size.width, rect.size.height), cropped);
        
        [NSGraphicsContext restoreGraphicsState];
        
        imgFrame = [[[NSImage alloc] initWithSize:frameSize] autorelease];
        [imgFrame addRepresentation:uprightRep];
    }
    else
    {
        imgFrame = [[[NSImage alloc] initWithCGImage:cropped size:frameSize] autorelease];
    }
    CGImageRelease(cropped);
    
    
    return imgFrame;
}

+ (NSMutableArray*) listFramesInSheet:(NSString*)file assetsPath:(NSString*) assetsPath
{
    NSString* absoluteFile = [NSString stringWithFormat:@"%@%@",assetsPath,file];
    
    return [CCBSpriteSheetParser listFramesInSheet:absoluteFile];
}

@end
