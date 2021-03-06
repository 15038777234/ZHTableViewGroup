//
//  ZHTableViewDataSource.m
//  Pods
//
//  Created by 张行 on 2017/3/18.
//
//

#import "ZHTableViewDataSource.h"
#import "ZHAutoConfigurationTableViewDelegate.h"
NS_ASSUME_NONNULL_BEGIN

@interface ZHTableViewDataSource ()

@property (nonatomic, strong) NSMutableArray<ZHTableViewGroup *> *groups;

@end

@implementation ZHTableViewDataSource {
    NSCache *_cellCache;
}

- (instancetype)initWithTableView:(UITableView *)tableView {
    if (self = [super init]) {
        _tableView = tableView;
        _autoConfigurationTableViewDelegate = YES;
        _cellCache = [[NSCache alloc] init];
    }
    return self;
}

- (ZHTableViewGroup *)addGroupWithCompletionHandle:(ZHTableViewDataSourceAddGroupCompletionHandle)completionHandle {
    ZHTableViewGroup *group = [[ZHTableViewGroup alloc] init];
    if (completionHandle) {
        completionHandle(group);
    }
    [self.groups addObject:group];
    return group;
}

- (void)reloadTableViewData {
    if (!self.tableView.dataSource) {
        if (self.isAutoConfigurationTableViewDelegate) {
            self.tableView.dataSource = self.tableViewDelegate;
        } else {
            NSAssert(NO, @"必须给 UITableView 设置 DataSource 代理");
        }
    }
    if (!self.tableView.delegate) {
        if (self.isAutoConfigurationTableViewDelegate) {
            self.tableView.delegate = self.tableViewDelegate;
        }
    }
    [self registerClass];
    [self.tableView reloadData];
}

+ (NSInteger)numberOfRowsInSectionWithDataSource:(ZHTableViewDataSource *)dataSource
                                         section:(NSInteger)section {
    ZHTableViewGroup *group = [self groupForSectionWithDataSource:dataSource section:section];
    if (!group) {
        return 0;
    }
    return group.cellCount;
}

+ (UITableViewCell *)cellForRowAtWithDataSource:(ZHTableViewDataSource *)dataSource
                                      indexPath:(NSIndexPath *)indexPath {
    return [self cellForRowAtWithDataSource:dataSource
                                  indexPath:indexPath
                                     config:!dataSource.isWillDisplayData];
}

+ (UITableViewCell *)cellForRowAtWithDataSource:(ZHTableViewDataSource *)dataSource
                                      indexPath:(NSIndexPath *)indexPath
                                         config:(BOOL)config
                                       useCache:(BOOL)useCache {
    ZHTableViewGroup *group = [self groupForSectionWithDataSource:dataSource section:indexPath.section];
    ZHTableViewCell *tableViewCell = [group tableViewCellForIndexPath:indexPath];
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    if (!group) {
        return cell;
    }
    UITableViewCell *resultCell;
    if (useCache) {
        UITableViewCell *cacheCell = [dataSource cacheCellWithIndexPath:indexPath];
        if ([cacheCell isKindOfClass:tableViewCell.anyClass]) {
            resultCell = [dataSource cacheCellWithIndexPath:indexPath];
            [group tableViewCell:tableViewCell configCell:resultCell atIndexPath:indexPath];
        }
    }
    if (!resultCell) {
        resultCell = [group cellForTableViewWithTableView:dataSource.tableView
                                                indexPath:indexPath
                                                   config:config];
    }
    if (!resultCell) {
        return cell;
    }
    NSIndexPath *realIndexPath = [group indexPathWithCell:tableViewCell indexPath:indexPath];
    BOOL isHidden = [tableViewCell isHiddenWithIndexPath:realIndexPath];
    resultCell.hidden = isHidden;
    if (!useCache) {
        [dataSource saveCacheWithCell:resultCell indexPath:indexPath];
    }
    return resultCell;
}

- (UITableViewCell *)cacheCellWithIndexPath:(NSIndexPath *)indexPath {
    return [_cellCache objectForKey:[self cacheKeyWithIndexPath:indexPath]];
}

