//
//  F53OSCBrowser.m
//  F53OSC
//
//  Created by Brent Lord on 8/27/20.
//  Adapted from QLKBrowser by Zach Waugh.
//
//  Copyright (c) 2013-2020 Figure 53 LLC, https://figure53.com
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#if !__has_feature(objc_arc)
#error This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#import "F53OSCBrowser.h"

#include <netinet/in.h>
#include <arpa/inet.h>


#ifndef RELEASE
#define DEBUG_BROWSER 0
#endif


NS_ASSUME_NONNULL_BEGIN

@implementation F53OSCClientRecord

- (instancetype)init
{
    self = [super init];
    if ( self )
    {
        self.port = 0;
        self.useTCP = NO;
        self.hostAddresses = @[];
    }
    return self;
}

- (id)copyWithZone:(nullable NSZone *)zone
{
    F53OSCClientRecord *copy = [[F53OSCClientRecord allocWithZone:zone] init];
    copy.port = self.port;
    copy.useTCP = self.useTCP;
    copy.hostAddresses = [self.hostAddresses copyWithZone:zone];
    copy.netService = self.netService;
    return copy;
}

@end


@interface F53OSCBrowser () <NSNetServiceBrowserDelegate, NSNetServiceDelegate>

@property (assign, readwrite)                   BOOL running;

@property (nonatomic, strong, nullable)         NSNetServiceBrowser *netServiceDomainsBrowser;
@property (nonatomic, strong, nullable)         NSNetServiceBrowser *netServiceBrowser;
@property (nonatomic, strong)                   NSMutableArray<NSNetService *> *unresolvedNetServices;

@property (nonatomic, strong)                   NSMutableArray<F53OSCClientRecord *> *mutableClientRecords;

- (void)setNeedsBeginResolvingNetServices;
- (void)beginResolvingNetServices;

- (nullable F53OSCClientRecord *)clientRecordForHost:(NSString *)host port:(UInt16)port;
- (nullable F53OSCClientRecord *)clientRecordForNetService:(NSNetService *)netService;

+ (nullable NSString *)IPAddressFromData:(NSData *)data resolveIPv6Addresses:(BOOL)resolveIPv6Addresses;

@end


@implementation F53OSCBrowser

- (instancetype)init
{
    self = [super init];
    if ( self )
    {
        self.domain = @"local.";
        self.serviceType = @"";
        self.useTCP = YES;
        self.resolveIPv6Addresses = NO;
        
        self.running = NO;
        self.netServiceBrowser = nil;
        
        self.unresolvedNetServices = [NSMutableArray arrayWithCapacity:1];
        self.mutableClientRecords = [NSMutableArray arrayWithCapacity:1];
    }
    return self;
}

- (void)dealloc
{
    [self stop];
}

#pragma mark - custom getters/setters

- (NSArray<F53OSCClientRecord *> *)clients
{
    return self.mutableClientRecords.copy;
}

- (void)setDomain:(NSString *)domain
{
    if ( domain.length == 0 )
        return;
    
    if ( [_domain isEqualToString:domain] == NO )
    {
        BOOL wasRunning = self.running;
        if ( wasRunning )
            [self stop];
        
        _domain = [domain copy];
        
        if ( wasRunning )
            [self start];
    }
}

- (void)setServiceType:(NSString *)serviceType
{
    if ( serviceType.length == 0 )
        return;
    
    if ( [_serviceType isEqualToString:serviceType] == NO )
    {
        BOOL wasRunning = self.running;
        if ( wasRunning )
            [self stop];
        
        _serviceType = [serviceType copy];
        
        if ( wasRunning )
            [self start];
    }
}

- (void)setUseTCP:(BOOL)useTCP
{
    if ( _useTCP != useTCP )
    {
        BOOL wasRunning = self.running;
        if ( wasRunning )
            [self stop];
        
        _useTCP = useTCP;
        
        if ( wasRunning )
            [self start];
    }
}

#pragma mark -

- (void)start
{
#if DEBUG_BROWSER
    if ( self.running )
        NSLog( @"[browser] starting browser - already running" );
    else
        NSLog( @"[browser] starting browser" );
#endif
    
    if ( self.running )
        return;
    
    if ( self.domain.length == 0 )
        return;
    if ( self.serviceType.length == 0 )
        return;
    
    // Create Bonjour browser to find available domains
    self.netServiceDomainsBrowser = [[NSNetServiceBrowser alloc] init];
    self.netServiceDomainsBrowser.delegate = self;
    
    [self.netServiceDomainsBrowser searchForBrowsableDomains];
}

