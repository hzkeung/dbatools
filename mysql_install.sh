#!/bin/bash
#By Huang Jinqiang<hzkeung@vip.qq.com>

usage_function() {
    #usage function
    echo "usage: $0 init_options replication_options"
    echo "  init options:"
    echo "    --version=                #mysql server version"
    echo "    --port=                   #mysql server port"
    echo "    --password=               #mysql user root@'localhost' password"
    echo "    --multi=[yes|no]          #mysql multi-instance yes or no"
    echo "  replication options:"
    echo "    --master-host=            #mysql master host"
    echo "    --master-port=            #mysql master port"
}

temp=$(echo -n "$@" -- |sed "s/=/ /g")
eval set -- $temp
while true; do
    case "$1" in
        --multi)
            multi=$2
            shift 2;;
        --port)
            port=$2
            shift 2 ;;
         --password)
            password=$2
            shift 2 ;;
         --version)
            version=$2
            shift 2 ;;
        --master-host)
             master_host=$2
            shift 2 ;;
        --master-port)
            master_port=$2
            shift 2 ;;
        --)
            break;;
        *)
            usage_function
            exit 1;;
    esac
done



conf_function() {
    cat > $1 <<EOF
#my.cnf
[client]
port    = ${port}
socket  = /tmp/mysql${port}.sock

[mysql]
prompt="\u@\h [\d]>" 
#pager="less -i -n -S"
#tee=/opt/mysql/query.log
no-auto-rehash

[mysqld]
#misc
user = mysql
basedir = /usr/local/mysql
datadir = /data/mysql/${port}/data
port = 3306
socket = /tmp/mysql${port}.sock
event_scheduler = 0
explicit-defaults-for-timestamp=on
skip_name_resolve = on
tmpdir = /data/mysql/${port}/tmp
#timeout
interactive_timeout = 300
wait_timeout = 300

#character set
character-set-server = utf8

open_files_limit = 65535
max_connections = 100
max_connect_errors = 100000
#lower_case_table_names =1
#logs
log-output=file
slow_query_log = 1
slow_query_log_file = slow.log
log-error = error.log
log_error_verbosity=3
pid-file = mysql.pid
long_query_time = 1
#log-slow-admin-statements = 1
#log-queries-not-using-indexes = 1
log-slow-slave-statements = 1

#binlog
#binlog_format = STATEMENT
binlog_format = row
server-id = ${port}${node}
log-bin = /data/mysql/${port}/logs/mysql-bin
binlog_cache_size = 4M
max_binlog_size = 256M
max_binlog_cache_size = 1M
sync_binlog = 1
expire_logs_days = 10
#procedure 
log_bin_trust_function_creators=1

#GTID
gtid-mode = ON
enforce_gtid_consistency = ON

#relay log
skip_slave_start = 1
max_relay_log_size = 128M
relay_log_purge = 1
relay_log_recovery = 1
relay-log=relay-bin
relay-log-index=relay-bin.index
log_slave_updates
#slave-skip-errors=1032,1053,1062
#skip-grant-tables

#buffers & cache
table_open_cache = 2048
table_definition_cache = 2048
table_open_cache = 2048
max_heap_table_size = 96M
sort_buffer_size = 128K
join_buffer_size = 128K
thread_cache_size = 200
query_cache_size = 0
query_cache_type = 0
query_cache_limit = 256K
query_cache_min_res_unit = 512
thread_stack = 192K
tmp_table_size = 96M
key_buffer_size = 8M
read_buffer_size = 2M
read_rnd_buffer_size = 16M
bulk_insert_buffer_size = 32M

#myisam
myisam_sort_buffer_size = 128M
myisam_max_sort_file_size = 10G
myisam_repair_threads = 1

#innodb
innodb_buffer_pool_size = 100M
innodb_buffer_pool_instances = 1
innodb_data_file_path = ibdata1:100M:autoextend
innodb_flush_log_at_trx_commit = 1
innodb_log_buffer_size = 8M
innodb_log_file_size = 100M
innodb_log_files_in_group = 3
innodb_max_dirty_pages_pct = 50
innodb_file_per_table = 1
innodb_rollback_on_timeout
innodb_status_file = 1
innodb_io_capacity = 2000
transaction_isolation = READ-COMMITTED
innodb_flush_method = O_DIRECT
EOF
}
install() {
    #install and initalize mysql
    node=$(ip addr show | awk '/inet /&&/brd/{if(match($2,"([0-9]+)/",a))print a[1]}')
    yum -y install gcc gcc-c++ openssl openssl-devel sysstat lsof wget vim-enhanced libaio
    if ! id mysql > /dev/null 2>&1; then
        groupadd -g 27 mysql
        useradd -g 27 -u 27 -d /usr/local/mysql -s /sbin/nologin -M mysql
    fi

    mkdir -p /opt/mysql /data/mysql/${port}/{data,logs,tmp} -p
    cd /opt/
    wget -c  http://dev.mysql.com/get/Downloads/MySQL-${version:0:3}/mysql-${version}-linux-glibc2.5-x86_64.tar.gz
    if ! test -f /opt/mysql-${version}-linux-glibc2.5-x86_64.tar.gz;then
        echo "file mysql-${version}-linux-glibc2.5-x86_64.tar.gz not found!"
        exit
    fi
    if ! test -d /opt/mysql/mysql-${version}-linux-glibc2.5-x86_64; then
        tar xf mysql-${version}-linux-glibc2.5-x86_64.tar.gz -C /opt/mysql
        if ! test -d /usr/local/mysql;then 
            ln -s /opt/mysql/mysql-${version}-linux-glibc2.5-x86_64 /usr/local/mysql
        fi
    fi

    rm -fr /etc/my.cnf
    conf_function /data/mysql/${port}/my.cnf
    chown mysql.mysql /data/mysql /usr/local/mysql /opt/mysql -R

    if ! test -d /data/mysql/${port}/data/mysql;then
        cd /usr/local/mysql
        ./bin/mysqld --defaults-file=/data/mysql/${port}/my.cnf --initialize
        echo 'export PATH=/usr/local/mysql/bin:$PATH' > /etc/profile.d/mysql.sh
        if test $multi == "yes";then
            /usr/local/mysql/bin/mysqld --defaults-file=/data/mysql/${port}/my.cnf &
        else
            ln -s /data/mysql/${port}/my.cnf /etc/my.cnf
            \cp support-files/mysql.server /etc/init.d/mysqld
            /etc/init.d/mysqld start
        fi
        source /etc/profile
        sleep 5
        initpasswd=$(awk '/password/{print $NF}' /data/mysql/${port}/data/error.log)
        /usr/local/mysql/bin/mysql -S /tmp/mysql${port}.sock -p"$initpasswd" --connect-expired-password -e\
            "alter user current_user() identified by '$password'" > /dev/null 2>&1
    fi
}
slave() {
    #replicatoin function
    /usr/local/mysql/bin/mysql -S /tmp/mysql${port}.sock -p"$password"\
         -e "RESET MASTER;
         CHANGE MASTER TO MASTER_HOST='$master_host', MASTER_PORT=$master_port, MASTER_USER='repl', MASTER_PASSWORD='repl4slave', MASTER_AUTO_POSITION=1;
         START SLAVE;" > /dev/null 2>&1
    sleep 1
    /usr/local/mysql/bin/mysql -S /tmp/mysql${port}.sock -p"$password"\
         -e "show slave status\\G"
}

run_function() {
    if test -n "$port" -a -n "$version" -a -n "$password" -a -n "$multi" -a -n "$master_host" -a -n "$master_port";then
        install
        slave
    elif test -n "$port" -a -n "$version" -a -n "$password" -a -n "$multi";then
        install
    else
        usage_function
        exit 1
    fi
}

run_function