- (void)saveCacheWithCell:(UITableViewCell *)cell indexPath:(NSIndexPath *)indexPath {
    [_cellCache setObject:cell forKey:[self cacheKeyWithIndexPath:indexPath]];
}

- (NSString *)cacheKeyWithIndexPath:(NSIndexPath *)indexPath {
    return [NSString stringWithFormat:@"%@-%@",@(indexPath.section),@(indexPath.row)];
}

+ (UITableViewCell *)cellForRowAtWithDataSource:(ZHTableViewDataSource *)dataSource
                                      indexPath:(NSIndexPath *)indexPath
                                         config:(BOOL)config {
    return [self cellForRowAtWithDataSource:dataSource
                                  indexPath:indexPath
                                     config:config
                                   useCache:NO];
}

+ (NSInteger)numberOfSectionsWithDataSource:(ZHTableViewDataSource *)dataSource {
    if (!dataSource) {
        return 0;
    }
    return dataSource.groups.count;
}

+ (CGFloat)heightForRowAtDataSource:(ZHTableViewDataSource *)dataSource
                          indexPath:(NSIndexPath *)indexPath customHeightCompletionHandle:(ZHTableViewDataSourceCustomHeightCompletionHandle)customHeightCompletionHandle {
    ZHTableViewCell *cell = [self cellForIndexPath:dataSource indexPath:indexPath];
    
    if (!cell) {
        return 0;
    }
    NSIndexPath *realyIndexPath = [self indexPathWithDataSource:dataSource
                                                      indexPath:indexPath];
    if ([cell isHiddenWithIndexPath:realyIndexPath]) {
        return 0;
    }
    if (cell.customHeightBlock) {
        UITableViewCell *tableViewCell = [self cellForRowAtWithDataSource:dataSource
                                                                indexPath:indexPath
                                                                   config:YES
                                                                 useCache:YES];
        return cell.customHeightBlock(tableViewCell, realyIndexPath);
    }
    if (!dataSource.priorityHeight) {
        CGFloat automaticHeight = ({
            automaticHeight = CGFLOAT_MAX;
            if (cell.height == NSNotFound) {
                UITableViewCell *automaticHeightCell = [self cellForRowAtWithDataSource:dataSource indexPath:indexPath config:YES
                                                                               useCache:YES];
                automaticHeight = [automaticHeightCell sizeThatFits:CGSizeMake([UIScreen mainScreen].bounds.size.width, CGFLOAT_MAX)].height;
            }
            automaticHeight;
        });
        CGFloat height = cell.height;
        if (cell.height == NSNotFound && automaticHeight != CGFLOAT_MAX) {
            height = automaticHeight;
        }
        return [self heightWithCustomHandle:height
                     customCompletionHandle:customHeightCompletionHandle
                                  baseModel:cell];
    } else {
        CGFloat heigh = cell.height;
        if (heigh > 0 && heigh < CGFLOAT_MAX && heigh < NSNotFound) {
            return heigh;
        }
        if (customHeightCompletionHandle) {
            heigh = customHeightCompletionHandle(cell);
            if (heigh > 0 && heigh < CGFLOAT_MAX && heigh < NSNotFound) {
                return heigh;
            }
        }
        CGFloat automaticHeight = ({
            automaticHeight = CGFLOAT_MAX;
            if (cell.height == NSNotFound) {
                UITableViewCell *automaticHeightCell = [self cellForRowAtWithDataSource:dataSource
                                                                              indexPath:indexPath
                                                                                 config:YES
                                                                               useCache:YES];
                automaticHeight = [automaticHeightCell sizeThatFits:CGSizeMake([UIScreen mainScreen].bounds.size.width, CGFLOAT_MAX)].height;
            }
            automaticHeight;
        });
        return automaticHeight;
    }
}

