//
//  DemoDataRequest.m
//  iTotemFramework
//
//  Created by Sword Zhou on 7/18/13.
//  Copyright (c) 2013 iTotemStudio. All rights reserved.
//

#import "DemoDataRequest.h"

@implementation DemoDataRequest

-(ITTParameterEncoding)parmaterEncoding
{
    return ITTJSONParameterEncoding;
}

- (ITTRequestMethod)getRequestMethod
{
    return ITTRequestMethodPost;
}

-(BOOL)useDumpyData
{
    return YES;
}

-(NSString*)dumpyResponseString
{
    return [NSString stringWithFileInMainBundle:@"mockData" ofType:@"json"];
}

- (NSString*)getRequestUrl
{
   return @"http://www.raywenderlich.com/downloads/weather_sample/weather.php";
}

- (void)processResult
{
    [super processResult];
    __unused NSArray * array = self.handleredResult[@"data"];

}
@end
