//
//  ZYSQLite3.m
//  FTMobileAgent
//
//  Created by 胡蕾蕾 on 2019/12/2.
//  Copyright © 2019 hll. All rights reserved.
//

#import "FTTrackerEventDBTool.h"
#import "ZY_FMDB.h"
#import "FTRecordModel.h"
#import "FTLog.h"
@interface FTTrackerEventDBTool ()
@property (nonatomic, strong) NSString *dbPath;
@property (nonatomic, strong) ZY_FMDatabaseQueue *dbQueue;
@property (nonatomic, strong) ZY_FMDatabase *db;
@property (nonatomic, strong) NSMutableArray<FTRecordModel *> *messageCaches;

@end
@implementation FTTrackerEventDBTool{
    dispatch_semaphore_t _lock;
}
static FTTrackerEventDBTool *dbTool = nil;
static dispatch_once_t onceToken;

#pragma mark --创建数据库
+ (instancetype)sharedManger
{
    return [FTTrackerEventDBTool shareDatabase:nil];
}
+ (instancetype)shareDatabase:(NSString *)dbName {
    dispatch_once(&onceToken, ^{
    if (!dbTool) {
        NSString *name = dbName;
        if (!name) {
            name = @"ZYFMDB.sqlite";
        }
        NSString  *path = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:name];
        ZY_FMDatabaseQueue *dbQueue = [ZY_FMDatabaseQueue databaseQueueWithPath:path];
        ZY_FMDatabase *fmdb = [dbQueue valueForKey:@"_db"];
        if ([fmdb  open]) {
            dbTool = FTTrackerEventDBTool.new;
            dbTool.db = fmdb;
            dbTool.dbPath = path;
            ZYDebug(@"db path:%@",path);
            dbTool.dbQueue = dbQueue;
            dbTool->_lock = dispatch_semaphore_create(1);
        }
        [dbTool createTable];
     }
    });
    if (![dbTool.db open]) {
        ZYDebug(@"database can not open !");
        return nil;
    };
    return dbTool;
}
- (void)createTable{
    @try {
        [self createEventTable];
    } @catch (NSException *exception) {
        ZYDebug(@"%@",exception);
    }
}
-(void)createEventTable
{
    if ([self zy_isExistTable:FT_DB_TRACREVENT_TABLE_NAME]) {
        return;
    }
      [self zy_inTransaction:^(BOOL *rollback) {
        NSDictionary *keyTypes = @{@"_id":@"INTEGER",
                                   @"tm":@"INTEGER",
                                   @"data":@"TEXT",
                                   @"op":@"TEXT",
        };
        if ([self isOpenDatabese:self.db]) {
               NSMutableString *sql = [[NSMutableString alloc] initWithString:[NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (",FT_DB_TRACREVENT_TABLE_NAME]];
               int count = 0;
               for (NSString *key in keyTypes) {
                   count++;
                   [sql appendString:key];
                   [sql appendString:@" "];
                   [sql appendString:[keyTypes valueForKey:key]];
                   if ([key isEqualToString:@"_id"]) {
                       [sql appendString:@" primary key AUTOINCREMENT"];
                   }
                   if (count != [keyTypes count]) {
                        [sql appendString:@", "];
                   }
               }
               [sql appendString:@")"];
               ZYDebug(@"%@", sql);
             BOOL success =[self.db executeUpdate:sql];
            ZYDebug(@"createTable success == %d",success);
           }
    }];
}

-(BOOL)insertItem:(FTRecordModel *)item{
    __block BOOL success = NO;
   if([self isOpenDatabese:self.db]) {
       [self zy_inDatabase:^{
           NSString *sqlStr = [NSString stringWithFormat:@"INSERT INTO '%@' ( 'tm' , 'data' ,'op') VALUES (  ? , ? , ? );",FT_DB_TRACREVENT_TABLE_NAME];
          success=  [self.db executeUpdate:sqlStr,@(item.tm),item.data,item.op];
           ZYDebug(@"data storage success == %d",success);
       }];
   }
    return success;
}
-(void)insertLoggingItems:(FTRecordModel *)item{
    if (!item) {
        return;
    }
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    [self.messageCaches addObject:item];
    if (self.messageCaches.count>=20) {
        NSArray *array = self.messageCaches.copy;
        [self.messageCaches removeAllObjects];
        dispatch_semaphore_signal(_lock);
        NSInteger count = self.dbLoggingMaxCount - [[FTTrackerEventDBTool sharedManger] getDatasCountWithOp:FT_DATA_TYPE_LOGGING]-array.count;
        
        if(count < 0){
            if(!self.discardNew){
                [[FTTrackerEventDBTool sharedManger] deleteLoggingItem:-count];
            }else{
                if (count+array.count>0) {
                    array =  [array subarrayWithRange:NSMakeRange(0, count+array.count)];
                }else{
                    return;
                }
            }
        }
        [self insertItemsWithDatas:array];

    }else{
        dispatch_semaphore_signal(_lock);
    }
}
-(BOOL)insertItemsWithDatas:(NSArray<FTRecordModel*> *)items{
    __block BOOL needRoolback = NO;
    if([self isOpenDatabese:self.db]) {
        [self zy_inTransaction:^(BOOL *rollback) {
            [items enumerateObjectsUsingBlock:^(FTRecordModel *item, NSUInteger idx, BOOL * _Nonnull stop) {
                NSString *sqlStr = [NSString stringWithFormat:@"INSERT INTO '%@' ( 'tm' , 'data','op') VALUES (  ? , ? , ? );",FT_DB_TRACREVENT_TABLE_NAME];
                if(![self.db executeUpdate:sqlStr,@(item.tm),item.data,item.op]){
                    *stop = YES;
                    needRoolback = YES;
                }
            }];
            rollback = &needRoolback;
        }];
        
    }
    return !needRoolback;
}
-(void)insertCacheToDB{
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    if (self.messageCaches.count > 0) {
        NSArray *array = [self.messageCaches copy];
        self.messageCaches = nil;
        dispatch_semaphore_signal(_lock);
        [self insertItemsWithDatas:array];
    }else{
        dispatch_semaphore_signal(_lock);
    }
}
-(NSArray *)getAllDatas{
    NSString* sql = [NSString stringWithFormat:@"SELECT * FROM '%@' ORDER BY tm ASC  ;",FT_DB_TRACREVENT_TABLE_NAME];

    return [self getDatasWithFormat:sql];

}

-(NSArray *)getFirstRecords:(NSUInteger)recordSize withType:(NSString *)type{
    if (recordSize == 0) {
        return @[];
    }
    NSString* sql = [NSString stringWithFormat:@"SELECT * FROM '%@' WHERE op = '%@' ORDER BY tm ASC limit %lu  ;",FT_DB_TRACREVENT_TABLE_NAME,type,(unsigned long)recordSize];

    return [self getDatasWithFormat:sql];
}

-(NSArray *)getDatasWithFormat:(NSString *)format{
    if([self isOpenDatabese:self.db]) {
        __block  NSMutableArray *array = [NSMutableArray new];
        [self zy_inDatabase:^{
            //ORDER BY ID DESC --根据ID降序查找:ORDER BY ID ASC --根据ID升序序查找
            ZY_FMResultSet*set = [self.db executeQuery:format];
            while(set.next) {
                //创建对象赋值
                FTRecordModel* item = [[FTRecordModel alloc]init];
                item.tm = [set longForColumn:@"tm"];
                item.data= [set stringForColumn:@"data"];
                item.op = [set stringForColumn:@"op"];
                [array addObject:item];
            }
        }];
        return array;
    }else{
        return nil;
    }
}
- (NSInteger)getDatasCount
{
    __block NSInteger count =0;
    [self zy_inDatabase:^{
        NSString *sqlstr = [NSString stringWithFormat:@"SELECT count(*) as 'count' FROM %@", FT_DB_TRACREVENT_TABLE_NAME];
          ZY_FMResultSet *set = [self.db executeQuery:sqlstr];

          while ([set next]) {
              count= [set intForColumn:@"count"];
          }

    }];
     return count;
}
- (NSInteger)getDatasCountWithOp:(NSString *)op{
    __block NSInteger count =0;
       [self zy_inDatabase:^{
           NSString *sqlstr = [NSString stringWithFormat:@"SELECT count(*) as 'count' FROM %@ WHERE op = '%@'", FT_DB_TRACREVENT_TABLE_NAME,op];
             ZY_FMResultSet *set = [self.db executeQuery:sqlstr];

             while ([set next]) {
                 count= [set intForColumn:@"count"];
             }

       }];
        return count;
    
}
-(BOOL)deleteItemWithType:(NSString *)type tm:(long long)tm{
    __block BOOL is;
       [self zy_inDatabase:^{
           NSString *sqlStr = [NSString stringWithFormat:@"DELETE FROM '%@' WHERE op = '%@' AND tm <= %lld ;",FT_DB_TRACREVENT_TABLE_NAME,type,tm];
           is = [self.db executeUpdate:sqlStr];
       }];
       return is;
}
-(BOOL)deleteLoggingItem:(NSInteger)count{
    __block BOOL is;
        [self zy_inDatabase:^{
            NSString *sqlStr = [NSString stringWithFormat:@"DELETE FROM '%@' WHERE op = '%@' AND (select count(_id) FROM '%@')> %ld AND _id IN (select _id FROM '%@' ORDER BY _id ASC limit %ld) ;",FT_DB_TRACREVENT_TABLE_NAME,FT_DATA_TYPE_LOGGING,FT_DB_TRACREVENT_TABLE_NAME,(long)count,FT_DB_TRACREVENT_TABLE_NAME,(long)count];
            is = [self.db executeUpdate:sqlStr];
        }];
        return is;
}
-(BOOL)deleteItemWithTm:(long long)tm
{   __block BOOL is;
    [self zy_inDatabase:^{
        NSString *sqlStr = [NSString stringWithFormat:@"DELETE FROM '%@' WHERE tm <= %lld ;",FT_DB_TRACREVENT_TABLE_NAME,tm];
        is = [self.db executeUpdate:sqlStr];
    }];
    return is;
}
-(BOOL)deleteItemWithId:(long )Id
{   __block BOOL is;
    [self zy_inDatabase:^{
     NSString *sqlStr = [NSString stringWithFormat:@"DELETE FROM '%@' WHERE _id <= %ld ;",FT_DB_TRACREVENT_TABLE_NAME,Id];
        is = [self.db executeUpdate:sqlStr];
    }];
    return is;
}
- (void)close
{
    [_db close];
}
-(BOOL)isOpenDatabese:(ZY_FMDatabase *)db{
    if (![db open]) {
        [db open];
    }
    return YES;
}
- (BOOL)zy_isExistTable:(NSString *)tableName
{
    __block NSInteger count = 0;
    [self zy_inDatabase:^{
        ZY_FMResultSet *set = [self.db executeQuery:@"SELECT count(*) as 'count' FROM sqlite_master "
                                                "WHERE type ='table' and name = ?", tableName];
           while([set next]) {
               count = [set intForColumn:@"count"];
           }
           [set close];
    }];
   
    return count > 0;
}
- (void)zy_inDatabase:(void(^)(void))block
{

    [[self dbQueue] inDatabase:^(ZY_FMDatabase *db) {
        block();
    }];
}

- (void)zy_inTransaction:(void(^)(BOOL *rollback))block
{

    [[self dbQueue] inTransaction:^(ZY_FMDatabase *db, BOOL *rollback) {
        block(rollback);
    }];

}
- (NSMutableArray<FTRecordModel *> *)messageCaches {
    if (!_messageCaches) {
        _messageCaches = [NSMutableArray array];
    }
    return _messageCaches;
}
- (void)resetInstance{
    onceToken = 0;
    dbTool =nil;
}
@end
