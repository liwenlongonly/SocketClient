//
//  ITTAFNBaseDataRequest.m
//  iTotemFramework
//
//  Created by Sword Zhou on 7/18/13.
//  Copyright (c) 2013 iTotemStudio. All rights reserved.
//

#import "ITTAFNBaseDataRequest.h"
#import "ITTNetworkTrafficManager.h"
#import "AFHTTPRequestOperation.h"
#import "ITTAFQueryStringPair.h"
#import "ITTDataRequestManager.h"
#import "ITTFileModel.h"
#import <AFNetworking.h>

@interface ITTAFNBaseDataRequest()
{
    AFHTTPRequestOperation  *_requestOperation;
}

@end

@implementation ITTAFNBaseDataRequest


- (NSString *)contentType:(ITTParameterEncoding)parameterEncoding
{
    NSString *charset = @"utf-8";//
    NSString *contentType = nil;
    if (parameterEncoding == ITTURLParameterEncoding) {
        contentType = [NSString stringWithFormat:@"application/x-www-form-urlencoded; charset=%@", charset];
    }else if(parameterEncoding == ITTJSONParameterEncoding){
        contentType = [NSString stringWithFormat:@"application/json; charset=%@", charset];
    }else if(parameterEncoding == ITTPropertyListParameterEncoding){
        
    }
    return contentType;
}