+ (void)didSelectRowAtWithDataSource:(ZHTableViewDataSource *)dataSource
                           indexPath:(NSIndexPath *)indexPath {
    
    ZHTableViewCell *tableViewCell = [self cellForIndexPath:dataSource indexPath:indexPath];
    if (!tableViewCell) {
        return;
    }
    __block UITableViewCell *cell = ({
        cell = nil;
        /* 因为点击的 CELL 一定是在屏幕可见的范围之内 所以直接取 */
        [dataSource.tableView.visibleCells enumerateObjectsUsingBlock:^(__kindof UITableViewCell * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSIndexPath *visibleIndexPath = [dataSource.tableView indexPathForCell:obj];
            if ([indexPath compare:visibleIndexPath] == NSOrderedSame) {
                cell = obj;
            }
        }];
        cell;
    });
    if (!cell) {
        return;
    }
	ZHTableViewGroup *group = [self groupForSectionWithDataSource:dataSource section:indexPath.section];
    [tableViewCell didSelectRowAtWithCell:cell indexPath:[group indexPathWithCell:tableViewCell indexPath:indexPath]];
}

+ (CGFloat)heightForHeaderInSectionWithDataSource:(ZHTableViewDataSource *)dataSource
                                          section:(NSInteger)section customHeightCompletionHandle:(ZHTableViewDataSourceCustomHeightCompletionHandle)customHeightCompletionHandle {
    return [self heightForHeaderFooterInSectionWithDataSource:dataSource section:section style:ZHTableViewHeaderFooterStyleHeader customHeightCompletionHandle:customHeightCompletionHandle];
}

+ (CGFloat)heightForFooterInSectionWithDataSource:(ZHTableViewDataSource *)dataSource
                                          section:(NSInteger)section customHeightCompletionHandle:(ZHTableViewDataSourceCustomHeightCompletionHandle)customHeightCompletionHandle {
    return [self heightForHeaderFooterInSectionWithDataSource:dataSource section:section style:ZHTableViewHeaderFooterStyleFooter customHeightCompletionHandle:customHeightCompletionHandle];
}

+ (UITableViewHeaderFooterView *)viewForHeaderInSectionWithDataSource:(ZHTableViewDataSource *)dataSource
                                                              section:(NSInteger)section {
    return [self viewHeaderFooterInSectionWithDtaSource:dataSource section:section style:ZHTableViewHeaderFooterStyleHeader];
}

+ (UITableViewHeaderFooterView *)viewForFooterInSectionWithDataSource:(ZHTableViewDataSource *)dataSource
                                                              section:(NSInteger)section {
    return [self viewHeaderFooterInSectionWithDtaSource:dataSource section:section style:ZHTableViewHeaderFooterStyleFooter];
}

- (void)clearData {
    [self.groups removeAllObjects];
    [_cellCache removeAllObjects];
}

+ (UITableViewHeaderFooterView *)viewHeaderFooterInSectionWithDtaSource:(ZHTableViewDataSource *)dataSource
                                                                section:(NSInteger)section style:(ZHTableViewHeaderFooterStyle)style {
    ZHTableViewGroup *group = [self groupForSectionWithDataSource:dataSource section:section];
    if (!group) {
        return nil;
    }
    return [group headerFooterForStyle:style tableView:dataSource.tableView section:section];
}

+ (CGFloat)heightForHeaderFooterInSectionWithDataSource:(ZHTableViewDataSource *)dataSource
                                                section:(NSInteger)section style:(ZHTableViewHeaderFooterStyle)style
                           customHeightCompletionHandle:(ZHTableViewDataSourceCustomHeightCompletionHandle)customHeightCompletionHandle {
    ZHTableViewGroup *group = [self groupForSectionWithDataSource:dataSource section:section];
    if(!group) {
        return 0;
    }
    NSInteger height = 0;
    ZHTableViewBaseModel *baseModel;
    UITableViewHeaderFooterView *headFooter = [self viewHeaderFooterInSectionWithDtaSource:dataSource section:section style:style];
    CGFloat automaticHeight = [headFooter sizeThatFits:CGSizeMake([UIScreen mainScreen].bounds.size.width, CGFLOAT_MAX)].height;
    switch (style) {
        case ZHTableViewHeaderFooterStyleHeader: {
            height = group.header.height;
            baseModel = group.header;
            if (group.header.customHeightBlock) {
                [group.header setHeaderFooter:headFooter section:section];
                return group.header.customHeightBlock(headFooter,section);
            }
        }
            break;
        case  ZHTableViewHeaderFooterStyleFooter: {
            height = group.footer.height;
            baseModel = group.footer;
            if (group.footer.customHeightBlock) {
                [group.footer setHeaderFooter:headFooter section:section];
                return group.footer.customHeightBlock(headFooter,section);
            }
        }
            break;
    }
    if (height == NSNotFound && automaticHeight != CGFLOAT_MAX) {
        height = automaticHeight;
    }
    return [self heightWithCustomHandle:height customCompletionHandle:customHeightCompletionHandle baseModel:baseModel];
}

