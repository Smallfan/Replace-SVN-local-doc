#!/bin/sh
export LC_ALL="en_US.UTF-8"

# 检查通过sh命令执行的shell脚本是不是还在执行当中,避免重复执行. 
checkitem="$0"
let procCnt=`ps -A --format='%p%P%C%x%a' --width 2048 -w --sort pid|grep "$checkitem"|grep -v grep|grep -v " -c sh "|grep -v "$$" | grep -c sh|awk '{printf("%d",$1)}'`
if [ ${procCnt} -gt 0 ] ; then 
    echo "$0脚本已经在运行[procs=${procCnt}],此次执行自动取消."
    exit 1; 
fi

cd /Users/Smallfan/trunk





for (( i = 0;; i++ )); do

	# echo "获取需要更新列表中" $(date '+%Y-%m-%d %H:%M:%S');
	# # 获取svn需要更新的文件列表
	# result=$(svn status -u)
	# keyword="*"

	# if [[ $result == *$keyword* ]]; then
		
		#需要更新
		echo "正在获取更新,请勿中途停止 " $(date '+%Y-%m-%d %H:%M:%S');
		svn update
		wait
		echo "更新完成" $(date '+%Y-%m-%d %H:%M:%S');
		echo "亲,让服务器休息一小会儿(1分钟)"
		sleep 30;

	# else

	# 	#不需要更新
	# 	echo "不需要更新" $(date '+%Y-%m-%d %H:%M:%S');

	# fi

done

