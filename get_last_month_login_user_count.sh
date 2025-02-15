#!/bin/bash
######################################################################################
# System name      : cas
# Component        : cm
# File name        : casmn_get_last_month_login_user_count.sh
# Process name     : System common function(log output)
#
# Function name    : 
# Output file      : /share/infra/log/casmn_get_last_month_login_user_count.sh.YYYYmmdd.HOSTNAME.log
# Return value     : 0 - Normal end
#                    1 - Warning Exit(Parameter error)
#                    2 - Warning Exit(There ia a warning)
#                    99- Abnormal end(Copy failure)
#                    104-Abnormal end(File doesn't exist)
#
######################################################################################

#-------------------------------------------------------------------------------
# Reading the common profile
#-------------------------------------------------------------------------------
CAS_DIR=/oper/script/cas
. ${CAS_DIR}/def/cascm_env.prf
. ${CAS_DIR}/def/cascm_func_shell.prf
. ${CAS_DIR}/def/cascm_func_log.prf
. ${CAS_DIR}/def/get_last_month_login_user_count.prf

#-----------------------------------
#Variable definition
#-----------------------------------
ymd_host=`date "+%Y%m%d"`.`hostname`
date_time=`date "+%Y/%m/%d %H:%M:%S"`
date_month_host=`echo $2 | awk '{print substr($1,1,6)}'`.`hostname`
date_daily_host=`echo $2 | awk '{print substr($1,1,8)}'`.`hostname`
process_date=`echo $2`
process_year=`echo $2 | awk '{print substr($1,1,4)}'`
process_month=`echo $2 | awk '{print substr($1,5,2)}'`
process_day=`echo $2 | awk '{print substr($1,7,2)}'`

process_copydata_date_today="${process_year}/${process_month}/${process_day}"
# 优化点：减少多次调用 date 命令，先将日期转换为时间戳再进行后续处理
fix_tmp_date=$(date -d "${process_copydata_date_today}" '+%s' 2>/dev/null)
process_copydata_date=$(date -d "@${fix_tmp_date}" | awk '{print($2,$3)}')
#idtext="supplicant=(127.0.0.1) logged in"
#idtext="supplicant=\(127.0.0.1\)\susername=\([a-z]*[0-9]*\@lcms\)\slogged in"
idtext=".*idpw.*authentication ok"
#20160413_delete_start
#process_copydata_date_nextday_tmp=`date -d "1 days ${process_date}" +%F`
#process_copydata_date_nextday=`date -d ${process_copydata_date_nextday_tmp} "+%Y/%m/%d"`
#process_copydata_date_nextday1=`echo ${process_copydata_date_nextday} | awk '{print substr($1,1,4)}'`
#process_copydata_date_nextday2=`echo ${process_copydata_date_nextday} | awk '{print substr($1,6,2)}'`
#process_copydata_date_nextday3=`echo ${process_copydata_date_nextday} | awk '{print substr($1,9,2)}'`
#temp_time="${process_copydata_date_nextday3},00:00:00"
#20160413_delete_end

#20160413_add_start
process_copydata_date_lastday_tmp=`date -d "-1 days ${process_date}" +%F`
process_copydata_date_lastday=`date -d ${process_copydata_date_lastday_tmp} "+%Y/%m/%d"`
fix_tmp_lastday=`date -d ${process_copydata_date_lastday} '+%s' 2>/dev/null`
process_copydata_lastday=`date -d "@${fix_tmp_lastday}"|awk '{print($2,$3)}'`
#20160413_add_end

#20160413_delete_start
#20160226_add_start
#temp_time_00="${process_day},00:00:00"
#temp_time_24="${process_copydata_date_nextday3},24:00:00"
#20160226_add_end
#20160413_delete_end

#Fix the day
get_day=`echo ${process_copydata_date}|awk '{print($2)}'`
get_month=`echo ${process_copydata_date}|awk '{print($1)}'`
lenday=`expr length ${get_day}`
if [ ${lenday} -lt 2 ] ; then
process_copydata_date=`echo "${get_month}  ${get_day}"`
fi