+ (CGFloat)heightWithCustomHandle:(CGFloat)height
           customCompletionHandle:(ZHTableViewDataSourceCustomHeightCompletionHandle)customCompletionHandle
                        baseModel:(ZHTableViewBaseModel *)baseModel {
    return [self lookBestHeightWithBlock:^CGFloat(NSUInteger index, BOOL *stop) {
        if (index == 0) {
            return height;
        } else if (index == 1 && customCompletionHandle) {
            return customCompletionHandle(baseModel);
        } else {
            *stop = YES;
            return 0;
        }
    }];
}

+ (BOOL)isVirifyHeight:(CGFloat)height {
    return height != NSNotFound && height != CGFLOAT_MAX;
}

+ (CGFloat)lookBestHeightWithBlock:(CGFloat(^)(NSUInteger index, BOOL *stop))block {
    CGFloat height = 0;
    BOOL stop = NO;
    NSUInteger index = 0;
    while (!stop) {
        height = block(index, &stop);
        if ([self isVirifyHeight:height]) {
            return height;
        }
        index ++;
    }
    return height;
}

+ (ZHTableViewGroup *)groupForSectionWithDataSource:(ZHTableViewDataSource *)dataSource
                                            section:(NSInteger)section {
    if (!dataSource) {
        return nil;
    }
    if (dataSource.groups.count <= section) {
        return nil;
    }
    return  dataSource.groups[section];
}

+ (ZHTableViewCell *)cellForIndexPath:(ZHTableViewDataSource *)dataSource
                            indexPath:(NSIndexPath *)indexPath {
    ZHTableViewGroup *group = [self groupForSectionWithDataSource:dataSource section:indexPath.section];
    if (!group) {
        return nil;
    }
    return [group tableViewCellForIndexPath:indexPath];
}

+ (NSIndexPath *)indexPathWithDataSource:(ZHTableViewDataSource *)dataSource indexPath:(NSIndexPath *)indexPath {
	ZHTableViewGroup *group = [self groupForSectionWithDataSource:dataSource section:indexPath.section];
	ZHTableViewCell *tableViewCell = [self cellForIndexPath:dataSource indexPath:indexPath];
	return [group indexPathWithCell:tableViewCell indexPath:indexPath];
}

+ (void)dataSource:(ZHTableViewDataSource *)dataSource
   willDisplayCell:(UITableViewCell *)cell
 forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!dataSource.isWillDisplayData) {
        return;
    }
    ZHTableViewGroup *group = [self groupForSectionWithDataSource:dataSource
                                                          section:indexPath.section];
    ZHTableViewCell *tableViewCell = [self cellForIndexPath:dataSource
                                                  indexPath:indexPath];
    [group tableViewCell:tableViewCell
              configCell:cell
             atIndexPath:indexPath];
}

- (void)registerClass {
    for (ZHTableViewGroup *group in self.groups) {
        [group registerHeaderFooterCellWithTableView:self.tableView];
    }
}

- (NSMutableArray<ZHTableViewGroup *> *)groups {
    if (!_groups) {
        _groups = [NSMutableArray array];
    }
    return _groups;
}

- (ZHAutoConfigurationTableViewDelegate *)tableViewDelegate {
    if (!_tableViewDelegate) {
        _tableViewDelegate = [[ZHAutoConfigurationTableViewDelegate alloc] initWithDataSource:self];
    }
    return _tableViewDelegate;
}

@end

@implementation ZHTableViewDataSource (ReloadHeight)

#pragma mark - 根据标识符刷新高度
- (void)reloadCellAutomaticHeightWithIdentifier:(NSString *)identifier {
    [self reloadCellFixedHeight:NSNotFound
                     identifier:identifier];
}

