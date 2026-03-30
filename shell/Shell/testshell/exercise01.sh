#!/bin/bash


# 任务要求：

# 创建一个名为 project_files 的目录。

# 在该目录下一次性创建 5 个文件，名称分别为 test1.txt, test2.txt ... test5.txt。

# 将所有文件名中包含“test”的文件移动到一个新创建的子目录 backup 中。

# 修改 test1.txt 的权限，使其仅所有者可读写（600）。

# 列出 backup 目录下的所有文件，并按文件大小排序。

# 提示命令： mkdir, touch, mv, chmod, ls -lhS

files_test=("test1.txt" "test2.txt" "test3.txt")
dir_file=/opt/project_files

if [ -d "$dir_file" ]; then
    echo "项目文件已存在"
else
    mkdir "$dir_file"
fi

cd "$dir_file"

for i in ${files_test[@]}; do
    touch "$i"
done

mkdir backup

for i in ${files_test[@]}; do
    if [[ $i =~ "test" ]]; then
        mv "$i" /opt/project_files/backup
    fi
done

chmod 600 test1.txt
ls -lhS /opt/project_files/backup