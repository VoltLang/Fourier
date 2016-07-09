// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/fourier/license.volt (BOOST ver. 1.0).
module lib.clang.database;

public import lib.clang.c.CXCompilationDatabase;


alias CXCompilationDatabase_NoError = CXCompilationDatabase_Error.CXCompilationDatabase_NoError;
alias CXCompilationDatabase_CanNotLoadDatabase = CXCompilationDatabase_Error.CXCompilationDatabase_CanNotLoadDatabase;