- (void)reloadCellFixedHeight:(CGFloat)height
                   identifier:(NSString *)identifier {
    [self reloadCellHeight:height
       tableViewCellConfig:^BOOL(NSUInteger section, NSUInteger row, ZHTableViewCell *tableViewCell) {
        return [tableViewCell.identifier isEqualToString:identifier];
    }];
}

#pragma mark - 根据类类型刷新高度
- (void)reloadCellAutomaticHeightWithClass:(Class)className {
    [self reloadCellFixedHeight:NSNotFound
                      className:className];
}

- (void)reloadCellFixedHeight:(CGFloat)height
                    className:(Class)className {
    [self reloadCellHeight:height
       tableViewCellConfig:^BOOL(NSUInteger section, NSUInteger row, ZHTableViewCell *tableViewCell) {
        return tableViewCell.anyClass == className;
    }];
}

- (void)reloadCellAutomaticHeightWithTableViewCell:(ZHTableViewCell *)tableViewCell {
    [self reloadCellFixedHeight:NSNotFound
                  tableViewCell:tableViewCell];
}

- (void)reloadCellFixedHeight:(NSInteger)height
                tableViewCell:(ZHTableViewCell *)tableViewCell {
    [self reloadCellHeight:height
       tableViewCellConfig:^BOOL(NSUInteger section, NSUInteger row, ZHTableViewCell *cell) {
        return [cell isEqual:tableViewCell];
    }];
}

- (void)reloadCellAutomicHeightWithGroupIndex:(NSUInteger)groupIndex
                                    cellIndex:(NSUInteger)cellIndex {
    [self reloadCellFixedHeight:NSNotFound
                     groupIndex:groupIndex
                      cellIndex:cellIndex];
}

- (void)reloadCellFixedHeight:(CGFloat)height
                   groupIndex:(NSUInteger)groupIndex
                    cellIndex:(NSUInteger)cellIndex {
    [self reloadCellHeight:height
       tableViewCellConfig:^BOOL(NSUInteger section, NSUInteger row, ZHTableViewCell *tableViewCell) {
        return section == groupIndex && row == cellIndex;
    }];
}

- (void)reloadCellHeight:(CGFloat)height
     tableViewCellConfig:(BOOL (^)(NSUInteger section, NSUInteger row, ZHTableViewCell *tableViewCell))tableViewCellConfig {
    if (!tableViewCellConfig) {
        return;
    }
    [[self filterCellWithConfig:tableViewCellConfig] enumerateObjectsUsingBlock:^(ZHTableViewCell * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        obj.height = height;
        [self.tableView beginUpdates];
        [self.tableView endUpdates];
    }];;
}

@end

@implementation ZHTableViewDataSource (ReloadCell)

- (void)reloadCellWithIdentifier:(NSString *)identienfier {
    [self reloadCellWithTableViewCellConfig:^BOOL(NSUInteger section, NSUInteger row, ZHTableViewCell *tableViewCell) {
        return [tableViewCell.identifier isEqualToString:identienfier];
    }];
}

- (void)reloadCellWithClassName:(Class)className {
    [self reloadCellWithTableViewCellConfig:^BOOL(NSUInteger section, NSUInteger row, ZHTableViewCell *tableViewCell) {
        return tableViewCell.anyClass == className;
    }];
}

- (void)reloadCellWithTableViewCell:(ZHTableViewCell *)tableViewCell {
    [self reloadCellWithTableViewCellConfig:^BOOL(NSUInteger section, NSUInteger row, ZHTableViewCell *tableViewCell1) {
        return [tableViewCell isEqual:tableViewCell1];
    }];
}

- (void)reloadCellWithGroupIndex:(NSUInteger)groupIndex
                       cellIndex:(NSUInteger)cellIndex {
    [self reloadCellWithTableViewCellConfig:^BOOL(NSUInteger section, NSUInteger row, ZHTableViewCell *tableViewCell1) {
        return groupIndex == section && cellIndex == row;
    }];
}

