
#import "MultipartFormDataParser.h"
#import "DDData.h"
#import "HTTPLogging.h"

#pragma mark log level

#ifdef DEBUG
static const int httpLogLevel = HTTP_LOG_LEVEL_WARN;
#else
static const int httpLogLevel = HTTP_LOG_LEVEL_WARN;
#endif

#ifdef __x86_64__
#define FMTNSINT "li"
#else
#define FMTNSINT "i"
#endif


//-----------------------------------------------------------------
// interface MultipartFormDataParser (private)
//-----------------------------------------------------------------


@interface MultipartFormDataParser (private)
+ (NSData*) decodedDataFromData:(NSData*) data encoding:(int) encoding;

- (int) findHeaderEnd:(NSData*) workingData fromOffset:(int) offset;
- (int) findContentEnd:(NSData*) data fromOffset:(int) offset;

- (int) numberOfBytesToLeavePendingWithData:(NSData*) data length:(NSUInteger) length encoding:(int) encoding;
- (int) offsetTillNewlineSinceOffset:(int) offset inData:(NSData*) data;

- (int) processPreamble:(NSData*) workingData;

@end


//-----------------------------------------------------------------
// implementation MultipartFormDataParser
//-----------------------------------------------------------------


@implementation MultipartFormDataParser 
@synthesize delegate,formEncoding;

- (id) initWithBoundary:(NSString*) boundary formEncoding:(NSStringEncoding) _formEncoding {
    if( nil == (self = [super init]) ){
        return self;
    }
	if( nil == boundary ) {
		HTTPLogWarn(@"MultipartFormDataParser: init with zero boundary");
		return nil;
	}
    boundaryData = [[@"\r\n--" stringByAppendingString:boundary] dataUsingEncoding:NSASCIIStringEncoding];

    pendingData = [[NSMutableData alloc] init];
    currentEncoding = contentTransferEncoding_binary;
	currentHeader = nil;

	formEncoding = _formEncoding;
	reachedEpilogue = NO;
	processedPreamble = NO;

    return self;
}


