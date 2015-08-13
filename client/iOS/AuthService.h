//
//  AuthInterface.h
//  DemoApp
//
//  Created by Thiago Alencar on 7/24/15.
//  Copyright © 2015 Alencar. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AuthInterface : NSObject

@property (nonatomic, strong) NSString *error;

+(void)authenticate:(NSString *)username and:(NSString *)password
           onSuccess:(void (^) (void)) successBlock
             onError:(void (^) (NSError * )) errorBlock;

+(void)registerUser:(NSString *)username and:(NSString *)password
          onSuccess:(void (^) (void)) successBlock
            onError:(void (^) (NSError * )) errorBlock;

+(BOOL)isSessionValid;

+(instancetype)sharedInstance;

+(void)showNetworkActivityIndicator:(BOOL)show ;

+(NSString *)expireDate;
+(void)setExpireDate:(NSString *)expires;

+(NSString *)gatewayToken;
+(void)setGatewayToken:(NSString *)gatewayToken;

+(NSString *)userId;
+(void)setUserId:(NSString *)userId;

+(NSString *)userName;
+(void)setUserName:(NSString *)userName;

+(NSString *)password;
+(void)setPassword:(NSString *)password;

+(void)resetSession;

@end