- (NSMutableURLRequest *)requestWithParams:(NSDictionary *)params url:(NSString *)url
{
    NSStringEncoding stringEncoding = NSUTF8StringEncoding;
	// process params
	NSMutableDictionary *allParams = [NSMutableDictionary dictionaryWithCapacity:10];
	[allParams addEntriesFromDictionary: params];
	NSDictionary *staticParams = [self getStaticParams];
	if (staticParams != nil) {
		[allParams addEntriesFromDictionary:staticParams];
	}
    NSURL *URL = [NSURL URLWithString:url];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    // used to monitor network traffic , this is not accurate number.
    long long postBodySize = 0;    
	if (ITTRequestMethodGet == [self getRequestMethod]) {
        NSString *paramString = ITTAFQueryStringFromParametersWithEncoding(allParams, stringEncoding);
        NSUInteger found = [url rangeOfString:@"?"].location;
        url = [url stringByAppendingFormat: NSNotFound == found? @"?%@" : @"&%@", paramString];
        URL = [NSURL URLWithString:url];
        [request setURL:URL];
        [request setHTTPMethod:@"GET"];
        postBodySize += [url lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
        ITTDINFO(@"request url %@", url);
    }
    else {
        switch (self.parmaterEncoding) {
            case ITTURLParameterEncoding: {
                NSString *paramString = ITTAFQueryStringFromParametersWithEncoding(allParams, stringEncoding);
                NSString *contentType = [self contentType:ITTURLParameterEncoding];
                [request setValue:contentType forHTTPHeaderField:@"Content-Type"];
                ITTDINFO(@"url:%@&data=%@",url,[paramString urlDecodedString]);
                NSData *jsonFormatPostData = [paramString dataUsingEncoding:NSUTF8StringEncoding];
                [request setHTTPBody:jsonFormatPostData];
                postBodySize += [jsonFormatPostData length];
                break;
            }
            case ITTJSONParameterEncoding: {
                NSError *error = nil;
                NSString *contentType = [self contentType:ITTJSONParameterEncoding];
                [request setValue:contentType forHTTPHeaderField:@"Content-Type"];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wassign-enum"
				NSString *jsonString = [NSJSONSerialization jsonStringFromDictionary:allParams];
				NSData *jsonFormatPostData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
                [request setHTTPBody:jsonFormatPostData];
                if (error) {
                    ITTDERROR(@"create request error %@", error);
                }
                postBodySize += [jsonFormatPostData length];
#pragma clang diagnostic pop                
                break;
            }
            case ITTPropertyListParameterEncoding:
                //to do
                
                break;
            default:
                break;
        }
        [request setHTTPMethod:@"POST"];
        ITTDINFO(@"request url %@", url);        
    }
    [request addValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
    if (_filePath && [_filePath length] > 0) {
        //create folder
        _requestOperation.outputStream = [NSOutputStream outputStreamToFileAtPath:_filePath append:NO];
    }
    [[ITTNetworkTrafficManager sharedManager] logTrafficOut:postBodySize];
    return request;
}

+ (void)showNetworkActivityIndicator
{
#if TARGET_OS_IPHONE
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
#endif
}

+ (void)hideNetworkActivityIndicator
{
#if TARGET_OS_IPHONE
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
#endif
}

- (void)networkingOperationDidStart:(NSNotification *)notification
{
    ITTDINFO(@"- (void)networkingOperationDidStart:(NSNotification *)notification");            
    AFURLConnectionOperation *connectionOperation = [notification object];
    if (connectionOperation.request.URL) {
        [[self class] showNetworkActivityIndicator];
        [self showIndicator:TRUE];
    }
}

- (void)networkingOperationDidFinish:(NSNotification *)notification
{
    ITTDINFO(@"- (void)networkingOperationDidFinish:(NSNotification *)notification");
    AFURLConnectionOperation *connectionOperation = [notification object];
    if (connectionOperation.request.URL) {
        [[self class] hideNetworkActivityIndicator];
        [self showIndicator:FALSE];
    }
}

- (void)notifyDelegateDownloadProgress
{
    //using block
    if (_onRequestProgressChangedBlock) {
        _onRequestProgressChangedBlock(self, _currentProgress);
    }
}

- (void)generateRequestWithUrl:(NSString*)url withParameters:(NSDictionary*)params
{
    NSMutableURLRequest *request = [self requestWithParams:params url:url];
    _requestOperation = [[AFHTTPRequestOperation alloc] initWithRequest:request];    
    [self showIndicator:YES];
    __weak typeof(self) weakSelf = self;    
    [_requestOperation setCompletionBlockWithSuccess:
     ^(AFHTTPRequestOperation *operation, id responseObject) {
         
         [weakSelf handleResultString:operation.responseString];
         [weakSelf showIndicator:NO];
         [weakSelf doRelease];
     }
     failure:^(AFHTTPRequestOperation *operation, NSError *error) {
         [weakSelf notifyDelegateRequestDidErrorWithError:error];
         [weakSelf handleError:error];
         [weakSelf showIndicator:NO];
         [weakSelf doRelease];
     }];
    [_requestOperation setDownloadProgressBlock:
        ^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
            weakSelf.currentProgress = 1.0*totalBytesRead/totalBytesExpectedToRead;
            [weakSelf notifyDelegateDownloadProgress];
        }];
}

- (void)doRequestWithParams:(NSDictionary*)params
{
    [self generateRequestWithUrl:self.requestUrl withParameters:params];
    [_requestOperation start];
}

- (void)handleError:(NSError*)error
{
    if (error) {
        NSString *errorMsg = nil;
        if ([NSURLErrorDomain isEqualToString:error.domain]) {
            errorMsg = @"无法连接到网络";
        }
        if (!_useSilentAlert) {
            [self showNetowrkUnavailableAlertView:errorMsg];
        }
    }
}

- (void)registerRequestNotification
{
    //register start and finish notification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkingOperationDidStart:) name:AFNetworkingOperationDidStartNotification object:_requestOperation];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkingOperationDidFinish:) name:AFNetworkingOperationDidFinishNotification object:_requestOperation];
}

- (void)unregisterRequestNotification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AFNetworkingOperationDidStartNotification object:_requestOperation];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AFNetworkingOperationDidFinishNotification object:_requestOperation];
}

- (void)cancelRequest
{
    ITTDINFO(@"%@ request is cancled", [self class]);
    [_requestOperation cancel];
    //to cancel here
    if (_onRequestCanceled) {
        _onRequestCanceled(self);
    }
    [self showIndicator:FALSE];
    [self doRelease];
}
@end
