// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/fourier/license.volt (BOOST ver. 1.0).
module lib.clang.error;

public import lib.clang.c.CXErrorCode;


alias CXError_Success          = CXErrorCode.CXError_Success;
alias CXError_Failure          = CXErrorCode.CXError_Failure;
alias CXError_Crashed          = CXErrorCode.CXError_Crashed;
alias CXError_InvalidArguments = CXErrorCode.CXError_InvalidArguments;
alias CXError_ASTReadError     = CXErrorCode.CXError_ASTReadError;
