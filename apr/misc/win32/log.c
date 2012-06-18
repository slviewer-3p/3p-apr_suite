/**
 * @file   log.c
 * @author Nat Goodspeed
 * @date   2012-06-15
 * @brief  Add Windows-specific apr_log() function
 *
 * I attempted to add this to misc.c, but APR internal headers are a mess --
 * it proved impossible to add the requisite Microsoft headers without
 * breaking things. I tried various orders for the #includes, which changed
 * the errors without resolving them.  :-P
 * 
 * $LicenseInfo:firstyear=2012&license=internal$
 * Copyright (c) 2012, Linden Research, Inc.
 * $/LicenseInfo$
 */

#include <Shlobj.h>
#include <varargs.h>
#include <stdio.h>
#include "apr_time.h"
#include "apr_file_info.h"

FILE* apr_open_log();

/* I'm amazed that APR doesn't already have GENERAL-PURPOSE logging
 * infrastructure.
 * Microsoft's vfprintf() accepts "%ws" or "%ls" (lowercase L) to mean a
 * wchar_t* string. */
void apr_log(const char* format, ...)
{
    /* We could store only a static FILE*, but we must distinguish three cases:
       - first call, try to open log file
       - log file successfully opened
       - open attempt failed, don't bother continually trying to reopen.
       Hence a separate 'first' flag. No-log behavior should exit quickly so
       we won't be shy about sprinkling apr_log() calls through the code. */
    static int first = 1;
    static FILE* logf = NULL;

    if (first)
    {
        char date[APR_CTIME_LEN];
        apr_ctime(date, apr_time_now());
        first = 0;
        /* Break out apr_open_log() as a separate function because some day we
           hope to migrate apr_log() to platform-independent source -- but
           apr_open_log() contains platform-dependent logic. */
        logf = apr_open_log();
        /* beware, open might fail for any of a number of reasons */
        if (logf)
        {
            fputs("========================================================================\n",
                  logf);
            fputs(date, logf);
            fputs("\n", logf);
        }
    }
    if (logf)
    {
        va_list ap;
        va_start(ap, format);
        vfprintf(logf, format, ap);
        va_end(ap);
        fputs("\n", logf);
        /* Flush but leave open for next call. If fflush() is working right,
           we shouldn't actually need to close the file to get all its output. */
        fflush(logf);
    }
}

/* apr_open_log() should only be called once per process, so we can perform nontrivial
   operations as needed. It's sensitive to APR_LOG environment variable:
   - Not set: don't log (default).
   - Absolute pathname: append to specified log file.
   - Relative pathname: prefix with (e.g.) "c:/Users/You/AppData/Roaming".
     That means that if you set APR_LOG="SecondLife/logs/apr.log", it should
     end up in the same directory as SecondLife.log.
*/
FILE* apr_open_log()
{
    apr_status_t status = APR_SUCCESS;
    apr_pool_t* pool = NULL;
    FILE* logf = NULL;
    char* APR_LOG = getenv("APR_LOG");
    char* APR_LOG_root = APR_LOG;
    char* APR_LOG_rel  = APR_LOG;
    /* If APR_LOG isn't even set, don't bother with any of the rest of this. */
    if (! APR_LOG)
        return NULL;

    /* For pathname manipulation, have to get an APR pool. Create and destroy
       it locally; don't require caller to pass it in. */
    if (apr_pool_create(&pool, NULL) != APR_SUCCESS)
        return NULL;

    /* Now that pool exists, don't just 'return NULL;' below this point we
       must 'goto cleanup' instead to destroy the pool. */

    /* Is APR_LOG absolute or relative? */
    status = apr_filepath_root(&APR_LOG_root, &APR_LOG_rel, 0, pool);
    /* Skip garbage path. This test is based on code in apr_filepath_merge().
       APR_SUCCESS means it's an absolute path; APR_ERELATIVE is obvious;
       APR_EINCOMPLETE means it starts with slash, which on Windows is an
       incomplete path because it doesn't specify the drive letter. Anything
       else means apr_filepath_root() was confused by this pathname. */
    if (! (status == APR_SUCCESS || status == APR_ERELATIVE || status == APR_EINCOMPLETE))
        goto cleanup;
        
    /* If it's a relative pathname, place it within AppData. */
    if (status == APR_ERELATIVE || status == APR_EINCOMPLETE)
    {
        char appdir[MAX_PATH];
        char* abspath = NULL;
        /* If we can't get the special folder pathname, give up. */
        if (S_OK != SHGetFolderPathA(NULL, CSIDL_APPDATA, NULL, 0, appdir))
            goto cleanup;

        /* If we can't append APR_LOG to appdir, give up. */
        if (APR_SUCCESS != apr_filepath_merge(&abspath, appdir, APR_LOG, 0, pool))
            goto cleanup;

        /* Okay, replace APR_LOG with abspath. */
        APR_LOG = abspath;
    }

    /* Try to open the file. */
    logf = fopen(APR_LOG, "a");

cleanup:
    apr_pool_destroy(pool);         /* clean up local temp pool */
    return logf;
}

/* Return %s suitable for logging a const char* that might be NULL */
const char* apr_logstr(const char* str)
{
    if (! str)
        return "NULL";
    return str;
}

const wchar_t* apr_logwstr(const wchar_t* str)
{
    if (! str)
        return L"NULL";
    return str;
}
