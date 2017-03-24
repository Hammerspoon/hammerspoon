/*
 * Copyright (c) 1999-2001,2004,2011,2014 Apple Inc. All Rights Reserved.
 * 
 * @APPLE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 *
 * cssmdli.h -- Service Provider Interface for Data Store Modules
 */

#ifndef _CSSMDLI_H_
#define _CSSMDLI_H_  1

#include <Security/cssmtype.h>

#ifdef __cplusplus
extern "C" {
#endif

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

typedef struct cssm_spi_dl_funcs {
    CSSM_RETURN (CSSMDLI *DbOpen)
        (CSSM_DL_HANDLE DLHandle,
         const char *DbName,
         const CSSM_NET_ADDRESS *DbLocation,
         CSSM_DB_ACCESS_TYPE AccessRequest,
         const CSSM_ACCESS_CREDENTIALS *AccessCred,
         const void *OpenParameters,
         CSSM_DB_HANDLE *DbHandle);
    CSSM_RETURN (CSSMDLI *DbClose)
        (CSSM_DL_DB_HANDLE DLDBHandle);
    CSSM_RETURN (CSSMDLI *DbCreate)
        (CSSM_DL_HANDLE DLHandle,
         const char *DbName,
         const CSSM_NET_ADDRESS *DbLocation,
         const CSSM_DBINFO *DBInfo,
         CSSM_DB_ACCESS_TYPE AccessRequest,
         const CSSM_RESOURCE_CONTROL_CONTEXT *CredAndAclEntry,
         const void *OpenParameters,
         CSSM_DB_HANDLE *DbHandle);
    CSSM_RETURN (CSSMDLI *DbDelete)
        (CSSM_DL_HANDLE DLHandle,
         const char *DbName,
         const CSSM_NET_ADDRESS *DbLocation,
         const CSSM_ACCESS_CREDENTIALS *AccessCred);
    CSSM_RETURN (CSSMDLI *CreateRelation)
        (CSSM_DL_DB_HANDLE DLDBHandle,
         CSSM_DB_RECORDTYPE RelationID,
         const char *RelationName,
         uint32 NumberOfAttributes,
         const CSSM_DB_SCHEMA_ATTRIBUTE_INFO *pAttributeInfo,
         uint32 NumberOfIndexes,
         const CSSM_DB_SCHEMA_INDEX_INFO *pIndexInfo);
    CSSM_RETURN (CSSMDLI *DestroyRelation)
        (CSSM_DL_DB_HANDLE DLDBHandle,
         CSSM_DB_RECORDTYPE RelationID);
    CSSM_RETURN (CSSMDLI *Authenticate)
        (CSSM_DL_DB_HANDLE DLDBHandle,
         CSSM_DB_ACCESS_TYPE AccessRequest,
         const CSSM_ACCESS_CREDENTIALS *AccessCred);
    CSSM_RETURN (CSSMDLI *GetDbAcl)
        (CSSM_DL_DB_HANDLE DLDBHandle,
         const CSSM_STRING *SelectionTag,
         uint32 *NumberOfAclInfos,
         CSSM_ACL_ENTRY_INFO_PTR *AclInfos);
    CSSM_RETURN (CSSMDLI *ChangeDbAcl)
        (CSSM_DL_DB_HANDLE DLDBHandle,
         const CSSM_ACCESS_CREDENTIALS *AccessCred,
         const CSSM_ACL_EDIT *AclEdit);
    CSSM_RETURN (CSSMDLI *GetDbOwner)
        (CSSM_DL_DB_HANDLE DLDBHandle,
         CSSM_ACL_OWNER_PROTOTYPE_PTR Owner);
    CSSM_RETURN (CSSMDLI *ChangeDbOwner)
        (CSSM_DL_DB_HANDLE DLDBHandle,
         const CSSM_ACCESS_CREDENTIALS *AccessCred,
         const CSSM_ACL_OWNER_PROTOTYPE *NewOwner);
    CSSM_RETURN (CSSMDLI *GetDbNames)
        (CSSM_DL_HANDLE DLHandle,
         CSSM_NAME_LIST_PTR *NameList);
    CSSM_RETURN (CSSMDLI *GetDbNameFromHandle)
        (CSSM_DL_DB_HANDLE DLDBHandle,
         char **DbName);
    CSSM_RETURN (CSSMDLI *FreeNameList)
        (CSSM_DL_HANDLE DLHandle,
         CSSM_NAME_LIST_PTR NameList);
    CSSM_RETURN (CSSMDLI *DataInsert)
        (CSSM_DL_DB_HANDLE DLDBHandle,
         CSSM_DB_RECORDTYPE RecordType,
         const CSSM_DB_RECORD_ATTRIBUTE_DATA *Attributes,
         const CSSM_DATA *Data,
         CSSM_DB_UNIQUE_RECORD_PTR *UniqueId);
    CSSM_RETURN (CSSMDLI *DataDelete)
        (CSSM_DL_DB_HANDLE DLDBHandle,
         const CSSM_DB_UNIQUE_RECORD *UniqueRecordIdentifier);
    CSSM_RETURN (CSSMDLI *DataModify)
        (CSSM_DL_DB_HANDLE DLDBHandle,
         CSSM_DB_RECORDTYPE RecordType,
         CSSM_DB_UNIQUE_RECORD_PTR UniqueRecordIdentifier,
         const CSSM_DB_RECORD_ATTRIBUTE_DATA *AttributesToBeModified,
         const CSSM_DATA *DataToBeModified,
         CSSM_DB_MODIFY_MODE ModifyMode);
    CSSM_RETURN (CSSMDLI *DataGetFirst)
        (CSSM_DL_DB_HANDLE DLDBHandle,
         const CSSM_QUERY *Query,
         CSSM_HANDLE_PTR ResultsHandle,
         CSSM_DB_RECORD_ATTRIBUTE_DATA_PTR Attributes,
         CSSM_DATA_PTR Data,
         CSSM_DB_UNIQUE_RECORD_PTR *UniqueId);
    CSSM_RETURN (CSSMDLI *DataGetNext)
        (CSSM_DL_DB_HANDLE DLDBHandle,
         CSSM_HANDLE ResultsHandle,
         CSSM_DB_RECORD_ATTRIBUTE_DATA_PTR Attributes,
         CSSM_DATA_PTR Data,
         CSSM_DB_UNIQUE_RECORD_PTR *UniqueId);
    CSSM_RETURN (CSSMDLI *DataAbortQuery)
        (CSSM_DL_DB_HANDLE DLDBHandle,
         CSSM_HANDLE ResultsHandle);
    CSSM_RETURN (CSSMDLI *DataGetFromUniqueRecordId)
        (CSSM_DL_DB_HANDLE DLDBHandle,
         const CSSM_DB_UNIQUE_RECORD *UniqueRecord,
         CSSM_DB_RECORD_ATTRIBUTE_DATA_PTR Attributes,
         CSSM_DATA_PTR Data);
    CSSM_RETURN (CSSMDLI *FreeUniqueRecord)
        (CSSM_DL_DB_HANDLE DLDBHandle,
         CSSM_DB_UNIQUE_RECORD_PTR UniqueRecord);
    CSSM_RETURN (CSSMDLI *PassThrough)
        (CSSM_DL_DB_HANDLE DLDBHandle,
         uint32 PassThroughId,
         const void *InputParams,
         void **OutputParams);
} CSSM_SPI_DL_FUNCS DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER, *CSSM_SPI_DL_FUNCS_PTR DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

#pragma clang diagnostic pop

#ifdef __cplusplus
}
#endif

#endif /* _CSSMDLI_H_ */
