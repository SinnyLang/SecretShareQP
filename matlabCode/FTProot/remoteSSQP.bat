@echo off
REM 自动化的SSH后台执行脚本，无需人工干预
set ITERATION=%1

set SSH_USER=
set SSH_HOST=
set SSH_PORT=
set SSH_PASS=
set OUTPUT_FILE=SSQP-out_%ITERATION%.log
set REMOTE_CMD="cd /home/lxh/workdir/MP-SPDZ/shells && nohup sh runSSQP.sh %ITERATION% %2 %3 %4 > %OUTPUT_FILE% 2>&1 &"

echo %REMOTE_CMD% >> "d:\FTProot\linuxCMD.txt"

REM 使用批处理模式(-batch)和自动接受主机密钥(-no-antispoof)
echo Executing remote command...
echo y | "d:\data\PuTTY\plink.exe" -ssh -batch -no-antispoof -P %SSH_PORT% -pw %SSH_PASS% %SSH_USER%@%SSH_HOST% %REMOTE_CMD%

REM 检查执行结果
if %errorlevel% equ 0 (
    echo 命令已成功提交并在后台执行
) else (
    echo 错误: 命令提交失败
    exit /b 1
)