- (BOOL) appendData:(NSData *)data { 
    // Can't parse without boundary;
    if( nil == boundaryData ) {
		HTTPLogError(@"MultipartFormDataParser: Trying to parse multipart without specifying a valid boundary");
		assert(false);
        return NO;
    }
    NSData* workingData = data;

    if( pendingData.length ) {
        [pendingData appendData:data];
        workingData = pendingData;
    }

	// the parser saves parse stat in the offset variable, which indicates offset of unhandled part in 
	// currently received chunk. Before returning, we always drop all data up to offset, leaving 
	// only unhandled for the next call

    int offset = 0;

	// don't parse data unless its size is greater then boundary length, so we couldn't
	// misfind the boundary, if it got split into different data chunks
	NSUInteger sizeToLeavePending = boundaryData.length;

	if( !reachedEpilogue && workingData.length <= sizeToLeavePending )  {
		// not enough data even to start parsing.
		// save to pending data.
		if( !pendingData.length ) {
			[pendingData appendData:data];
		}
		if( checkForContentEnd ) {
			if(	pendingData.length >= 2 ) {
				if( *(uint16_t*)(pendingData.bytes + offset) == 0x2D2D ) {
					// we found the multipart end. all coming next is an epilogue.
					HTTPLogVerbose(@"MultipartFormDataParser: End of multipart message");
					waitingForCRLF = YES;
					reachedEpilogue = YES;
					offset+= 2;
				}
				else {
					checkForContentEnd = NO;
					waitingForCRLF = YES;
					return YES;
				}
			} else {
				return YES;
			}
			
		}
		else {
			return YES;
		}
	}
	while( true ) {
		if( checkForContentEnd ) {
			// the flag will be raised to check if the last part was the last one.
			if( offset < workingData.length -1 ) {
				char* bytes = (char*) workingData.bytes;
				if( *(uint16_t*)(bytes + offset) == 0x2D2D ) {
					// we found the multipart end. all coming next is an epilogue.
					HTTPLogVerbose(@"MultipartFormDataParser: End of multipart message");
					checkForContentEnd = NO;
					reachedEpilogue = YES;
					// still wait for CRLF, that comes after boundary, but before epilogue.
					waitingForCRLF = YES;
					offset += 2;
				}
				else {
					// it's not content end, we have to wait till separator line end before next part comes
					waitingForCRLF = YES;
					checkForContentEnd = NO;
				}
			}
			else {
				// we haven't got enough data to check for content end.
				// save current unhandled data (it may be 1 byte) to pending and recheck on next chunk received
				if( offset < workingData.length ) {
					[pendingData setData:[NSData dataWithBytes:workingData.bytes + workingData.length-1 length:1]];
				}
				else {
					// there is no unhandled data now, wait for more chunks
					[pendingData setData:[NSData data]];
				}
				return YES;
			}
		}
		if( waitingForCRLF ) {

			// the flag will be raised in the code below, meaning, we've read the boundary, but
			// didnt find the end of boundary line yet.

			offset = [self offsetTillNewlineSinceOffset:offset inData:workingData];
			if( -1 == offset ) {
				// didnt find the endl again.
				if( offset ) {
					// we still have to save the unhandled data (maybe it's 1 byte CR)
					if( *((char*)workingData.bytes + workingData.length -1) == '\r' ) {
						[pendingData setData:[NSData dataWithBytes:workingData.bytes + workingData.length-1 length:1]];
					}
					else {
						// or save nothing if it wasnt 
						[pendingData setData:[NSData data]];
					}
				}
				return YES;
			}
			waitingForCRLF = NO;
		}
		if( !processedPreamble ) {
			// got to find the first boundary before the actual content begins.
			offset = [self processPreamble:workingData];
			// wait for more data for preamble
			if( -1 == offset ) 
				return YES;
			// invoke continue to skip newline after boundary.
			continue;
		}

		if( reachedEpilogue ) {
			// parse all epilogue data to delegate.
			if( [delegate respondsToSelector:@selector(processEpilogueData:)] ) {
				NSData* epilogueData = [NSData dataWithBytesNoCopy: (char*) workingData.bytes + offset length: workingData.length - offset freeWhenDone:NO];
				[delegate processEpilogueData: epilogueData];
			}
			return YES;
		}

		if( nil == currentHeader ) {
			// nil == currentHeader is a state flag, indicating we are waiting for header now.
			// whenever part is over, currentHeader is set to nil.

			// try to find CRLFCRLF bytes in the data, which indicates header end.
			// we won't parse header parts, as they won't be too large.
			int headerEnd = [self findHeaderEnd:workingData fromOffset:offset];
			if( -1 == headerEnd ) {
				// didn't recieve the full header yet.
				if( !pendingData.length) {
					// store the unprocessed data till next chunks come
					[pendingData appendBytes:data.bytes + offset length:data.length - offset];
				}
				else {
					if( offset ) {
						// save the current parse state; drop all handled data and save unhandled only.
						pendingData = [[NSMutableData alloc] initWithBytes: (char*) workingData.bytes + offset length:workingData.length - offset];
					}
				}
				return  YES;
			}
			else {

				// let the header parser do it's job from now on.
				NSData * headerData = [NSData dataWithBytesNoCopy: (char*) workingData.bytes + offset length:headerEnd + 2 - offset freeWhenDone:NO];
				currentHeader = [[MultipartMessageHeader alloc] initWithData:headerData formEncoding:formEncoding];

				if( nil == currentHeader ) {
					// we've found the data is in wrong format.
					HTTPLogError(@"MultipartFormDataParser: MultipartFormDataParser: wrong input format, coulnd't get a valid header");
					return NO;
				}
                if( [delegate respondsToSelector:@selector(processStartOfPartWithHeader:)] ) {
                    [delegate processStartOfPartWithHeader:currentHeader];
                }

				HTTPLogVerbose(@"MultipartFormDataParser: MultipartFormDataParser: Retrieved part header.");
			}
			// skip the two trailing \r\n, in addition to the whole header.
			offset = headerEnd + 4;	
		}
		// after we've got the header, we try to
		// find the boundary in the data.
		int contentEnd = [self findContentEnd:workingData fromOffset:offset];
		
		if( contentEnd == -1 ) {

			// this case, we didn't find the boundary, so the data is related to the current part.
			// we leave the sizeToLeavePending amount of bytes to make sure we don't include 
			// boundary part in processed data.
			NSUInteger sizeToPass = workingData.length - offset - sizeToLeavePending;

			// if we parse BASE64 encoded data, or Quoted-Printable data, we will make sure we don't break the format
			int leaveTrailing = [self numberOfBytesToLeavePendingWithData:data length:sizeToPass encoding:currentEncoding];
			sizeToPass -= leaveTrailing;
			
			if( sizeToPass <= 0 ) {
				// wait for more data!
				if( offset ) {
					[pendingData setData:[NSData dataWithBytes:(char*) workingData.bytes + offset length:workingData.length - offset]];
				}
				return YES;
			}
			// decode the chunk and let the delegate use it (store in a file, for example)
			NSData* decodedData = [MultipartFormDataParser decodedDataFromData:[NSData dataWithBytesNoCopy:(char*)workingData.bytes + offset length:workingData.length - offset - sizeToLeavePending freeWhenDone:NO] encoding:currentEncoding];
			
			if( [delegate respondsToSelector:@selector(processContent:WithHeader:)] ) {
				HTTPLogVerbose(@"MultipartFormDataParser: Processed %"FMTNSINT" bytes of body",sizeToPass);

				[delegate processContent: decodedData WithHeader:currentHeader];
			}

			// store the unprocessed data till the next chunks come.
			[pendingData setData:[NSData dataWithBytes:(char*)workingData.bytes + workingData.length - sizeToLeavePending length:sizeToLeavePending]];
			return YES;
		}
		else {

			// Here we found the boundary.
			// let the delegate process it, and continue going to the next parts.
			if( [delegate respondsToSelector:@selector(processContent:WithHeader:)] ) {
				[delegate processContent:[NSData dataWithBytesNoCopy:(char*) workingData.bytes + offset length:contentEnd - offset freeWhenDone:NO] WithHeader:currentHeader];
			}

			if( [delegate respondsToSelector:@selector(processEndOfPartWithHeader:)] ){
				[delegate processEndOfPartWithHeader:currentHeader];
				HTTPLogVerbose(@"MultipartFormDataParser: End of body part");
			}
			currentHeader = nil;

			// set up offset to continue with the remaining data (if any)
            // cast to int because above comment suggests a small number
			offset = contentEnd + (int)boundaryData.length;
			checkForContentEnd = YES;
			// setting the flag tells the parser to skip all the data till CRLF
		}
	}
    return YES;
}


