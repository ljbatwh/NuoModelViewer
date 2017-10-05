//
//  ModelOperationTexturePopover.h
//  ModelViewer
//
//  Created by dfeng on 10/5/17.
//  Copyright © 2017 middleware. All rights reserved.
//

#import <Cocoa/Cocoa.h>



@class ModelOperationPanel;



@interface ModelOperationTexturePopover : NSViewController


- (instancetype)initWithPopover:(NSPopover*)popover
                withSourcePanel:(ModelOperationPanel*)sourcePanel;


@end