- (void)reloadCellWithTableViewCellConfig:(BOOL (^)(NSUInteger section, NSUInteger row, ZHTableViewCell *tableViewCell))tableViewCellConfig {
    if (!tableViewCellConfig) {
        return;
    }
    [[self filterCellWithConfig:tableViewCellConfig] enumerateObjectsUsingBlock:^(ZHTableViewCell * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSMutableArray<NSIndexPath *> *indexPaths = [NSMutableArray array];
        for (NSUInteger i = 0; i < obj.cellNumber; i++) {
            NSIndexPath *indexPath = [self indexPathWithTableViewCell:obj];
            [indexPaths addObject:[NSIndexPath indexPathForRow:(indexPath.row + i) inSection:indexPath.section]];
        }
        [self updatesTableView:^{
            [self.tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
        }];
    }];
}

- (NSMutableArray<NSIndexPath *> *)indexPathsWithTableViewCell:(ZHTableViewCell *)tableViewCell {
    NSMutableArray<NSIndexPath *> *indexPaths = [NSMutableArray array];
    for (NSUInteger i = 0; i < tableViewCell.cellNumber; i++) {
        NSIndexPath *indexPath = [self indexPathWithTableViewCell:tableViewCell];
        [indexPaths addObject:[NSIndexPath indexPathForRow:(indexPath.row + i) inSection:indexPath.section]];
    }
    return indexPaths;
}

@end

@implementation ZHTableViewDataSource (ReloadData)

- (void)reloadCellWithDataCount:(NSUInteger)dataCount
                     identifier:(NSString *)identifier {
    [self reloadCellWithDataCount:dataCount tableViewCellConfig:^BOOL(NSUInteger section, NSUInteger row, ZHTableViewCell *tableViewCell) {
        return [tableViewCell.identifier isEqualToString:identifier];
    }];
}

- (void)reloadCellWithDataCount:(NSUInteger)dataCount
                 className:(Class)className {
    [self reloadCellWithDataCount:dataCount tableViewCellConfig:^BOOL(NSUInteger section, NSUInteger row, ZHTableViewCell *tableViewCell) {
        return tableViewCell.anyClass == className;
    }];
}

- (void)reloadCellWithDataCount:(NSUInteger)dataCount
             tableViewCell:(ZHTableViewCell *)tableViewCell {
    [self reloadCellWithDataCount:dataCount tableViewCellConfig:^BOOL(NSUInteger section, NSUInteger row, ZHTableViewCell *tableViewCell1) {
        return [tableViewCell isEqual:tableViewCell1];
    }];
}

- (void)reloadCellWithDataCount:(NSUInteger)dataCount
                groupIndex:(NSUInteger)groupIndex
                 cellIndex:(NSUInteger)cellIndex {
    [self reloadCellWithDataCount:dataCount tableViewCellConfig:^BOOL(NSUInteger section, NSUInteger row, ZHTableViewCell *tableViewCell1) {
        return groupIndex == section && cellIndex == row;
    }];
}

- (void)reloadCellWithDataCount:(NSUInteger)dataCount
            tableViewCellConfig:(BOOL (^)(NSUInteger section, NSUInteger row, ZHTableViewCell *tableViewCell))tableViewCellConfig {
    [[self filterCellWithConfig:tableViewCellConfig] enumerateObjectsUsingBlock:^(ZHTableViewCell * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSUInteger cellNumber = obj.cellNumber;
        NSIndexPath *indexPath = [self indexPathWithTableViewCell:obj];
        obj.cellNumber = dataCount;
        if (cellNumber == dataCount) {
            NSMutableArray<NSIndexPath *> *indexPaths = [NSMutableArray array];
            for (NSUInteger i = 0; i < cellNumber; i++) {
                [indexPaths addObject:[NSIndexPath indexPathForRow:(indexPath.row + i) inSection:indexPath.section]];
            }
            [self.tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
        } else if (cellNumber < dataCount) {
            NSMutableArray<NSIndexPath *> *indexPaths = [NSMutableArray array];
            NSMutableArray<NSIndexPath *> *insertIndexPaths = [NSMutableArray array];
            for (NSUInteger i = 0; i < dataCount; i++) {
                if (i < cellNumber) {
                    [indexPaths addObject:[NSIndexPath indexPathForRow:(indexPath.row + i) inSection:indexPath.section]];
                } else {
                    [insertIndexPaths addObject:[NSIndexPath indexPathForRow:(indexPath.row + i) inSection:indexPath.section]];
                }
            }
            [self updatesTableView:^{
                [self.tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
                [self.tableView insertRowsAtIndexPaths:insertIndexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
            }];
        } else {
            NSMutableArray<NSIndexPath *> *indexPaths = [NSMutableArray array];
            NSMutableArray<NSIndexPath *> *deleteIndexPath = [NSMutableArray array];
            for (NSUInteger i = 0; i < cellNumber; i++) {
                if (i < dataCount) {
                    [indexPaths addObject:[NSIndexPath indexPathForRow:(indexPath.row + i) inSection:indexPath.section]];
                } else {
                    [deleteIndexPath addObject:[NSIndexPath indexPathForRow:(indexPath.row + i) inSection:indexPath.section]];
                }
            }
            [self updatesTableView:^{
                [self.tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
                [self.tableView deleteRowsAtIndexPaths:deleteIndexPath withRowAnimation:UITableViewRowAnimationAutomatic];
            }];
        }
    }];
}

- (void)updatesTableView:(void(^)(void))update {
    if (@available(iOS 11.0, *)) {
        [self.tableView performBatchUpdates:update completion:nil];
    } else {
        [self.tableView beginUpdates];
        update();
        [self.tableView endUpdates];
    }
}

@end

@implementation ZHTableViewDataSource (Cell)

- (NSArray<ZHTableViewCell *> *)filterCellWithConfig:(BOOL (^)(NSUInteger section, NSUInteger row, ZHTableViewCell *tableViewCell))config {
    NSMutableArray<ZHTableViewCell *> *filterResults = [NSMutableArray array];
    __block NSUInteger section = 0;
    [self.groups enumerateObjectsUsingBlock:^(ZHTableViewGroup * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        section = idx;
        __block NSUInteger row = 0;
        [obj.cells enumerateObjectsUsingBlock:^(ZHTableViewCell * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            row = idx;
            if (config(section,row,obj)) {
                [filterResults addObject:obj];
            }
        }];
    }];
    return filterResults;
}

- (NSIndexPath *)indexPathWithTableViewCell:(ZHTableViewCell *)tableViewCell {
    __block NSIndexPath *indexPath;
    __block NSUInteger section = 0;
    [self.groups enumerateObjectsUsingBlock:^(ZHTableViewGroup * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        section = idx;
        __block NSUInteger row = 0;
        [obj.cells enumerateObjectsUsingBlock:^(ZHTableViewCell * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([tableViewCell isEqual:obj]) {
                indexPath = [NSIndexPath indexPathForRow:row inSection:section];
                *stop = YES;
                return;
            }
            row += obj.cellNumber;
        }];
    }];
    return indexPath;
}

@end

@implementation ZHTableViewDataSource (Hidden)

- (void)reloadAllHiddenCell {
    NSMutableArray<NSIndexPath *> *needReloadIndexPath = [NSMutableArray array];
    [[self filterCellWithConfig:^BOOL(NSUInteger section, NSUInteger row, ZHTableViewCell *tableViewCell) {
        return YES;
    }] enumerateObjectsUsingBlock:^(ZHTableViewCell * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (!obj.hiddenBlock) {
            return;
        }
        [[self indexPathsWithTableViewCell:obj] enumerateObjectsUsingBlock:^(NSIndexPath * _Nonnull indexPath, NSUInteger idx, BOOL * _Nonnull stop) {
            NSIndexPath *realIndexPath = [NSIndexPath indexPathForRow:idx inSection:0];
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
            if (cell && cell.isHidden == [obj isHiddenWithIndexPath:realIndexPath]) {
                return;
            }
            [needReloadIndexPath addObject:indexPath];
        }];
    }] ;
    [self updatesTableView:^{
        [self.tableView reloadRowsAtIndexPaths:needReloadIndexPath
                              withRowAnimation:UITableViewRowAnimationAutomatic];
    }];
}

@end
NS_ASSUME_NONNULL_END
