// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#import <QuartzCore/QuartzCore.h>

@interface NSImage (kod)

+ (NSImage*)imageWithCIImage:(CIImage*)ciImage;

- (NSImage*)imageByApplyingCIFilterNamed:(NSString*)ciFilterName;

- (NSImage*)imageByApplyingCIFilterNamed:(NSString*)ciFilterName
                        filterParameters:(NSDictionary*)filterParameters;

- (CIImage*)ciImage;

@end