//-----------------------------------------------------------------
#pragma mark private methods

- (int) offsetTillNewlineSinceOffset:(int) offset inData:(NSData*) data {
	char* bytes = (char*) data.bytes;
	NSUInteger length = data.length;
	if( offset >= length - 1 ) 
		return -1;

	while ( *(uint16_t*)(bytes + offset) != 0x0A0D ) {
		// find the trailing \r\n after the boundary. The boundary line might have any number of whitespaces before CRLF, according to rfc2046

		// in debug, we might also want to know, if the file is somehow misformatted.
#ifdef DEBUG
		if( !isspace(*(bytes+offset)) ) {
			HTTPLogWarn(@"MultipartFormDataParser: Warning, non-whitespace character '%c' between boundary bytes and CRLF in boundary line",*(bytes+offset) );
		}
		if( !isspace(*(bytes+offset+1)) ) {
			HTTPLogWarn(@"MultipartFormDataParser: Warning, non-whitespace character '%c' between boundary bytes and CRLF in boundary line",*(bytes+offset+1) );
		}
#endif
		offset++;
		if( offset >= length ) {
			// no endl found within current data
			return -1;
		}
	}

	offset += 2;
	return offset;
}


- (int) processPreamble:(NSData*) data {
	int offset = 0;
	
	char* boundaryBytes = (char*) boundaryData.bytes + 2; // the first boundary won't have CRLF preceding.
    char* dataBytes = (char*) data.bytes;
    NSUInteger boundaryLength = boundaryData.length - 2;
    NSUInteger dataLength = data.length;
    
	// find the boundary without leading CRLF.
    while( offset < dataLength - boundaryLength +1 ) {
        int i;
        for( i = 0;i < boundaryLength; i++ ) {
            if( boundaryBytes[i] != dataBytes[offset + i] )
                break;
        }
        if( i == boundaryLength ) {
            break;
        }
		offset++;
    }
 	
	if( offset == dataLength ) {
		// the end of preamble wasn't found in this chunk
		NSUInteger sizeToProcess = dataLength - boundaryLength;
		if( sizeToProcess > 0) {
			if( [delegate respondsToSelector:@selector(processPreambleData:)] ) {
				NSData* preambleData = [NSData dataWithBytesNoCopy: (char*) data.bytes length: data.length - offset - boundaryLength freeWhenDone:NO];
				[delegate processPreambleData:preambleData];
				HTTPLogVerbose(@"MultipartFormDataParser: processed preamble");
			}
			pendingData = [NSMutableData dataWithBytes: data.bytes + data.length - boundaryLength length:boundaryLength];
		}
		return -1;
	}
	else {
		if ( offset && [delegate respondsToSelector:@selector(processPreambleData:)] ) {
			NSData* preambleData = [NSData dataWithBytesNoCopy: (char*) data.bytes length: offset freeWhenDone:NO];
			[delegate processPreambleData:preambleData];
		}
		offset +=boundaryLength;
		// tells to skip CRLF after the boundary.
		processedPreamble = YES;
		waitingForCRLF = YES;
	}
	return offset;
}



