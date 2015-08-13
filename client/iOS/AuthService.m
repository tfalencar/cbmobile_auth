//
//  AuthInterface.m
//  ConektApp
//
//  Created by Thiago Alencar on 7/24/15.
//  Copyright © 2015 Alencar. All rights reserved.
//

#import "AuthInterface.h"
#import "AFNetworkActivityIndicatorManager.h"
#import <CouchbaseLite/CouchbaseLite.h>
#import "AFNetworking.h"
#import "ISO8601DateFormatter.h"
#import "FDKeychain.h"

@implementation AuthInterface

static NSString *const kKeyChainServiceName = @"demoAppService";
static NSString *const kKeyChainExpiresKey = @"expires";
static NSString *const kKeyChainGatewayTokenKey = @"gatewayToken";
static NSString *const kKeyChainUserIdKey = @"userId";
static NSString *const kKeyChainUserNameKey = @"username";
static NSString *const kKeyChainPasswordKey = @"password";

static NSString *const kApiURL = @"http://localhost:8080/"; //replace with your API endpoint address

+ (instancetype)sharedInstance
{
    static AuthInterface *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[AuthInterface alloc] init];
    });
    return sharedInstance;
}

+ (BOOL)isSessionValid
{
    if([AuthInterface expireDate])
    {
        ISO8601DateFormatter *formatter = [[ISO8601DateFormatter alloc] init];
        NSDate *expireDate = [formatter dateFromString:[AuthInterface expireDate]];
        formatter = nil;
        
        //check if current time is earlier than expiration date
        if([expireDate compare: [NSDate date]] == NSOrderedDescending)
            return YES;
        else
            return NO;
    }
    else
    {
        return NO;
    }
}

+(void)authenticate:(NSString *)username and:(NSString *)password
           onSuccess:(void (^) (void)) successBlock
             onError:(void (^) (NSError * )) errorBlock
{
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    
    AFSecurityPolicy *securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
    securityPolicy.allowInvalidCertificates = YES;
    manager.securityPolicy = securityPolicy;
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    
    //retrieve authToken
    NSString * authToken = [AuthInterface gatewayToken];
    if (!authToken) {
        authToken = @"";
    }
    
    NSDictionary *params = @{@"username": username, @"password": password};
    
    [manager POST:[NSString stringWithFormat:@"%@%@", kApiURL, @"api/v1.0/auth"] parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject)
     {
         NSLog(@"JSON: %@", (NSDictionary *)responseObject);
         
         //decode JWT token, and extract sync gateway session token
         
         NSDictionary *sessionObject = (NSDictionary *)responseObject;
         NSString * jwt = [sessionObject objectForKey:@"token"];
         
         //check if data is correct
         if (([jwt isEqualToString:@""]) || jwt == nil) {
              NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedStringFromTable(@"JWT data failed decoding", @"ConektApp", nil)};
             NSError * error = [NSError errorWithDomain:@"Server response error" code:NSURLErrorCannotParseResponse userInfo:userInfo];
             errorBlock(error);
             return;
         }
         
         NSString * payload = [AuthInterface getPayloadFromJWT: jwt];
         NSData * data = [payload dataUsingEncoding: NSUTF8StringEncoding];
         
         NSError * error;
         NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
         
         NSLog(@"Payload: %@", jsonDict);
         
         if(error) { errorBlock(error); return; }
         
         [AuthInterface setExpireDate: [jsonDict objectForKey:@"exp"]];
         [AuthInterface setUserId: [jsonDict objectForKey:@"username"]];
         
         NSString *gatewayJSONstring = [jsonDict objectForKey:@"sg-session"];
         data = [gatewayJSONstring dataUsingEncoding: NSUTF8StringEncoding];
         jsonDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
         
         if(error) { errorBlock(error); return; }
         
         NSLog(@"the session token: %@", [jsonDict objectForKey:@"session_id"]);
         
         // Update data
         [AuthInterface setGatewayToken: [jsonDict objectForKey:@"session_id"]];
         
         successBlock();
         
     } failure:^(AFHTTPRequestOperation *operation, NSError *error)
     {
         NSLog(@"Error: %@", error);
         
         errorBlock(error);
     }];
}