old_process_month=$((10#${process_month}-3))
if [ ${old_process_month} -le 0 ] ; then
old_process_year=$((10#${process_year}-1))
old_process_month=$((10#${old_process_month}+12))
else
    old_process_year=${process_year}
fi

#Fix the month
if [ ${old_process_month} -lt 10 ] ; then
old_process_month=0${old_process_month}
fi

shell_log_path="${SHELL_LOG_DIR}/${SHELL_NAME}.sh.${ymd_host}.log"
shell_log_month_path="${SHELL_LOG_DIR}/user_access.${date_month_host}.log"
shell_log_daily_path="${SHELL_LOG_DIR_DAILY}/user_access.${date_daily_host}.log"


#====================================================================================
# Function name     : f_chk_param
# Process summary   : Check the validity of parameter
# Parameter1        : All parameters
# Return value      : 0 - Normal end
#                     1 -  Warning Exit(Invalid parameters)
#====================================================================================
f_chk_param() {

# Check for the existence of options
while getopts d: opt
do
   case $opt in
      "d" )
          t_buff=${OPTARG}
          if [ ! -z ${t_buff}  ] ;then
              if  [[ ${t_buff} != [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9] ]]; then
                  F_write_log_local "CASP0190-E The parameter is not 8 colume numbers."
                  RC=100
                  F_err_shell
              fi

              today=`date '+%s'`
              fixed_date=`date -d ${t_buff} '+%s' 2>/dev/null`

              if [ $? != 0 ] ; then
                  F_write_log_local "CASP0191-E Specified date is not correct."
                  RC=100
                  F_err_shell
              fi

              count=`expr ${today} - ${fixed_date}`

              if [ ${count} -le 0 ] ; then
                  F_write_log_local "CASP0192-E Specified date is furture."
                  RC=100
                  F_err_shell
              fi
              count_day=`expr ${count} / 86400`
              count_min=`expr \( $count_day \* 1440 \) + 1441`
          else
              F_write_log_local "CASP0193-E The parameter is empty."
              RC=100
              F_err_shell
          fi
          ;;
      * )
          F_write_log_local "CASP0198-E -d are not included in the parameters."
          return 1
          ;;
   esac
done


return 0
}


#====================================================================================
# Function name     : f_chk_log_file
# Process summary   : Check the log file existence
# Parameter1        : None
# Return value      : None
#====================================================================================

# Check for the existence
f_chk_log_file() {
sta_msg="#################### Start ${SHELL_NAME}.sh  ####################"
if [ ! -f "${shell_log_path}" ] ; then
    echo "${date_time} ${SHELL_NAME} ${sta_msg}" >> ${shell_log_path} 2>&1
    if [ $? -ne 0 ] ; then
      F_write_log_local "CASP0225-E Failed to creation the log file.(${shell_log_path})"
      RC=1
      F_err_shell
    fi
else
    echo "${date_time} ${SHELL_NAME} ${sta_msg}" >> ${shell_log_path} 2>&1
fi
INIT_FLG=on
}



#====================================================================================
# Function name     : f_chk_month_log_file
# Process summary   : Check the month log file existence
# Parameter1        : None
# Return value      : None
#====================================================================================
f_chk_month_log_file() {
F_write_log_local "Start to check the existence of log file.(${shell_log_month_path})"
if [ ! -f "${shell_log_month_path}" ] ; then
     if [ ${process_day} -eq "01" ] ; then
        touch ${shell_log_month_path} 2>&1
        if [ $? -ne 0 ] ; then
            F_write_log_local "CASP0225-E Failed to creation the log file.(${shell_log_month_path})"
             RC=1
             F_err_shell
         else
             F_write_log_local "The Log file creation success.(${shell_log_month_path})"
        fi
     else
         F_write_log_local "CASP0228-E The Log file does not exist.(${shell_log_month_path})"
         RC=1
         F_err_shell
     fi
else
    if [ ${process_day} -eq "01" ] ; then
        F_write_log_local "Null Clear (${shell_log_month_path})."
        > ${shell_log_month_path}
        val=`wc -c ${shell_log_month_path} | awk '{print $1}'`
         if [ ${val} -ne 0 ] ; then
            F_write_log_local "CASP0224-E Failed to clear the log file.(${shell_log_month_path})"
            RC=1
            F_err_shell
         else   
             F_write_log_local "Null Clear success.(${shell_log_month_path})"
         fi
    else
         val=${process_year}/${process_month}/${process_day}
         rcd_cnt=`awk -F ',' -v nval="$val" '{if($1==nval) print $0}' ${shell_log_month_path}|wc -l`
         if [ $rcd_cnt -ne 0 ] ; then
             F_write_log_local "Clear log of date.(${shell_log_month_path})"
#20160413_modify_start
#20160226_modify_start
#             sed -i '/'"${process_year}"'\/'"${process_month}"'\/'"${process_day}"'/d' ${shell_log_month_path}
#	      sed -i -e 's/'"${process_year}"'\/'"${process_month}"'\/'"${temp_time_00}"'/'"${process_copydata_date_nextday1}"'\/'"${process_copydata_date_nextday2}"'\/'"${temp_time_24}"'/g' -i -e '/'"${process_year}"'\/'"${process_month}"'\/'"${process_day}"'/d' -i -e 's/'"${process_copydata_date_nextday1}"'\/'"${process_copydata_date_nextday2}"'\/'"${temp_time_24}"'/'"${process_year}"'\/'"${process_month}"'\/'"${temp_time_00}"'/g' ${shell_log_month_path}
             sed -i '/'"${process_year}"'\/'"${process_month}"'\/'"${process_day}"'/d' ${shell_log_month_path}
#20160226_modify_end
#20160413_modify_end
             if [ $? -ne 0 ] ; then
                F_write_log_local "CASP0224-E Failed to clear the log file.(${shell_log_month_path})"
                RC=1
                F_err_shell
             else
#20160413_delete_start
#                sed -i '/'"${process_copydata_date_nextday1}"'\/'"${process_copydata_date_nextday2}"'\/'"${temp_time}"'/d' ${shell_log_month_path}
#                if [ $? -ne 0 ] ; then
#                    F_write_log_local "CASP0224-E Failed to clear the log file.(${shell_log_month_path})"
#                    RC=1
#                    F_err_shell
#                fi
#20160413_delete_end
                F_write_log_local "Clear log of date success.(${shell_log_month_path})"
             fi
         fi
    fi
fi
F_write_log_local "End to check the existence of log file.(${shell_log_month_path})"
}

#====================================================================================
# Function name     : f_chk_daily_log_file
# Process summary   : Check the daily log file
# Parameter1        : None
# Return value      : None
#====================================================================================
f_chk_daily_log_file() {
F_write_log_local "Start to check the existence of log file.(${shell_log_daily_path})"
if [ ! -f "${shell_log_daily_path}" ] ; then
      touch ${shell_log_daily_path} 2>&1
      if [ $? -ne 0 ] ; then
           F_write_log_local "CASP0225-E Failed to creation the log file.(${shell_log_daily_path})"
           RC=1
           F_err_shell
      else
           F_write_log_local "The Log file creation success.(${shell_log_daily_path})"
      fi
else
      F_write_log_local "Null Clear (${shell_log_daily_path})."
      > ${shell_log_daily_path}
      val=`wc -c ${shell_log_daily_path} | awk '{print $1}'`
      if [ ${val} -ne 0 ] ; then
         F_write_log_local "CASP0224-E Failed to clear the log file.(${shell_log_daily_path})"
         RC=1
         F_err_shell
      else   
         F_write_log_local "Null Clear success.(${shell_log_daily_path})"
      fi
fi
F_write_log_local "End to check the existence of log file.(${shell_log_daily_path})"
}
