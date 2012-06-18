/**
 * @file   apr_log.h
 * @author Nat Goodspeed
 * @date   2012-06-15
 * @brief  Declarations for apr_log() and friends
 * 
 * $LicenseInfo:firstyear=2012&license=internal$
 * Copyright (c) 2012, Linden Research, Inc.
 * $/LicenseInfo$
 */

#if ! defined(APR_LOG_H)
#define APR_LOG_H

/*
 * apr_log() is like printf() to an implicit log file.
 * It's sensitive to APR_LOG environment variable:
 * - Not set: don't log (default). This state is cached for fast exit.
 * - Absolute pathname: append to specified log file.
 * - Relative pathname: prefix with (e.g.) "c:/Users/You/AppData/Roaming".
 *   That means that if you set APR_LOG="SecondLife/logs/apr.log", it should
 *   end up in the same directory as SecondLife.log.
 * Various errors cause apr_log() to silently fail -- if it's not working,
 * it's got nowhere to complain!
 */
void apr_log(const char* format, ...);
/* Return %s suitable for logging a const char* that might be NULL */
const char* apr_logstr(const char* str);
const wchar_t* apr_logwstr(const wchar_t* str);

#endif /* ! defined(APR_LOG_H) */
