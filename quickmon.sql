
-- system time
select 'NOW' as indicator, trunc(sysdate(), 'SS') as sysdate; 


-- system status
select 'SYSTEM' as indicator, node_count,node_down_count
  , current_epoch-last_good_epoch-1 as epoch_lag
  , trim(to_char(wos_row_count, '999,999,999,999')) as wos_row_count
  , trim(to_char(total_used_bytes//1024//1024, '999,999,999,999')) as total_used_mb
  , current_epoch,last_good_epoch,ahm_epoch 
from system;


-- sessions
select 'SESSION_COUNT' as indicator, count(*)
from sessions;


-- cpu usage
select 'CPU_USAGE' as indicator
  ,trunc(time, 'SS') as time
  ,avg(100*(user_microseconds_end_value-user_microseconds_start_value
        +nice_microseconds_end_value-nice_microseconds_start_value
        +system_microseconds_end_value-system_microseconds_start_value
        +io_wait_microseconds_end_value-io_wait_microseconds_start_value)/number_of_processors)//1000000 as cpu_usage
from dc_cpu_aggregate_by_second 
group by 2 order by 2 desc limit 1;


-- memory usage
select 'MEMORY_SIZE' as indicator
  , trim(to_char(max(memory_size_kb), '999,999,999,999'))as memory_size_kb
  , trim(to_char(max(memory_inuse_kb+metadata_memory_inuse_kb), '999,999,999,999')) as memory_inuse_kb
  , 100*max(memory_inuse_kb+metadata_memory_inuse_kb)//max(memory_size_kb) as memory_usage
from (
  select node_name, sum(memory_size_kb) as memory_size_kb, sum(memory_inuse_kb) as memory_inuse_kb
  from resource_pool_status
  group by node_name
) t0
join (
  select node_name, sum(memory_size_kb) as metadata_memory_inuse_kb
  from resource_pool_status
  where pool_name = 'metadata'
  group by node_name
) t1 on t0.node_name = t1.node_name;


-- running query count 
select 'RUNNING_QUERY_COUNT' as indicator, ifnull(max(running_query_count), 0) as running_query_count
from (
  select sum(running_query_count) as running_query_count
  from resource_pool_status 
  group by node_name
) t ;


-- queued query count 
select 'QUEUED_QUERY_COUNT' as indicator, ifnull(max(queued_query_count), 0) as queued_query_count
from (
  select count(*) as queued_query_count
  from resource_queues 
  group by node_name
) t ;


-- free query entry count 
select 'FREE_QUERY_ENTRY_COUNT' as indicator, ifnull(max(free_query_entry_count), 0) as free_query_entry_count
from (
  select sum((memory_size_kb*0.95-memory_inuse_kb)*0.95//query_budget_kb) as free_query_entry_count
  from resource_pool_status 
  where pool_name not in ('sysdata', 'wosdata', 'metadata', 'blobdata', 'jvm', 'tm', 'dbd', 'sysquery', 'refresh')
  group by node_name
) t ;


-- resource pool status
select 'RESOURCE_POOL_STATUS' as indicator
  , t1.pool_name
  , t1.running_query_count
  , NVL2(t2.queued_query_count, 0, t1.free_query_entry) as free_query_entry
  , t2.queued_query_count
from (
  select pool_name
    , running_query_count
    , (max_memory_size_kb*0.95-memory_inuse_kb)*0.95//query_budget_kb as free_query_entry
  from resource_pool_status 
  where pool_name not in ('sysdata', 'wosdata', 'metadata', 'blobdata', 'jvm'/*, 'tm', 'dbd', sysquery', 'refresh'*/)
  and node_name=(select node_name from nodes where node_state='UP' order by node_name limit 1)
) t1
left join (
  select pool_name
    , count(*) as queued_query_count
  from resource_queues 
  where pool_name not in ('sysdata', 'wosdata', 'metadata', 'blobdata', 'jvm'/*, 'tm', 'dbd', sysquery', 'refresh'*/)
  and node_name=(select node_name from nodes where node_state='UP' order by node_name limit 1)
  group by pool_name
) t2 on t1.pool_name = t2.pool_name
order by 3 desc, 2
;

-- tuple mover operations
select distinct 'TUPLE_MOVER_OPERATIONS' as indicator
  , table_schema || '.' || table_name as table_name
  , operation_name
from tuple_mover_operations
where is_executing='t'
order by 2;