- (void)stop
{
#if DEBUG_BROWSER
    NSLog( @"[browser] stopping browser" );
#endif
    
    self.delegate = nil;
    
    // Stop bonjour browsers - delegate methods will perform cleanup
    [self.netServiceDomainsBrowser stop];
    [self.netServiceBrowser stop];
    
    // Stop/remove all clients
    NSArray<F53OSCClientRecord *> *clientRecords = self.mutableClientRecords.copy;
    for ( F53OSCClientRecord *aClientRecord in clientRecords )
    {
        aClientRecord.netService = nil;
        
        [self.mutableClientRecords removeObject:aClientRecord];
        [self.delegate browser:self didRemoveClientRecord:aClientRecord];
    }
}

#pragma mark -

- (void)setNeedsBeginResolvingNetServices
{
    // this method may be called many times in rapid succession by an NSNetService delegate callback (e.g. if `moreComing` is YES)
    // - so we cancel previous perform requests to ensure each service begins resolving only once
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(beginResolvingNetServices) object:nil];
    [self performSelector:@selector(beginResolvingNetServices) withObject:nil afterDelay:0.5];
}

- (void)beginResolvingNetServices
{
    NSArray<NSNetService *> *netServices = [self.unresolvedNetServices copy];
    for ( NSNetService *aService in netServices )
    {
        if ( aService.addresses.count )
            continue;
        
        [aService resolveWithTimeout:5.0];
    }
}

#pragma mark - Clients

- (nullable F53OSCClientRecord *)clientRecordForHost:(NSString *)host port:(UInt16)port
{
    for ( F53OSCClientRecord *aClientRecord in self.mutableClientRecords )
    {
        if ( aClientRecord.port != port )
            continue;
        
        for ( NSString *aHostAddress in aClientRecord.hostAddresses )
        {
            if ( [aHostAddress isEqualToString:host] && aClientRecord.port == port )
                return aClientRecord;
        }
    }
    
    return nil;
}

- (nullable F53OSCClientRecord *)clientRecordForNetService:(NSNetService *)netService
{
    for ( F53OSCClientRecord *aClientRecord in self.mutableClientRecords )
    {
        if ( [aClientRecord.netService isEqual:netService] )
            return aClientRecord;
    }
    
    return nil;
}

#pragma mark - NSNetServiceBrowserDelegate

- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)browser
{
#if DEBUG_BROWSER
    if ( browser == self.netServiceDomainsBrowser )
        NSLog( @"[browser] starting bonjour - browsable domains search" );
    else if ( browser == self.netServiceBrowser )
        NSLog( @"[browser] starting bonjour browser - \"%@\"", self.domain );
    else
        NSLog( @"[browser] netServiceBrowserWillSearch: %@", browser );
#endif
    
    if ( browser == self.netServiceDomainsBrowser )
        self.running = YES;
}

- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)browser
{
#if DEBUG_BROWSER
    if ( browser == self.netServiceDomainsBrowser )
        NSLog( @"[browser] stopping bonjour - browsable domains search" );
    else if ( browser == self.netServiceBrowser )
        NSLog( @"[browser] stopping bonjour (TCP) - \"%@\"", self.domain );
    else
        NSLog( @"[browser] netServiceBrowserDidStopSearch: %@", browser );
#endif
    
    if ( browser == self.netServiceDomainsBrowser )
    {
        self.running = NO;
        
        self.netServiceDomainsBrowser.delegate = nil;
        self.netServiceDomainsBrowser = nil;
    }
    else if ( browser == self.netServiceBrowser )
    {
        self.netServiceBrowser.delegate = nil;
        self.netServiceBrowser = nil;
    }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didNotSearch:(NSDictionary<NSString *, NSNumber *> *)errorDict
{
#if DEBUG_BROWSER
    NSLog( @"[browser] netServiceBrowser:didNotSearch:" );
    for ( NSString *aError in errorDict )
    {
        NSLog( @"[browser] search error %@: %@, ", (NSNumber *)errorDict[aError], aError );
    }
#endif
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didFindDomain:(NSString *)domainString moreComing:(BOOL)moreComing
{
#if DEBUG_BROWSER
    NSLog( @"[browser] netServiceBrowser:didFindDomain: \"%@\" moreComing: %@", domainString, ( moreComing ? @"YES" : @"NO" ) );
#endif
    
    if ( !self.netServiceBrowser && [domainString isEqualToString:self.domain] )
    {
        self.netServiceBrowser = [[NSNetServiceBrowser alloc] init];
        self.netServiceBrowser.delegate = self;
        
        [self.netServiceBrowser searchForServicesOfType:self.serviceType inDomain:self.domain];
    }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didFindService:(NSNetService *)netService moreComing:(BOOL)moreComing
{
#if DEBUG_BROWSER
    NSLog( @"[browser] netServiceBrowser:didFindService: \"%@\" moreComing: %@", netService, ( moreComing ? @"YES" : @"NO" ) );
#endif
    
    netService.delegate = self;
    [self.unresolvedNetServices addObject:netService];
    
    // this may be called many times, especially when `moreComing` is YES
    // - so we coalesce delegate callbacks using our "setNeedsNotify..." method
    [self setNeedsBeginResolvingNetServices];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)netService moreComing:(BOOL)moreComing
{
#if DEBUG_BROWSER
    NSLog( @"[browser] netServiceBrowser:didRemoveService: %@ moreComing: %@", netService, ( moreComing ? @"YES" : @"NO" ) );
#endif
    
    F53OSCClientRecord *clientRecord = [self clientRecordForNetService:netService];
    if ( !clientRecord )
        return;
    
    [self.mutableClientRecords removeObject:clientRecord];
    [self.delegate browser:self didRemoveClientRecord:clientRecord];
}

#pragma mark - NSNetServiceDelegate

- (void)netServiceDidResolveAddress:(NSNetService *)netService
{
#if DEBUG_BROWSER
    NSLog( @"[browser] netServiceDidResolveAddress: %@", netService );
#endif
#if !RELEASE
    NSAssert( [NSThread isMainThread], @"[browser] netServiceDidResolveAddress: is not thread-safe and expects to be called on the main thread." );
#endif
    
    // Allow delegate to deny connecting to this service
    if ( [self.delegate respondsToSelector:@selector(browser:shouldAcceptNetService:)] &&
        [self.delegate browser:self shouldAcceptNetService:netService] == NO )
        return;
    
    NSInteger port = netService.port;
    if ( port < 0 ) // -1 = not resolved
        return;
    
    NSMutableArray<NSString *> *hostAddresses = [NSMutableArray arrayWithCapacity:netService.addresses.count];
    for ( NSData *aAddress in netService.addresses )
    {
        NSString *host = [F53OSCBrowser IPAddressFromData:aAddress resolveIPv6Addresses:self.resolveIPv6Addresses];
        if ( host )
            [hostAddresses addObject:host];
    }
    if ( !hostAddresses.count )
        return;
    
    F53OSCClientRecord *clientRecord = [F53OSCClientRecord new];
    clientRecord.port = port;
    clientRecord.useTCP = self.useTCP;
    clientRecord.hostAddresses = hostAddresses.copy;
    clientRecord.netService = netService;
    
    // Once resolved, we can remove the net service from our local records.
    // (The client record will still hold on to it, though.)
    netService.delegate = nil;
    [self.unresolvedNetServices removeObject:netService];
    
#if DEBUG_BROWSER
    NSLog( @"[browser] adding client: %@", client );
#endif
    
    [self.mutableClientRecords addObject:clientRecord];
    [self.delegate browser:self didAddClientRecord:clientRecord];
}

- (void)netService:(NSNetService *)netService didNotResolve:(NSDictionary<NSString *, NSNumber *> *)error
{
#if !RELEASE
    NSAssert( [NSThread isMainThread], @"[browser] netService:didNotResolve: is not thread-safe and expects to be called on the main thread." );
#endif
    
    [netService stop];
    netService.delegate = nil;
    [self.unresolvedNetServices removeObject:netService];
    
    NSLog( @"[browser] Error: Failed to resolve service: %@ - %@", netService, error );
}

#pragma mark - Utility

+ (nullable NSString *)IPAddressFromData:(NSData *)data resolveIPv6Addresses:(BOOL)resolveIPv6Addresses
{
    typedef union {
        struct sockaddr sa;
        struct sockaddr_in ipv4;
        struct sockaddr_in6 ipv6;
    } ip_socket_address;
    
    ip_socket_address *socketAddress = (ip_socket_address *)data.bytes;
    
    if ( socketAddress && AF_INET == socketAddress->sa.sa_family )
    {
        char buffer[INET_ADDRSTRLEN];
        memset( buffer, 0, INET_ADDRSTRLEN );
        
        const char *formatted = inet_ntop( AF_INET,
                                          (void *)&(socketAddress->ipv4.sin_addr),
                                          buffer,
                                          (socklen_t)sizeof( buffer ) );
        if ( formatted == NULL )
            return nil;
        
        return [NSString stringWithCString:formatted encoding:NSASCIIStringEncoding];
    }
    else if ( resolveIPv6Addresses && socketAddress && AF_INET6 == socketAddress->sa.sa_family )
    {
        char buffer[INET6_ADDRSTRLEN];
        memset( buffer, 0, INET6_ADDRSTRLEN );
        
        const char *formatted = inet_ntop( AF_INET6,
                                          (void *)&(socketAddress->ipv6.sin6_addr),
                                          buffer,
                                          (socklen_t)sizeof( buffer ) );
        if ( formatted == NULL )
            return nil;
        
        return [NSString stringWithCString:formatted encoding:NSASCIIStringEncoding];
    }
    else
    {
        return nil;
    }
}

@end

NS_ASSUME_NONNULL_END