+(NSString*)getPayloadFromJWT:(NSString*)token
{
    NSArray * segments = [token componentsSeparatedByString:@"."];
    NSString * base64String = [segments objectAtIndex:1];
    int requiredLength = (int)(4 * ceil((float)[base64String length] / 4.0));
    unsigned long nbrPaddings = requiredLength - [base64String length];
    
    if (nbrPaddings > 0) {
        NSString *padding =
        [[NSString string] stringByPaddingToLength:nbrPaddings
                                        withString:@"=" startingAtIndex:0];
        base64String = [base64String stringByAppendingString:padding];
    }
    
    base64String = [base64String stringByReplacingOccurrencesOfString:@"-" withString:@"+"];
    base64String = [base64String stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
    
    NSData *decodedData = [[NSData alloc] initWithBase64EncodedString:base64String options:0];
    NSString *decodedString = [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];
    return decodedString;
}

+(void)registerUser:(NSString *)username and:(NSString *)password
          onSuccess:(void (^) (void)) successBlock
            onError:(void (^) (NSError * )) errorBlock
{
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    
    AFSecurityPolicy *securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
    securityPolicy.allowInvalidCertificates = YES;
    manager.securityPolicy = securityPolicy;
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    
    //retrieve authToken
    NSString * authToken = [AuthInterface gatewayToken];
    if (!authToken) {
        authToken = @"";
    }
    
    NSDictionary *params = @{@"username": username, @"password": password};
    
    [manager POST:[NSString stringWithFormat:@"%@%@", kApiURL, @"api/v1.0/register"] parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject)
     {
         NSLog(@"JSON: %@", (NSDictionary *)responseObject);
         
         NSDictionary *sessionObject = [(NSDictionary *)responseObject objectForKey:@"response"];
         
         // Update data
         [AuthInterface setGatewayToken: [sessionObject objectForKey:@"token"]];
         [AuthInterface setExpireDate: [sessionObject objectForKey:@"expiry_date"]];
         [AuthInterface setUserId: [sessionObject objectForKey:@"user_id"]];
         
         successBlock();
         
     } failure:^(AFHTTPRequestOperation *operation, NSError *error)
     {
         NSLog(@"Error: %@", error);
         
         errorBlock(error);
     }];

}

#pragma mark network activity indicator

+(void)showNetworkActivityIndicator:(BOOL)show
{
    static BOOL loginReplicationProgressDisplayedIndicator = NO;
    
    if (show && !loginReplicationProgressDisplayedIndicator) {
        loginReplicationProgressDisplayedIndicator = YES;
        [[AFNetworkActivityIndicatorManager sharedManager] incrementActivityCount];
    }
    else if (!show && loginReplicationProgressDisplayedIndicator) {
        loginReplicationProgressDisplayedIndicator = NO;
        [[AFNetworkActivityIndicatorManager sharedManager] decrementActivityCount];
    }
}

#pragma mark key chain setters and getters


+(NSString *)expireDate {
    return [FDKeychain itemForKey:kKeyChainExpiresKey forService:kKeyChainServiceName error:NULL];
}

+(void)setExpireDate:(NSString *)expires {
    [FDKeychain saveItem:expires forKey:kKeyChainExpiresKey forService:kKeyChainServiceName error:NULL];
}

+(NSString *)gatewayToken {
    return [FDKeychain itemForKey:kKeyChainGatewayTokenKey forService:kKeyChainServiceName error:NULL];
}

+(void)setGatewayToken:(NSString *)gatewayToken {
    [FDKeychain saveItem:gatewayToken forKey:kKeyChainGatewayTokenKey forService:kKeyChainServiceName error:NULL];
}

+(NSString *)userId {
    return [FDKeychain itemForKey:kKeyChainUserIdKey forService:kKeyChainServiceName error:NULL];
}

+(void)setUserId:(NSString *)userId {
    [FDKeychain saveItem:userId forKey:kKeyChainUserIdKey forService:kKeyChainServiceName error:NULL];
}

+(NSString *)userName {
    return [FDKeychain itemForKey:kKeyChainUserNameKey forService:kKeyChainServiceName error:NULL];
}

+(void)setUserName:(NSString *)userName {
    [FDKeychain saveItem:userName forKey:kKeyChainUserNameKey forService:kKeyChainServiceName error:NULL];
}

+(NSString *)password {
    return [FDKeychain itemForKey:kKeyChainPasswordKey forService:kKeyChainServiceName error:NULL];
}

+(void)setPassword:(NSString *)password {
    [FDKeychain saveItem:password forKey:kKeyChainPasswordKey forService:kKeyChainServiceName error:NULL];
}

+(void)resetSession
{
    //expire session
    ISO8601DateFormatter *formatter = [[ISO8601DateFormatter alloc] init];
    NSString *theDate = [formatter stringFromDate:[NSDate date]];
    formatter = nil;
    [self setExpireDate:theDate];
    
    //reset user
    [self setUserName:@""];
    [self setPassword:@""];
    
    [self setGatewayToken:@""];
    [self setUserId:@""];
}

@end