- (int) findHeaderEnd:(NSData*) workingData fromOffset:(int)offset {
    char* bytes = (char*) workingData.bytes; 
    NSUInteger inputLength = workingData.length;
    uint16_t separatorBytes = 0x0A0D;

	while( true ) {
		if(inputLength < offset + 3 ) {
			// wait for more data
			return -1;
		}
        if( (*((uint16_t*) (bytes+offset)) == separatorBytes) && (*((uint16_t*) (bytes+offset)+1) == separatorBytes) ) {
			return offset;
        }
        offset++;
    }
    return -1;
}


- (int) findContentEnd:(NSData*) data fromOffset:(int) offset {
    char* boundaryBytes = (char*) boundaryData.bytes;
    char* dataBytes = (char*) data.bytes;
    NSUInteger boundaryLength = boundaryData.length;
    NSUInteger dataLength = data.length;
    
    while( offset < dataLength - boundaryLength +1 ) {
        int i;
        for( i = 0;i < boundaryLength; i++ ) {
            if( boundaryBytes[i] != dataBytes[offset + i] )
                break;
        }
        if( i == boundaryLength ) {
            return offset;
        }
		offset++;
    }
    return -1;
}


- (int) numberOfBytesToLeavePendingWithData:(NSData*) data length:(int) length encoding:(int) encoding {
	// If we have BASE64 or Quoted-Printable encoded data, we have to be sure
	// we don't break the format.
	int sizeToLeavePending = 0;
	
	if( encoding == contentTransferEncoding_base64 ) {	
		char* bytes = (char*) data.bytes;
		int i;
		for( i = length - 1; i > 0; i++ ) {
			if( * (uint16_t*) (bytes + i) == 0x0A0D ) {
				break;
			}
		}
		// now we've got to be sure that the length of passed data since last line
		// is multiplier of 4.
		sizeToLeavePending = (length - i) & ~0x11; // size to leave pending = length-i - (length-i) %4;
		return sizeToLeavePending;
	}
	
	if( encoding == contentTransferEncoding_quotedPrintable ) {
		// we don't pass more less then 3 bytes anyway.
		if( length <= 2 ) 
			return length;
		// check the last bytes to be start of encoded symbol.
		const char* bytes = data.bytes + length - 2;
		if( bytes[0] == '=' )
			return 2;
		if( bytes[1] == '=' )
			return 1;
		return 0;
	}
	return 0;
}


//-----------------------------------------------------------------
#pragma mark decoding


+ (NSData*) decodedDataFromData:(NSData*) data encoding:(int) encoding {
	switch (encoding) {
		case contentTransferEncoding_base64: {
			return [data base64Decoded]; 
		} break;

		case contentTransferEncoding_quotedPrintable: {
			return [self decodedDataFromQuotedPrintableData:data];
		} break;

		default: {
			return data;
		} break;
	}
}


+ (NSData*) decodedDataFromQuotedPrintableData:(NSData *)data {
//	http://tools.ietf.org/html/rfc2045#section-6.7

	const char hex []  = { '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F', };

	NSMutableData* result = [[NSMutableData alloc] initWithLength:data.length];
	const char* bytes = (const char*) data.bytes;
	int count = 0;
	NSUInteger length = data.length;
	while( count < length ) {
		if( bytes[count] == '=' ) {
			[result appendBytes:bytes length:count];
			bytes = bytes + count + 1;
			length -= count + 1;
			count = 0;

			if( length < 3 ) {
				HTTPLogWarn(@"MultipartFormDataParser: warning, trailing '=' in quoted printable data");
			}
			// soft newline
			if( bytes[0] == '\r' ) {
				bytes += 1;
				if(bytes[1] == '\n' ) {
					bytes += 2;
				}
				continue;
			}
			char encodedByte = 0;

			for( int i = 0; i < sizeof(hex); i++ ) {
				if( hex[i] == bytes[0] ) {
					encodedByte += i << 4;
				}
				if( hex[i] == bytes[1] ) {
					encodedByte += i;
				}
			}
			[result appendBytes:&encodedByte length:1];
			bytes += 2;
		}

#ifdef DEBUG
		if( (unsigned char) bytes[count] > 126 ) {
			HTTPLogWarn(@"MultipartFormDataParser: Warning, character with code above 126 appears in quoted printable encoded data");
		}
#endif
		
		count++;
	}
	return result;
}


@end
