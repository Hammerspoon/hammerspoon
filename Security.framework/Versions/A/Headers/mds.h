/*
 * Copyright (c) 2000-2001,2011,2014 Apple Inc. All Rights Reserved.
 * 
 * The contents of this file constitute Original Code as defined in and are
 * subject to the Apple Public Source License Version 1.2 (the 'License').
 * You may not use this file except in compliance with the License. Please obtain
 * a copy of the License at http://www.apple.com/publicsource and read it before
 * using this file.
 * 
 * This Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESS
 * OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES, INCLUDING WITHOUT
 * LIMITATION, ANY WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
 * PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT. Please see the License for the
 * specific language governing rights and limitations under the License.
 */


/*
   File:      mds.h

   Contains:  Module Directory Services Data Types and API.

   Copyright (c) 1999-2000,2011,2014 Apple Inc. All Rights Reserved.
*/

#ifndef _MDS_H_
#define _MDS_H_  1

#include <Security/cssmtype.h>

#ifdef __cplusplus
extern "C" {
#endif

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

typedef CSSM_DL_HANDLE MDS_HANDLE;

typedef CSSM_DL_DB_HANDLE MDS_DB_HANDLE;

typedef struct mds_funcs {
    CSSM_RETURN (CSSMAPI *DbOpen)
        (MDS_HANDLE MdsHandle,
         const char *DbName,
         const CSSM_NET_ADDRESS *DbLocation,
         CSSM_DB_ACCESS_TYPE AccessRequest,
         const CSSM_ACCESS_CREDENTIALS *AccessCred,
         const void *OpenParameters,
         CSSM_DB_HANDLE *hMds);

    CSSM_RETURN (CSSMAPI *DbClose)
        (MDS_DB_HANDLE MdsDbHandle);

    CSSM_RETURN (CSSMAPI *GetDbNames)
        (MDS_HANDLE MdsHandle,
         CSSM_NAME_LIST_PTR *NameList);

    CSSM_RETURN (CSSMAPI *GetDbNameFromHandle)
        (MDS_DB_HANDLE MdsDbHandle,
         char **DbName);

    CSSM_RETURN (CSSMAPI *FreeNameList)
        (MDS_HANDLE MdsHandle,
         CSSM_NAME_LIST_PTR NameList);

    CSSM_RETURN (CSSMAPI *DataInsert)
        (MDS_DB_HANDLE MdsDbHandle,
         CSSM_DB_RECORDTYPE RecordType,
         const CSSM_DB_RECORD_ATTRIBUTE_DATA *Attributes,
         const CSSM_DATA *Data,
         CSSM_DB_UNIQUE_RECORD_PTR *UniqueId);

    CSSM_RETURN (CSSMAPI *DataDelete)
        (MDS_DB_HANDLE MdsDbHandle,
         const CSSM_DB_UNIQUE_RECORD *UniqueRecordIdentifier);

    CSSM_RETURN (CSSMAPI *DataModify)
        (MDS_DB_HANDLE MdsDbHandle,
         CSSM_DB_RECORDTYPE RecordType,
         CSSM_DB_UNIQUE_RECORD_PTR UniqueRecordIdentifier,
         const CSSM_DB_RECORD_ATTRIBUTE_DATA *AttributesToBeModified,
         const CSSM_DATA *DataToBeModified,
         CSSM_DB_MODIFY_MODE ModifyMode);

    CSSM_RETURN (CSSMAPI *DataGetFirst)
        (MDS_DB_HANDLE MdsDbHandle,
         const CSSM_QUERY *Query,
         CSSM_HANDLE_PTR ResultsHandle,
         CSSM_DB_RECORD_ATTRIBUTE_DATA_PTR Attributes,
         CSSM_DATA_PTR Data,
         CSSM_DB_UNIQUE_RECORD_PTR *UniqueId);

    CSSM_RETURN (CSSMAPI *DataGetNext)
        (MDS_DB_HANDLE MdsDbHandle,
         CSSM_HANDLE ResultsHandle,
         CSSM_DB_RECORD_ATTRIBUTE_DATA_PTR Attributes,
         CSSM_DATA_PTR Data,
         CSSM_DB_UNIQUE_RECORD_PTR *UniqueId);

    CSSM_RETURN (CSSMAPI *DataAbortQuery)
        (MDS_DB_HANDLE MdsDbHandle,
         CSSM_HANDLE ResultsHandle);

    CSSM_RETURN (CSSMAPI *DataGetFromUniqueRecordId)
        (MDS_DB_HANDLE MdsDbHandle,
         const CSSM_DB_UNIQUE_RECORD *UniqueRecord,
         CSSM_DB_RECORD_ATTRIBUTE_DATA_PTR Attributes,
         CSSM_DATA_PTR Data);

    CSSM_RETURN (CSSMAPI *FreeUniqueRecord)
        (MDS_DB_HANDLE MdsDbHandle,
         CSSM_DB_UNIQUE_RECORD_PTR UniqueRecord);

    CSSM_RETURN (CSSMAPI *CreateRelation)
        (MDS_DB_HANDLE MdsDbHandle,
         CSSM_DB_RECORDTYPE RelationID,
         const char *RelationName,
         uint32 NumberOfAttributes,
         const CSSM_DB_SCHEMA_ATTRIBUTE_INFO *pAttributeInfo,
         uint32 NumberOfIndexes,
         const CSSM_DB_SCHEMA_INDEX_INFO *pIndexInfo);

    CSSM_RETURN (CSSMAPI *DestroyRelation)
        (MDS_DB_HANDLE MdsDbHandle,
         CSSM_DB_RECORDTYPE RelationID);
} MDS_FUNCS DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER, *MDS_FUNCS_PTR DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;


/* MDS Context APIs */

CSSM_RETURN CSSMAPI
MDS_Initialize (const CSSM_GUID *pCallerGuid,
                const CSSM_MEMORY_FUNCS *pMemoryFunctions,
                MDS_FUNCS_PTR pDlFunctions,
                MDS_HANDLE *hMds)
				DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

CSSM_RETURN CSSMAPI
MDS_Terminate (MDS_HANDLE MdsHandle)
	DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

CSSM_RETURN CSSMAPI
MDS_Install (MDS_HANDLE MdsHandle)
	DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

CSSM_RETURN CSSMAPI
MDS_Uninstall (MDS_HANDLE MdsHandle)
	DEPRECATED_IN_MAC_OS_X_VERSION_10_7_AND_LATER;

#pragma clang diagnostic pop

#ifdef __cplusplus
}
#endif

#endif /* _MDS_H_ */
