#!/bin/bash  

localUrl='/Users/Smallfan/Desktop/trunk'

remoteHost='服务器IP'
remoteName='用户名'
remotePasswd='密码'
remotePath='Working Copy目录地址'

cd $localUrl
#从云服务器拷贝替换本地Library
scp -r "$remoteName@$remoteHost:$remotePath/Library" $localUrl
# wget -P . -m -nH ftp://$remoteHost:21/$remotePath/Library --ftp-user=$remoteName --ftp-password=$remotePasswd;
wait

#创建临时文件夹
mkdir temp
chmod -R 777 temp
cd temp

#下载云svn数据库,重命名为A.db
ftp -v -n << EOF
	open $remoteHost
	user $remoteName $remotePasswd
	cd $remotePath/.svn
	bin
	get wc.db
	prompt off
	bye
EOF
wait

cp wc.db A.db
wait

#创建本地svn数据库副本,重命名为B.db
cp $localUrl/.svn/wc.db $localUrl/temp
wait
mv wc.db B.db
wait


#开始执行替换
#从B.NODES表中查local_relpath字段中包含"Library/"的行,将结果存入B.TEMP_NODES表,同时删除原来的数据
sqlite3 B.db "create table TEMP_NODES as select * from NODES where local_relpath like 'Library/%';"
sqlite3 B.db "delete from NODES where local_relpath like 'Library/%';"

#将B.PRISTINE中checksum字段存在于B.TEMP_NODES中checksum字段的行中的md5_checksum存入B.PREDEL_PRISTINE
sqlite3 B.db << EOF
create table PREDEL_PRISTINE as select md5_checksum from PRISTINE where checksum in (select checksum from TEMP_NODES);
.exit
EOF

# #将B.PREDEL_PRISTINE中md5_checksum所有数据导出到文件BPREDELLIST.txt
# sqlite3 B.db "select md5_checksum from PREDEL_PRISTINE" > BPREDELLIST.txt
# wait

# #循环查询本地svn/pristine中与BPREDELLIST.txt每一行同名的文件,删除
# #为保存变更记录方便revert,暂时不删除了
# for line in $(cat BPREDELLIST.txt); do
# 	if [[ $line == \$* ]]; then
# 		if [[ $line != \$md5* ]]; then
# 			line=${line##*\$};
			

# 		fi
# 	fi
# done

#删除B.PREDEL_PRISTINE表
sqlite3 B.db "drop table PREDEL_PRISTINE;"

#将B.PRISTINE中checksum字段存在于B.TEMP_NODES中checksum字段的行删除,然后删除B.TEMP_NODES表
sqlite3 B.db "delete from PRISTINE where checksum in (select checksum from TEMP_NODES);"
sqlite3 B.db "drop table TEMP_NODES;"

#从A.NODES查local_relpath字段中包含"Library/"的行,将结果存入A.TEMP2_NODES,然后跨库复制A.TEMP2_NODES到B.TEMP2_NODES
sqlite3 A.db "create table TEMP2_NODES as select * from NODES where local_relpath like 'Library/%';"

sqlite3 B.db << EOF
attach database 'A.db' as 'A';
create table TEMP2_NODES as select * from A.TEMP2_NODES;
.exit
EOF

#判断B.NODES中是否存在inherited_props字段,如果没有则创建(兼容1.8以上svn)
# sqlite3 B.db "select * from sqlite_master where type = NODES and name = inherited_props"
# sqlite3 B.db "alter table NODES add column inherited_props blob;"

#将B.TEMP2_NODES插入到B.NODES
sqlite3 B.db "insert into NODES(wc_id,local_relpath,op_depth,parent_relpath,repos_id,repos_path,revision,presence,moved_here,moved_to,kind,properties,depth,checksum,symlink_target,changed_revision,changed_date,changed_author,translated_size,last_mod_time,dav_cache,file_external) select wc_id,local_relpath,op_depth,parent_relpath,repos_id,repos_path,revision,presence,moved_here,moved_to,kind,properties,depth,checksum,symlink_target,changed_revision,changed_date,changed_author,translated_size,last_mod_time,dav_cache,file_external from TEMP2_NODES;"
# sqlite3 B.db "insert into NODES select * from TEMP2_NODES;"

#将B.TEMP2_NODES中checksum所有数据导出到文件BPREMERGELIST.txt
sqlite3 B.db "select checksum from TEMP2_NODES;" > BPREMERGELIST.txt
wait

#删除B.TEMP2_NODES表
sqlite3 B.db "drop table TEMP2_NODES;"






#将A.PRISTINE中checksum字段存在于A.TEMP2_NODES中checksum字段的行复制到B.TEMP_PRISTINE
sqlite3 A.db "create table TEMP_PRISTINE as select * from PRISTINE where checksum in (select checksum from TEMP2_NODES);"

sqlite3 B.db << EOF
attach database "A.db" as 'A';
create table TEMP_PRISTINE as select * from A.TEMP_PRISTINE;
.exit
EOF

#将B.TEMP_PRISTINE插入B.PRISTINE
sqlite3 B.db "insert into PRISTINE select * from TEMP_PRISTINE;"







#从云服务器找到存在于BREMERGELIST.txt每一行的文件下载至本地.svn/pristine对应路径中
for line in $(cat BPREMERGELIST.txt); do
	if [[ $line == \$sha1* ]]; then
		line=${line##*\$};
		prefix=${line:0:2};

		# result=0;
		# zero=0;

		# all=`ls $localUrl/.svn/pristine`;
		# for dir in $all; do
		# 	if [[ $dir == $prefix ]]; then
		# 		result=1;
		# 		break 1;
		# 	fi
		# done

		# if [ "$result" -eq "$zero" ]; then
		# 	cd pristine;
		# 	mkdir $dir;
		# 	chmod -R 777 $dir;
		# 	wait;
		# fi

		cd $localUrl/.svn/pristine/$dir/

		rm -rf ./$line.svn-base
   		wget ftp://$remoteHost:21/$remotePath/.svn/pristine/$dir/$line.svn-base --ftp-user=$remoteName --ftp-password=$remotePasswd;
   		
		wait

	fi
done


#删除B.TEMP_PRISTINE
sqlite3 B.db "drop table TEMP_PRISTINE;"
#结束替换


#覆盖本地原来svn数据库,并删除所有临时数据库
# cp -f $localUrl/temp/B.db $localUrl/.svn/wc.db
# wait
#
# rm $localUrl/temp

echo "完成任务!!!"
