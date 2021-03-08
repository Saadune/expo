// Copyright 2021-present 650 Industries. All rights reserved.

#import <sqlite3.h>

NS_ASSUME_NONNULL_BEGIN

@interface EXUpdatesDatabaseUtils : NSObject

+ (nullable NSArray<NSDictionary *> *)executeSql:(NSString *)sql
                                        withArgs:(nullable NSArray *)args
                                      onDatabase:(struct sqlite3 *)db
                                           error:(NSError ** _Nullable)error;

+ (NSError *)errorFromSqlite:(struct sqlite3 *)db;

@end

NS_ASSUME_NONNULL_END
